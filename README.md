# Multi-Agent Dorado Basecalling File Structure
This scheme lets multiple PCs (“agents”) run Dorado basecalling on shared POD5 data while avoiding conflicts and keeping status synchronized.

## 1. `samplesheet.csv`
Defines input and output folder pairs for basecalling tasks.

**Columns:**
- `name` - Name of POD5 - BAM pair
- `pod5_dir` — Path to the POD5 input directory  
- `bam_dir` — Path to the BAM output directory  

---

## 2. `status/folder_status.csv`
Tracks high-level progress per folder.

**Columns:**
- `name` - Name of POD5 - BAM pair
- `pod5_dir` — Input POD5 directory  
- `bam_dir` — Output BAM directory  
- `folder_id` — Unique folder identifier  
- `folder_status` — One of: `pending`, `processing`, `done`  
- `agent_name` — Name of the PC (agent) handling this folder  
- `last_updated` — Timestamp of last modification  

---

## 3. `status/file_status_[folder_id].csv`
Tracks detailed progress for individual files within a folder.

**Columns:**
- `pod5_path` — Full path to the input POD5 file  
- `bam_path` — Full path to the output BAM file  
- `file_status` — One of: `pending`, `downloading`, `basecalling`, `uploading`, `done`  
- `agent_name` — Name of the PC (agent) handling the file  
- `last_updated` — Timestamp of last modification  

---

## 4. `status/agent_status.csv`
Tracks agent (PC) states and manual overrides.

**Columns:**
- `agent_name` — PC identifier  
- `lock_state` — Manual control flag: `locked` or `unlocked`  
- `agent_state` — One of: `off`, `on`, `locked`  
- `last_updated` — Timestamp of last update  

---

## 5. `status/heartbeat_[agent_name].touch`
Empty file acting as a heartbeat signal.  
- Updated (touched) every 1 minute by the corresponding agent while active.  

---

### Summary of Naming Conventions

| Entity | File Naming Pattern | Key Column Prefix | Example Status Values |
|--------|----------------------|-------------------|------------------------|
| Folder | `folder_status.csv` | `folder_` | pending, processing, done |
| File | `file_status_[folder_id].csv` | `file_` | pending, downloading, basecalling, uploading, done |
| Agent | `agent_status.csv` | `agent_` | off, on, locked |
| Heartbeat | `heartbeat_[agent_name].touch` | — | — |

# Layout

Below is a compact, implementation-ready plan for organizing R scripts and core functions. It uses a small set of modules, a clear state machine, and file-locked CSV I/O.

dorado-orchestrator/
├─ R/
│  ├─ config.R                # paths, constants, timeouts
│  ├─ locks.R                 # lock helpers (filelock + lockdir fallback)
│  ├─ io_csv.R                # locked CSV read/write, schema validators
│  ├─ status_models.R         # enums, validation, allowed transitions
│  ├─ discovery.R             # (1) detect new folders; update folder_status.csv
│  ├─ scheduler.R             # (2) pick next folder; create/read file_status; loop
│  ├─ worker.R                # (2) file-level state transitions; hooks to dorado
│  ├─ monitor.R               # (3) manual overrides, heartbeats, restart logic
│  ├─ logging.R               # structured logs
│  └─ utils.R                 # small helpers (timestamps, paths, etc.)
├─ bin/
│  ├─ agent_main.R            # entry point for an agent (PC)
│  └─ reconcile.R             # optional: repairs/cleans bad states
├─ status/                    # runtime state (CSV + heartbeats)
├─ samplesheet.csv
└─ example_dataset1/...
