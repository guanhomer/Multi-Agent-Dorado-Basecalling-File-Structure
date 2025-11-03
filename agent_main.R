# ------------------------------------------------------------------------
# Usage:
#   Copy and paste the following command in CMD to run the script (replace X: or Y: with your NAS drive letter):
#     cd /d C:\proj\temp && Rscript "X:\Nanopore_Data\script\20251102 multiagent scheme\agent_main.R"
#     cd /d C:\proj\temp && Rscript "Y:\Nanopore_Data\script\20251102 multiagent scheme\agent_main.R"
#
# Delayed execution examples:
#   Wait 3 hours, then run:
#     cd /d C:\proj\temp && timeout /t 10800 >nul && Rscript "X:\Nanopore_Data\script\20251102 multiagent scheme\agent_main.R"
#   Wait 12 hours, then run:
#     cd /d C:\proj\temp && timeout /t 43200 >nul && Rscript "X:\Nanopore_Data\script\20251102 multiagent scheme\agent_main.R"
#
# ------------------------------------------------------------------------
# Setting up Rscript path:
#   Add R’s bin folder to your PATH so you can run “Rscript” directly.
#   Steps:
#     1. Open: System → Advanced system settings → Environment Variables…
#     2. Edit “Path” (User or System) → New → add one of:
#          C:\Program Files\R\R-4.4.2\bin    (analysis PC)
#          C:\Program Files\R\R-4.5.0\bin    (sequencing PC)

# Agent entry point (bin/agent_main.R)
# Loop: discovery → check manual pause → claim folder → process → repeat.
# Backoff when idle.

# There are three main functions
# 1. Check new folders & update folder status
#     - discover_new_folders() reads samplesheet under lock, appends new pending rows to folder_status.csv.
# 2. Choose first non-done folder & process
#     - claim_next_folder() safely claims a pending folder.
#     - ensure_file_status() creates file-level CSV.
#     - process_folder() performs state transitions (pending → … → done) with locked writes, one file at a time, and marks the folder done when all files are done.
# 3. Monitor manual edits; pause/restart
#     - should_pause() watches agent_status.csv for locked.

# Resolve this script's directory robustly (Rscript, RStudio, or fallback)
get_script_dir <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) > 0) return(dirname(normalizePath(sub("^--file=", "", file_arg))))
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    p <- rstudioapi::getSourceEditorContext()$path
    if (nzchar(p)) return(dirname(normalizePath(p)))
  }
  getwd()
}
script_dir <- get_script_dir()

# Helper to source files relative to this repo
source_here <- function(relpath) {
  f <- file.path(script_dir, relpath)
  if (!file.exists(f)) stop("Missing file: ", f)
  source(f)  # avoid polluting global env
}

source_here_glob <- function(pattern, recursive = FALSE, local = parent.frame()) {
  dir <- script_dir  # or set your base dir
  files <- list.files(
    path = file.path(dir, dirname(pattern)),
    pattern = glob2rx(basename(pattern)),
    full.names = TRUE,
    recursive = recursive
  )
  files <- sort(files)
  if (!length(files)) stop("No files match: ", pattern)
  for (f in files) source(f, local = local)
  invisible(files)
}

# Source in a sensible order (logging first)
source_here("R/logging.R")
source_here("R/config.R")
source_here_glob("R/*.R")

agent_main <- function() {
  log_message("Agent starting", cfg$log_file)
  log_message(sprintf("Agent: %s", cfg$agent_name), cfg$log_file)
  
  # Ensure this agent exists in status/agent_status.csv; add if missing.
  update_agent_state(cfg, agent_state = "on")
  log_message("Agent state set to ON.", cfg$log_file)
  
  repeat {
    # Pause / lock handling
    if (should_pause(cfg)) {
      log_message("Agent paused (locked). Sleeping...", cfg$log_file)
      Sys.sleep(600)
      next
    }
    
    # Discovery
    log_message("Discovery: scanning samplesheet for new folders...", cfg$log_file)
    added <- discover_new_folders(cfg)
    if (!is.null(added) && added > 0) {
      log_message(sprintf("Discovery: added %d new folder(s).", as.integer(added)), cfg$log_file)
    }
    
    # Claim next folder
    log_message("Scheduler: attempting to claim next pending folder...", cfg$log_file)
    row <- claim_next_folder(cfg)
    
    if (is.null(row)) {
      log_message(sprintf("No pending folders. Exiting."), cfg$log_file)
      break
    }
    
    # Process claimed folder
    update_agent_state(cfg, agent_state = "on", folder_id = row$folder_id[1])
    log_message(sprintf(
      "Processing: folder_id=%s | pod5_dir=%s | bam_dir=%s",
      row$folder_id[1], row$pod5_dir[1], row$bam_dir[1]
    ), cfg$log_file)
    
    t0 <- Sys.time()
    process_folder(cfg, row, replacing = FALSE)
    dt <- round(as.numeric(difftime(Sys.time(), t0, units = "hours")), 2)
    log_message(sprintf("Processing complete for folder_id=%s in %f hours.", row$folder_id[1], dt), cfg$log_file)
  }
  
  # Mark agent OFF and log
  update_agent_state(cfg, "off")
  log_message("Agent state set to OFF. Goodbye.", cfg$log_file)
  
  invisible(0L)
}

agent_main()