# utils.R — generic helpers


# ---------- Logging ----------
# Simple logging utility for multi-agent Dorado basecalling
log_message <- function(msg, log_file = NULL) {
  timestamp <- now_ts()
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

# ---------- Time ----------
now_ts <- function() format(Sys.time(), "%Y-%m-%d %H:%M:%S")

fmt_duration <- function(t0, units = "secs") {
  secs <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  switch(units,
    "secs" = sprintf("%.0fs", secs),
    "mins" = sprintf("%.1fmin", secs/60),
    "hours"= sprintf("%.2fh", secs/3600),
    stop("units must be 'secs'|'mins'|'hours'")
  )
}

# ---------- Paths ----------
is_windows <- function() .Platform$OS.type == "windows"

is_abs_path <- function(p) {
  if (is_windows()) grepl("^[A-Za-z]:[\\/]|^\\\\\\\\", p) else grepl("^/", p)
}

norm_slashes <- function(p) gsub("\\\\", "/", p, perl = TRUE)

path_norm <- function(p) normalizePath(p, winslash = "/", mustWork = FALSE)

join_root <- function(root, path) {
  full <- if (is_abs_path(path)) path else file.path(root, path)
  path_norm(full)
}

