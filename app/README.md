# AntManager (V0)

AntManager is a **local-first** macOS desktop app that helps you keep an evidence-backed timeline of work and generate daily/weekly narratives from:

- Git commits (automatic)
- Manual notes (fast, lightweight)
- Local LLM summaries via Ollama (optional; falls back to deterministic output if Ollama is not running)

## Quick start (dev)

### Prereqs

- Flutter (desktop enabled)
- Python 3.10+
- Git
- Optional: Ollama

### 1) Set up Python core

From repo root:

```bash
cd app
python3 -m venv .venv
source .venv/bin/activate
pip install -r core/requirements.txt
python3 core/main.py init-db
```

### 2) Optional: set up Ollama (local LLM)

Install Ollama (macOS):

```bash
brew install ollama
```

Start the daemon (if not auto-started):

```bash
ollama serve
```

Pull a model used by default:

```bash
ollama pull llama3.1:8b
```

### 3) Run the Flutter app

```bash
cd app
flutter pub get
flutter run -d macos
```

## How it works (V0)

- **Flutter UI** calls the **Python core** via CLI (no server, no ports).
- Python stores all data in a local SQLite DB.
- If Ollama is running, Python uses it to produce a neutral summary; otherwise it produces a safe fallback output.

## Configure Git repositories

In the app:

- Go to **Settings → Git repositories → Add**

Or via CLI:

```bash
cd app
python3 core/main.py config-add-repo /path/to/repo
python3 core/main.py config-get
```

## Data locations

- **App data (DB, transcripts folder)**: stored under macOS Application Support (set via `ANT_MANAGER_DATA_DIR` when launched from Flutter)
- **Config**: `~/.ant_manager/config.json`

## Notes / safety

- This is intended as a personal, local tool.
- V0 does not record meetings. You can capture context via manual notes.
