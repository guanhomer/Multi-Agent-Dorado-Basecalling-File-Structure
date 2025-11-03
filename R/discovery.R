# (1) Discovery: detect new folders and update folder status
# Read samplesheet.csv.
# Compare to status/folder_status.csv.
# Append missing rows with folder_status = "pending", agent_name = NA, last_updated = now().

# source("R/io_csv.R")

discover_new_folders <- function(cfg) {
  ss <- read_csv_locked(cfg$samplesheet, c("name","pod5_dir","bam_dir"))
  fs <- read_csv_locked(cfg$folder_status, 
                        c("name","folder_id","pod5_dir","bam_dir","folder_status","agent_name","last_updated"))
  
  ss$pod5_dir = path_fix(ss$pod5_dir)
  ss$bam_dir = path_fix(ss$bam_dir)
  
  key_ss <- paste(ss$pod5_dir, ss$bam_dir)
  key_fs <- paste(fs$pod5_dir, fs$bam_dir)
  new_rows <- ss[!key_ss %in% key_fs, ]

  if (nrow(new_rows)) {
    add <- data.frame(
      name = new_rows$name,
      folder_id = ifelse(nzchar(new_rows$name), paste0(new_rows$name, "_", format(Sys.Date(), "%Y%m%d")), NA_character_),
      pod5_dir = new_rows$pod5_dir,
      bam_dir  = new_rows$bam_dir,
      folder_status = "pending",
      agent_name = NA_character_,
      last_updated = format(Sys.Date(), "%Y-%m-%d %H:%m"),
      stringsAsFactors = FALSE
    )
    fs <- rbind(fs, add)
    write_csv_locked(cfg$folder_status, fs)
  }
  invisible(nrow(new_rows))
}


path_fix <- function(path) {
  gsub("\\\\", "/", path)
}
