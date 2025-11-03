# Create file-level status and process (worker.R)
# For the claimed folder, build status/file_status_<folder_id>.csv if it does not exist: enumerate .pod5 files, create rows with file_status = "pending" and the target bam_path.
# Process in order; each step updates the row’s file_status and last_updated.
# On completion of all rows → set folder to done.

# source("R/io_csv.R")

ensure_file_status <- function(cfg, folder_row) {
  fcsv <- file.path(cfg$status_dir, sprintf("file_status_%s.csv", folder_row$folder_id))
  
  if (file.exists(fcsv)) return(fcsv)
  
  folder_row$pod5_dir_complete <- .root_join(cfg$nanopore_root, folder_row$pod5_dir)
  
  pod5s <- list.files(folder_row$pod5_dir_complete, pattern = "\\.pod5$", full.names = TRUE)
  pod5s <- file.path(folder_row$pod5_dir, basename(pod5s))
  pod5s <- pod5s[order(as.integer(sub("^.+_([0-9]+)\\.pod5$","\\1",pod5s)))]
  df <- data.frame(
    name = folder_row$name,
    folder_id = folder_row$folder_id,
    pod5_path = pod5s,
    bam_path  = file.path(folder_row$bam_dir, paste0(tools::file_path_sans_ext(basename(pod5s)), ".bam")),
    file_status = "pending",
    agent_name = NA_character_,
    last_updated = format(Sys.Date(), "%Y-%m-%d %H:%m"),
    stringsAsFactors = FALSE
  )
  write_csv_locked(fcsv, df)
  fcsv
}

# Steps per file:
# 1) status = "downloading": copy POD5 to cfg$local_tmp_pod5
# 2) status = "basecalling" : run dorado, write BAM to cfg$local_tmp_bam
# 3) status = "uploading"   : copy cfg$local_tmp_bam to final bam_path
# 4) status = "done"
process_folder <- function(cfg, folder_row, replacing = FALSE) {
  fcsv <- ensure_file_status(cfg, folder_row)
  
  dir.create(dirname(cfg$local_tmp_pod5), recursive = TRUE, showWarnings = FALSE)
  dir.create(dirname(cfg$local_tmp_bam),  recursive = TRUE, showWarnings = FALSE)
  
  repeat {
    if (should_pause(cfg)) { Sys.sleep(600); next }
    
    # read current state
    ff <- read_csv_locked(
      fcsv,
      c("name","folder_id","pod5_path","bam_path","file_status","agent_name","last_updated")
    )
    
    # Resume existing work for this agent (if any)
    i <- which(ff$agent_name == cfg$agent_name & !ff$file_status %in% c("done","pending"))[1]
    if (is.na(i)) { # Otherwise, claim the first pending row
      i <- which(ff$file_status == "pending")[1]
    }
    if (is.na(i)) break  # no more work in this folder
    
    log_message(sprintf("Processing %d/%d ...\n", i, nrow(ff)), cfg$log_file)
    
    # Prepend root if path is relative; then normalize
    pod5_path_complete <- .root_join(cfg$nanopore_root, ff$pod5_path[i])
    bam_path_complete  <- .root_join(cfg$nanopore_root, ff$bam_path[i])
    
    # ---------- SKIP existing bam ----------
    if (!replacing && file.exists(bam_path_complete)) {
      ff <- read_csv_locked(fcsv, names(ff))
      ff$file_status[i]  <- "done"
      ff$last_updated[i] <- format(Sys.Date(), "%Y-%m-%d %H:%m")
      write_csv_locked(fcsv, ff)
      
      log_message(sprintf("%s\n", "Found existing bam output. Skipping ..."), cfg$log_file)
      next
    }
    
    # ---------- DOWNLOADING ----------
    ff$file_status[i]  <- "downloading"
    ff$agent_name[i]   <- cfg$agent_name
    ff$last_updated[i] <- format(Sys.Date(), "%Y-%m-%d %H:%m")
    write_csv_locked(fcsv, ff)
    
    # copy POD5 locally (single-file scratch)
    log_message(sprintf("%s\n", "Downloading POD5 ..."), cfg$log_file)
    if (file.exists(cfg$local_tmp_pod5)) unlink(cfg$local_tmp_pod5, force = TRUE)
    ok <- file.copy(pod5_path_complete, cfg$local_tmp_pod5, overwrite = TRUE)
    if (!ok) stop("Failed to copy POD5 to local temp: ", cfg$local_tmp_pod5)
    
    if (should_pause(cfg)) { Sys.sleep(600); next }
    
    # ---------- BASECALLING ----------
    ff <- read_csv_locked(fcsv, names(ff))
    ff$file_status[i]  <- "basecalling"
    ff$last_updated[i] <- format(Sys.Date(), "%Y-%m-%d %H:%m")
    write_csv_locked(fcsv, ff)
    
    # ensure previous temp BAM is removed
    if (file.exists(cfg$local_tmp_bam)) unlink(cfg$local_tmp_bam, force = TRUE)
    
    # Run dorado (adjust args to your dorado CLI)
    # Example: dorado basecaller <pod5> --output-bam <bam_path>
    # Replace with the correct subcommand/flags you use.
    log_message(sprintf("%s\n", "Basecalling ..."), cfg$log_file)
    run_dorado_basecall(pod5_path = cfg$local_tmp_pod5,
                                       bam_path = cfg$local_tmp_bam,
                                       dorado_exe = cfg$dorado_exe,
                                       reference_fa = cfg$reference_fa,
                                       tmp_dir = cfg$local_tmp_dir,
                                       log_file = cfg$log_file)
    
    # on failure or missing output BAM -> reset to pending and continue with next file
    if (!file.exists(cfg$local_tmp_bam)) {
      ff <- read_csv_locked(fcsv, names(ff))
      ff$file_status[i]  <- "pending"
      ff$last_updated[i] <- format(Sys.Date(), "%Y-%m-%d %H:%m")
      write_csv_locked(fcsv, ff)
      
      # cleanup partial artifacts
      if (file.exists(cfg$local_tmp_bam))  unlink(cfg$local_tmp_bam,  force = TRUE)
      if (file.exists(cfg$local_tmp_pod5)) unlink(cfg$local_tmp_pod5, force = TRUE)
      
      next
    }
    
    if (should_pause(cfg)) { Sys.sleep(600); next }
    
    # ---------- UPLOADING ----------
    ff <- read_csv_locked(fcsv, names(ff))
    ff$file_status[i]  <- "uploading"
    ff$last_updated[i] <- format(Sys.Date(), "%Y-%m-%d %H:%m")
    write_csv_locked(fcsv, ff)
    
    # copy local BAM to final destination
    log_message(sprintf("%s\n", "Uploading BAM ..."), cfg$log_file)
    dir.create(dirname(bam_path_complete[i]), recursive = TRUE, showWarnings = FALSE)
    ok <- file.copy(cfg$local_tmp_bam, bam_path_complete, overwrite = TRUE)
    if (!ok) stop("Failed to copy BAM to final destination: ", bam_path_complete)
    
    # ---------- DONE ----------
    ff <- read_csv_locked(fcsv, names(ff))
    ff$file_status[i]  <- "done"
    ff$last_updated[i] <- format(Sys.Date(), "%Y-%m-%d %H:%m")
    write_csv_locked(fcsv, ff)
    
    # cleanup local temps for next iteration
    if (file.exists(cfg$local_tmp_pod5)) unlink(cfg$local_tmp_pod5, force = TRUE)
    if (file.exists(cfg$local_tmp_bam))  unlink(cfg$local_tmp_bam,  force = TRUE)
  }
  
  # If all files are done, mark folder as done
  ff <- read_csv_locked(
    fcsv, c("name","folder_id","pod5_path","bam_path","file_status","agent_name","last_updated")
  )
  if (nrow(ff) > 0 && all(ff$file_status == "done")) {
    fs <- read_csv_locked(
      cfg$folder_status,
      c("name","folder_id","pod5_dir","bam_dir","folder_id","folder_status","agent_name","last_updated")
    )
    j <- which(fs$folder_id == folder_row$folder_id)[1]
    if (!is.na(j)) {
      fs$folder_status[j] <- "done"
      fs$last_updated[j]  <- format(Sys.Date(), "%Y-%m-%d %H:%m")
      write_csv_locked(cfg$folder_status, fs)
    }
  }
}

