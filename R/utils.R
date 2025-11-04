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


# ---------- Uploading ----------
# copy to "<dst>.tmp" then atomically rename to "<dst>"
atomic_upload_bam <- function(src_bam, dst_bam, log_file = NULL) {
  stopifnot(nzchar(src_bam), nzchar(dst_bam))
  if (!file.exists(src_bam)) stop("atomic_upload_bam: source not found: ", src_bam)

  dir.create(dirname(dst_bam), recursive = TRUE, showWarnings = FALSE)
  tmp_dst <- paste0(dst_bam, ".tmp")

  # clean any stale temp
  if (file.exists(tmp_dst)) unlink(tmp_dst, force = TRUE)

  # stage copy
  ok <- file.copy(src_bam, tmp_dst, overwrite = TRUE)
  if (!ok || !file.exists(tmp_dst)) stop("atomic_upload_bam: staging copy failed: ", tmp_dst)

  # optional sanity check: size match
  s_src <- file.info(src_bam)$size
  s_tmp <- file.info(tmp_dst)$size
  if (is.finite(s_src) && is.finite(s_tmp) && !identical(s_src, s_tmp)) {
    unlink(tmp_dst, force = TRUE)
    stop("atomic_upload_bam: size mismatch after copy (src=", s_src, ", tmp=", s_tmp, ")")
  }

  # remove existing destination (Windows rename won't overwrite)
  if (file.exists(dst_bam)) unlink(dst_bam, force = TRUE)

  # atomic replace within the same directory
  ok2 <- file.rename(tmp_dst, dst_bam)
  if (!ok2) {
    # best-effort cleanup
    if (file.exists(tmp_dst)) unlink(tmp_dst, force = TRUE)
    stop("atomic_upload_bam: rename failed into destination: ", dst_bam)
  }

  if (!is.null(log_file)) {
    log_message(sprintf("Uploaded BAM atomically -> %s\n", dst_bam), log_file)
  }

  invisible(TRUE)
}

