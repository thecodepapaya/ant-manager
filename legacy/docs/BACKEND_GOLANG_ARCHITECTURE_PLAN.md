# Backend Migration Plan: Python Core to Go (Golang)

## 1. Goal Description

Migrate the **Ant Manager** backend (`app/core`) from Python 3 to a single, standalone **Go (Golang)** binary (`ant-manager-core`) while retaining the existing Flutter desktop frontend.

### Context & Motivations
The current Python backend imposes significant runtime overhead:
- Flutter must construct and maintain a Python virtual environment in `~/Library/Application Support/ant_manager_python_venv`.
- Flutter executes `pip install -r requirements.txt` on startup.
- Python process invocation has a cold-start overhead of ~300–800ms per command.
- Complex runtime dependencies (`pyobjc`, `google-api-python-client`, `requests`).

By rewriting the backend in Go as a **pure-Go, CGO-free, 1:1 CLI-compatible executable**:
1. Cold start drops from ~500ms to **<5ms**.
2. Python, pip, and virtual environment setup logic in Flutter is **completely eliminated**.
3. All existing Flutter UI screens, Riverpod providers, and data flows remain unchanged.
4. Binary distribution is a single static file placed in the Flutter assets/bundle.

---

## 2. Key Architectural Decisions

1. **Communication**: CLI-compatible binary providing 1:1 argument and JSON output parity with `main.py`. This ensures zero breaking changes on the Flutter UI layer.
2. **Calendar Ingestion**: Apple Calendar (macOS EventKit) is excluded for now. Google Calendar OAuth2 and Google Calendar API v3 will be implemented in pure Go.
3. **CGO-Free Architecture**: The Go binary will use `modernc.org/sqlite` (pure Go SQLite), allowing effortless cross-compilation (`CGO_ENABLED=0`) across macOS (Apple Silicon `arm64` and Intel `amd64`), Windows, and Linux.
4. **Data & Config Preservation**: The Go backend will use the exact same SQLite database path (`~/Library/Application Support/ant_manager.db` or via `ANT_MANAGER_DATA_DIR`) and the exact same `~/.ant_manager/config.json` file. Existing user data and settings will be 100% preserved.

---

## 3. Architectural Comparison

```text
Current Architecture (Python + Flutter):
┌────────────────┐  Subprocess CLI (Cold start) ┌──────────────────────────────┐
│ Flutter (Dart) │ ───────────────────────────> │ Python Core (Requires venv,  │
│                │ <─────────────────────────── │ pyobjc, pip, ~2.5k LOC)      │
└────────────────┘          JSON Output         └──────────────────────────────┘

Target Go Architecture:
┌────────────────┐  Subprocess CLI (<5ms start) ┌──────────────────────────────┐
│ Flutter (Dart) │ ───────────────────────────> │ Go Single Static Binary      │
│                │ <─────────────────────────── │ (~15MB, zero dependencies)   │
└────────────────┘          JSON Output         └──────────────────────────────┘
```

---

## 4. Go Project Structure (`core-go/`)

```
core-go/
├── cmd/
│   └── ant-manager-core/
│       └── main.go              # CLI entry point matching main.py args
├── internal/
│   ├── config/
│   │   ├── config.go            # ~/.ant_manager/config.json reader/writer
│   │   └── types.go             # AppConfig struct & defaults
│   ├── storage/
│   │   ├── db.go                # SQLite connection pool, migrations
│   │   ├── schema.go            # SQL schema & DDL
│   │   ├── events.go            # Events & Artifacts CRUD
│   │   ├── notes.go             # Notes CRUD
│   │   └── narratives.go        # Narratives CRUD & lock logic
│   ├── ingestion/
│   │   ├── git.go               # Commit parsing, diff extraction, author check
│   │   └── google_cal.go        # Google Calendar OAuth2 & Event Ingestion
│   ├── processing/
│   │   ├── evidence.go          # Event deduplication & timeline unification
│   │   ├── prompts.go           # Prompt templates for daily, wins, commit summary
│   │   └── narrative_builder.go # Time bounding, context assembly, generation
│   ├── llm/
│   │   ├── client.go            # Unified LLM interface
│   │   ├── ollama.go            # Native HTTP client for Ollama
│   │   ├── gemini.go            # Google Generative AI client
│   │   └── openai.go            # OpenAI client
│   └── utils/
│       ├── dates.go             # ISO8601 & timezone calculations
│       └── paths.go             # Cross-platform data/config dir resolution
├── go.mod
├── go.sum
└── Makefile                     # Build & bundle commands
```

---

## 5. Technical Specification by Component

### Storage & Schema
- Pure Go SQLite driver (`modernc.org/sqlite`).
- Database initialized with WAL mode:
  ```sql
  PRAGMA journal_mode = WAL;
  PRAGMA foreign_keys = ON;
  ```
- Tables:
  - `events` (with `author` and `title` columns)
  - `artifacts` (with CASCADE deletion on `event_id`)
  - `narratives` (with unique index on `period_start, period_end, purpose`)
  - `notes` (with index on `timestamp`)
  - `blockers`

### Git Ingestion & Concurrency
- Uses `os/exec.CommandContext` to invoke `git log` and `git show`.
- Leverages goroutines and `sync.WaitGroup` (or `errgroup.Group`) to scan multiple repositories concurrently.
- Format string parity with current Python ingestion:
  `--format=%H%x1f%aI%x1f%an%x1f%s%x1e`

### Google Calendar
- Uses `golang.org/x/oauth2` for token exchange and refresh.
- Uses `google.golang.org/api/calendar/v3` for querying calendar items within `start_dt` and `end_dt`.
- Stores and reads token JSON in `~/.ant_manager/config.json`.

### LLM Client Layer
- Unified interface with pluggable providers:
  - **Ollama**: Local REST calls to `http://localhost:11434/api/generate`.
  - **Gemini**: Official Google GenAI SDK (`github.com/google/generative-ai-go`).
  - **OpenAI**: Official OpenAI Go SDK (`github.com/sashabaranov/go-openai`).

### Flutter Bridge Refactoring
- Refactor `app/lib/services/python_service.dart`:
  - Eliminate virtualenv creation, pip dependency installation, and requirements checking.
  - Locate `ant-manager-core` binary and execute directly via `Process.run`.
  - Retain existing JSON parsing logic.
