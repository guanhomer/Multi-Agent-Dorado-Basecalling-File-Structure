# All CSV reads/writes go through here so concurrency and schemas are consistent.

# source("R/locks.R")

read_csv_locked <- function(path, schema_cols) {
  lock_path <- paste0(path, ".lock")
  with_lock(lock_path, exclusive = FALSE, timeout = 60, {
    if (!file.exists(path)) {
      empty_df <- as.data.frame(
        setNames(vector("list", length(schema_cols)), schema_cols),
        stringsAsFactors = FALSE
      )
      return(empty_df)
    }
    df <- utils::read.csv(path, stringsAsFactors = FALSE)
    missing <- setdiff(schema_cols, names(df))
    for (m in missing) df[[m]] <- NA_character_
    df[names(df) %in% schema_cols]
  })
}

write_csv_locked <- function(path, df) {
  lock_path <- paste0(path, ".lock")
  with_lock(lock_path, exclusive = TRUE, timeout = 60, {
    tmp <- tempfile(tmpdir = dirname(path))
    utils::write.csv(df, tmp, row.names = FALSE)
    file.rename(tmp, path)
  })
}
