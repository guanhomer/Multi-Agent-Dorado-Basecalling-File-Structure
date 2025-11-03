# (2) Scheduling + processing
# Choose next folder (scheduler.R)
# Read agent_status.csv (ensure agent_state == "on" and not locked).
# Read folder_status.csv.
# Pick the first folder_status == "pending", claim it by writing folder_status="processing" and agent_name=<this agent>.

# source("R/io_csv.R")

claim_next_folder <- function(cfg) {
  fs <- read_csv_locked(cfg$folder_status, 
                        c("name","folder_id","pod5_dir","bam_dir","folder_status","agent_name","last_updated"))
  
  # 1) Resume existing work for this agent (if any)
  j <- which(fs$agent_name == cfg$agent_name & fs$folder_status == "processing")[1]
  if (!is.na(j)) {
    return(fs[j, , drop = FALSE])
  }
  
  # 2) Otherwise, claim the first pending row
  idx <- which(fs$folder_status == "pending")[1]
  if (is.na(idx)) return(NULL)

  fs$folder_status[idx] <- "processing"
  fs$agent_name[idx]    <- cfg$agent_name
  fs$last_updated[idx]  <- format(Sys.Date(), "%Y-%m-%d %H:%m")
  write_csv_locked(cfg$folder_status, fs)
  fs[idx, , drop = FALSE]
}
