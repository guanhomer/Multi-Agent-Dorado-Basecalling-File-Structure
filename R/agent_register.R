# Ensure this agent exists in status/agent_status.csv; add if missing.

update_agent_state <- function(cfg, agent_state = NULL, lock_state = "unlocked", folder_id = NULL) {
  stopifnot(!is.null(cfg$agent_name), nzchar(cfg$agent_name))
  dir.create(dirname(cfg$agent_status), recursive = TRUE, showWarnings = FALSE)
  
  cols <- c("agent_id","agent_name","lock_state","agent_state","last_folder_id","last_updated")
  as <- read_csv_locked(cfg$agent_status, cols)
  
  if (!nrow(as) || !(cfg$agent_name %in% as$agent_name)) {
    new_row <- data.frame(
      agent_id  = cfg$agent_id,
      agent_name  = cfg$agent_name,
      lock_state  = lock_state,
      agent_state = "off",
      last_folder_id = "",
      last_updated = now_ts(),
      stringsAsFactors = FALSE
    )
    as <- rbind(as, new_row)
    write_csv_locked(cfg$agent_status, as)
    return(invisible(TRUE))  # added
  } else {
    # Ensure required columns exist and touch timestamp (no state change)
    i <- which(as$agent_id == cfg$agent_id)[1]
    if (!is.null(agent_state)) as$agent_state[i]  <- agent_state
    if (!is.null(folder_id)) as$last_folder_id = folder_id
    as$last_updated[i] <- now_ts()
    write_csv_locked(cfg$agent_status, as)
    return(invisible(FALSE)) # already present
  }
}