# Helper: detect absolute paths on Windows and POSIX
.is_abs_path <- function(p) {
  ifelse(.Platform$OS.type == "windows",
         grepl("^[A-Za-z]:[\\/]|^\\\\\\\\", p),
         grepl("^/", p))
}

# Prepend root if path is relative; then normalize
.root_join <- function(root, path) {
  full <- ifelse(.is_abs_path(path), path, file.path(root, path))
  normalizePath(full, winslash = "/", mustWork = FALSE)
}

# Run Dorado basecalling for a single POD5 → BAM.
# Windows-oriented (uses `cmd /c` and stdout redirection '>').
# Returns the process exit status (0 on success).
run_dorado_basecall <- function(pod5_path,
                                bam_path,
                                dorado_exe,
                                reference_fa,
                                model = "sup,5mC_5hmC",
                                min_qscore = 10,
                                tmp_dir = getwd(),
                                log_file = NULL) {
  # Ensure output directory exists
  dir.create(dirname(bam_path), recursive = TRUE, showWarnings = FALSE)
  
  # Quote for Windows cmd context (handles spaces and special chars)
  q <- function(x) shQuote(x, type = "cmd")
  
  # Build the Dorado command line (stdout redirected to BAM file)
  # Example:
  # "C:\...dorado.exe" basecaller --min-qscore 10 --reference "ref.fa" sup,5mC_5hmC "in.pod5" > "out.bam"
  dorado_cmd <- paste(
    "cd /d", q(tmp_dir), "&&",
    q(dorado_exe),
    "basecaller",
    "--min-qscore", sprintf("%d", as.integer(min_qscore)),
    "--reference", q(reference_fa),
    model,
    q(pod5_path),
    ">",
    q(bam_path)
  )
  
  # Optional logging
  if (!is.null(log_file)) {
    log_message(sprintf("%s\n", dorado_cmd), cfg$log_file)
  }
  
  # Execute via Windows shell
  # Note: use system2 if you prefer; here we mirror your pattern.
  status <- system(sprintf('cmd /c %s', dorado_cmd))
  
  # Return status (0 = success)
  invisible(status)
}
# -------------------------
# Example usage:
# dorado_exe <- "C:/proj/dorado-1.0.2-win64/bin/dorado.exe"
# reference  <- "C:/nanopore_data/Reference_genome/GRCh38.p14.genome.fa/GRCh38.p14.genome.fa"
# pod5_file  <- "C:/data/example/read_001.pod5"
# bam_file   <- "C:/data/example/read_001.bam"
# log_file   <- "C:/data/status/agent.log"
# status <- run_dorado_basecall(pod5_file, bam_file, dorado_exe, reference, log_file = log_file)
# if (status != 0 || !file.exists(bam_file)) message("Basecalling failed.")