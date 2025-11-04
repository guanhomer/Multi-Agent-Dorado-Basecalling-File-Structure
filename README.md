# Multi-Agent Dorado Basecalling System

This system enables multiple PCs (“agents”) to perform **Dorado basecalling concurrently** on shared POD5 data while maintaining consistent synchronization and preventing file conflicts.

It uses the `filelock` R package to coordinate concurrent reads and writes across network drives.

A companion script, toggle_agent.bat, lets users manually switch an agent between locked and unlocked states for controlled pausing or resuming of processing.

---

## Repository Layout

Each user defines input/output folder pairs (`pod5_dir`, `bam_dir`) manually in the samplesheet.

The orchestrator scripts then generate and update status files that coordinate scheduling and progress tracking.

Each POD5–BAM pair (folder) is assigned to only one agent at a time to prevent conflicts and redundant work.

```
Multi-Agent-Dorado-Basecalling-File-Structure/
├─ R/
│  ├─ config.R          # Global config, paths, timeouts, Dorado exe path
│  ├─ agent_register.R  # Ensure agent entry exists in agent_status.csv
│  ├─ locks.R           # Lock helpers (filelock + lockdir fallback)
│  ├─ io_csv.R          # Locked CSV I/O utilities
│  ├─ discovery.R       # Detect new folders from samplesheet
│  ├─ scheduler.R       # Select next folder to process
│  ├─ worker.R          # Run basecalling steps & update status
│  ├─ monitor.R         # Handle manual overrides, pause/resume
│  └─ utils.R           # Generic helpers (paths, timestamps, logging, atomic ops)
├─ status/
│  ├─ folder_status.csv           # Folder-level task tracking
│  ├─ file_status_[folder_id].csv # File-level tracking within each folder
│  └─ agent_status.csv            # Agent states and manual control
├─ samplesheet.csv                # Folder mappings for POD5 → BAM
├─ toggle_agent.bat               # Manual lock/unlock toggle for agents
└─ agent_main.R                   # Agent entry point script
```

---
## Core Principle: Safe Concurrent Access

When several agents read and write shared CSV status files (`folder_status.csv`, `file_status_*.csv`, `agent_status.csv`), race conditions can occur.  
To prevent this, all file I/O operations are wrapped in **advisory locks** using the `filelock` library:

```r
# Example (simplified)
library(filelock)
lk <- lock("status/folder_status.csv.lock", exclusive = TRUE)
on.exit(unlock(lk), add = TRUE)

write.csv(df, "status/folder_status.csv", row.names = FALSE)
```

If your shared directory is on a **true network share** (SMB/NFS), `filelock` provides reliable cross-agent coordination.  
If using **cloud-synced folders** (e.g. Dropbox, OneDrive), use the system’s built-in lockdir fallback (`locks.R`) since cloud sync does not propagate OS-level locks.

---

## File Specifications

### 1. `samplesheet.csv`
Defines input and output folder pairs for basecalling tasks.

| Column | Description |
|---------|--------------|
| `name` | Identifier for the POD5–BAM pair |
| `pod5_dir` | Path to the POD5 input directory |
| `bam_dir` | Path to the BAM output directory |

---

### 2. `status/folder_status.csv`
Tracks folder-level progress.

| Column | Description |
|---------|-------------|
| `name` | Identifier for the POD5–BAM pair |
| `folder_id` | Unique folder identifier (`name_YYYYMMDD`) |
| `pod5_dir` | Input POD5 directory |
| `bam_dir` | Output BAM directory |
| `folder_status` | `pending`, `processing`, `done` |
| `agent_name` | Name of the PC (agent) handling the folder |
| `last_updated` | Timestamp of last modification |

---

### 3. `status/file_status_[folder_id].csv`
Tracks file-level progress within a folder.

| Column | Description |
|---------|-------------|
| `name` | Identifier for the POD5–BAM pair |
| `folder_id` | Associated folder identifier |
| `pod5_path` | Full path to input POD5 file |
| `bam_path` | Full path to output BAM file |
| `file_status` | `pending`, `downloading`, `basecalling`, `uploading`, `done` |
| `agent_name` | Name of agent handling the file |
| `last_updated` | Timestamp of last modification |

---

### 4. `status/agent_status.csv`
Tracks each agent’s operational state and manual control flags. Agents can be manually paused or resumed by editing status/agent_status.csv.

| Column | Description |
|---------|-------------|
| `agent_id` | Internal identifier for the PC |
| `agent_name` | Hostname of the PC |
| `lock_state` | Manual override (`locked` or `unlocked`) |
| `agent_state` | `off`, `on`, `locked` |
| `last_folder_id` | Last assigned folder |
| `last_updated` | Timestamp of last modification |

---

### Naming Conventions

| Entity | File Pattern | Prefix | Example Status Values |
|---------|--------------|---------|------------------------|
| Folder | `folder_status.csv` | `folder_` | pending, processing, done |
| File | `file_status_[folder_id].csv` | `file_` | pending, downloading, basecalling, uploading, done |
| Agent | `agent_status.csv` | `agent_` | off, on, locked, sleeping, pausing |

---

## Manual lock/unlock via toggle_agent.bat
Use toggle_agent.bat to pause or resume an agent by editing status/agent_status.csv. The script shows the table before/after the change, acquires a simple lock (agent_status.csv.lockdir) to avoid concurrent edits, and can be double-clicked (window stays open).

Usage (cmd or double-click prompts):
- Default status_dir: alongside the script in status\
- Requires PowerShell (built into Windows 10/11)

What it changes:
- Sets lock_state to locked/unlocked
- Touches last_updated

Agents check lock_state in their loop and pause when locked, resuming automatically when switched back to unlocked.

---

## Summary

- Multiple agents cooperate through shared CSV files in a network folder.  
- Each file operation uses **`filelock`** for concurrency safety.  
- The system is modular and easily extensible (e.g., custom Dorado CLI arguments, retry logic, health monitoring).
