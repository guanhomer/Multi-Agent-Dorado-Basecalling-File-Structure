# logging.R
# Simple logging utility for multi-agent Dorado basecalling

log_message <- function(msg, log_file = NULL) {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  line <- sprintf("[%s] %s", timestamp, msg)
  
  # Always print to console
  message(line)
  
  # Optionally append to log file
  if (!is.null(log_file)) {
    dir.create(dirname(log_file), recursive = TRUE, showWarnings = FALSE)
    cat(line, "\n", file = log_file, append = TRUE)
  }
  
  invisible(line)
}
