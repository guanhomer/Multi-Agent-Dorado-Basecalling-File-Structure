# Prefer filelock::lock() on SMB/NFS.
# Fallback “lock directory” for cloud-sync folders.

library(filelock)

with_lock <- function(lock_path, exclusive = TRUE, timeout = 30, code) {
  lk <- lock(lock_path, exclusive = exclusive, timeout = timeout)
  on.exit(unlock(lk), add = TRUE)
  force(code)
}

with_lockdir <- function(lockdir_path, code) {
  if (!dir.create(lockdir_path, showWarnings = FALSE)) stop("Locked: ", lockdir_path)
  on.exit(unlink(lockdir_path, recursive = TRUE, force = TRUE), add = TRUE)
  force(code)
}
