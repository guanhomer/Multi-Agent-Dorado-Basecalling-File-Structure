# config.R
# Configuration for multi-agent Dorado basecalling orchestrator
# All intermediates are scoped inside `local()` so only `cfg` is exported.

cfg <- local({
  # ------------------ Agent Identity ------------------
  agent_id <- Sys.info()[["nodename"]]
  if (is.null(agent_id) || agent_id == "") {
    agent_id <- Sys.getenv("COMPUTERNAME", unset = Sys.getenv("HOSTNAME", unset = "unknown_agent"))
  }
  agent_name = agent_id
  
  # ------------------ Paths ------------------
  repo_dir   <- get_script_dir()
  status_dir <- file.path(repo_dir, "status")
  
  # ------------------ Agent settings ------------------
  if (agent_id == "SA-0002332DQS") { # Analysis PC
    agent_name = "Analysis_PC"
    nanopore_root <- "X:/Nanopore_Data"
    dorado_exe <- "C:/proj/dorado-1.1.1-win64/bin/dorado.exe"
    reference_fa <- "C:/proj/reference/GRCh38.p14.genome.fa"
    local_tmp_dir <- "C:/proj/temp"
  } else if (agent_id == "SA-0002286DRS") { # Sequencing PC
    agent_name = "Seq_PC"
    dorado_exe  <- "C:/proj/dorado-1.1.1-win64/bin/dorado.exe"
    reference_fa <- "C:/nanopore_data/Reference_genome/GRCh38.p14.genome.fa/GRCh38.p14.genome.fa"
    nanopore_root <- "Y:/Nanopore_Data"
    local_tmp_dir <- "C:/proj/temp"
  }
  
  # Local, per-agent temp area (holds single scratch POD5/BAM files)
  dir.create(local_tmp_dir, recursive = TRUE, showWarnings = FALSE)
  local_tmp_pod5 <- file.path(local_tmp_dir, "scratch.pod5")
  local_tmp_bam  <- file.path(local_tmp_dir, "scratch.bam")
  
  # ------------------ Assemble cfg (only object leaked) ------------------
  cfg <- list(
    # Agent info
    agent_id    = agent_id,
    agent_name    = agent_name,
    
    # Project paths
    repo_dir      = repo_dir,
    status_dir    = status_dir,
    samplesheet   = file.path(repo_dir, "samplesheet.csv"),
    folder_status = file.path(status_dir, "folder_status.csv"),
    agent_status  = file.path(status_dir, "agent_status.csv"),
    
    # Local temp files (per agent)
    local_tmp_dir  = local_tmp_dir,
    local_tmp_pod5 = local_tmp_pod5,
    local_tmp_bam  = local_tmp_bam,
    
    # Agent settings
    dorado_exe    = dorado_exe,
    reference_fa  = reference_fa,
    nanopore_root = nanopore_root
  )
  
  # Log path (depends on status_dir + agent_name)
  cfg$log_file <- file.path(status_dir, sprintf("agent_%s.log", cfg$agent_name))
  
  cfg
})

message("Configuration loaded for agent: ", cfg$agent_name)
