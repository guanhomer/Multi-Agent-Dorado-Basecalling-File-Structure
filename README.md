# Multi-Agent Dorado Basecalling System

This scheme enables multiple PCs (“agents”) to run Dorado basecalling concurrently on shared POD5 data while avoiding file conflicts and maintaining synchronized status tracking.

---

## 1. `samplesheet.csv`
Defines input and output folder pairs for basecalling tasks.

**Columns:**
- `name` — Identifier for the POD5–BAM pair  
- `pod5_dir` — Path to the POD5 input directory  
- `bam_dir` — Path to the BAM output directory  

---

## 2. `status/folder_status.csv`
Tracks high-level progress per folder.

**Columns:**
- `name` — Identifier for the POD5–BAM pair
- `folder_id` — Unique folder identifier  
- `pod5_dir` — Input POD5 directory  
- `bam_dir` — Output BAM directory  
- `folder_status` — One of: `pending`, `processing`, `done`  
- `agent_name` — Name of the PC (agent) handling the folder  
- `last_updated` — Timestamp of last modification  

---

## 3. `status/file_status_[folder_id].csv`
Tracks detailed progress for individual POD5–BAM file pairs within each folder.

**Columns:**
- `name` — Identifier for the POD5–BAM pair
- `folder_id` — Unique folder identifier  
- `pod5_path` — Full path to the input POD5 file  
- `bam_path` — Full path to the output BAM file  
- `file_status` — One of: `pending`, `downloading`, `basecalling`, `uploading`, `done`  
- `agent_name` — Name of the PC (agent) handling the file  
- `last_updated` — Timestamp of last modification  

---

## 4. `status/agent_status.csv`
Tracks agent (PC) states and manual overrides.

**Columns:**
- `agent_id` — PC identifier  
- `agent_name` — PC name  
- `lock_state` — Manual control flag (`locked` or `unlocked`)  
- `agent_state` — One of: `off`, `on`, `locked`  
- `last_folder_id` — Last working folder  
- `last_updated` — Timestamp of last update  

---

### Summary of Naming Conventions

| Entity | File Naming Pattern | Key Column Prefix | Example Status Values |
|--------|----------------------|-------------------|------------------------|
| Folder | `folder_status.csv` | `folder_` | pending, processing, done |
| File | `file_status_[folder_id].csv` | `file_` | pending, downloading, basecalling, uploading, done |
| Agent | `agent_status.csv` | `agent_` | off, on, locked |
| Heartbeat | `heartbeat_[agent_name].touch` | — | — |

---

# Repository Layout

A modular, implementation-ready structure for coordinating concurrent Dorado basecalling.

```
dorado-orchestrator/
├─ R/
│  ├─ config.R                # Paths, constants, timeouts
│  ├─ agent_register.R        # Register agent
│  ├─ locks.R                 # Lock helpers (filelock + lockdir fallback)
│  ├─ io_csv.R                # Locked CSV read/write, schema validators
│  ├─ discovery.R             # Detect new folders; update folder_status.csv
│  ├─ scheduler.R             # Pick next folder; create/read file_status; loop
│  ├─ worker.R                # File-level transitions; hooks to Dorado
│  ├─ monitor.R               # Manual overrides, heartbeats, restart logic
│  ├─ logging.R               # Simple logs
│  └─ utils.R                 # Helper functions (timestamps, paths, etc.)
├─ status/                    # Runtime state (CSV + heartbeats)
│  ├─ folder_status.csv              # High-level folder progress
│  ├─ file_status_[folder_id].csv    # File-level progress tracking
│  └─ agent_status.csv               # Agent states and manual control
├─ samplesheet.csv                   # Input/output folder mapping
└─ agent_main.R                      # Entry point for each agent (PC)
```

---
