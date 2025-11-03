# (3) Monitor manual edits and restart logic (monitor.R)
# Goals:
#   Respect agent_status.csv manual lock_state or agent_state == "locked" → pause processing loop.
# Detect invalid manual edits in CSVs and repair or refuse (e.g., backward transitions).

# source("R/io_csv.R")

# monitor.R — pause when this agent is locked (manual or state)
should_pause <- function(cfg) {
  cols <- c("agent_name","lock_state","agent_state","last_updated")
  as <- read_csv_locked(cfg$agent_status, cols)
  
  # No agent_status rows → not paused
  if (!nrow(as)) return(FALSE)
  
  row <- as[as$agent_name == cfg$agent_name, , drop = FALSE]
  if (!nrow(row)) return(FALSE)
  
  lock_state  <- tolower(trimws(as.character(row$lock_state[1])))
  agent_state <- tolower(trimws(as.character(row$agent_state[1])))
  
  should_locked <- identical(lock_state, "locked") || identical(agent_state, "locked")
  
  if (isTRUE(should_locked)) {
    log_message(sprintf("Detected locked state for agent '%s'; pausing.", cfg$agent_name), cfg$log_file)
  }
  
  should_locked
}
