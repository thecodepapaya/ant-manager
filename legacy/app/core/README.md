# AntManager Core (Python)

The `core` directory contains the logic, processing, and data management layer of AntManager. It is designed as a standalone CLI tool that the Flutter frontend invokes to perform all backend operations.

## 🏗 Architecture

The core follows a modular, functional approach where each command is an atomic operation.

```text
                  +-----------------+
                  |     main.py     | (CLI Entry)
                  +--------+--------+
                           |
           +---------------+---------------+
           |               |               |
   +-------v-------+ +-----v-----+ +-------v-------+
   |   Ingestion   | | Processing| |    Storage    |
   +---------------+ +-------------+ +-------------+
   | git_ingestion | | evidence_c| | db.py (SQLite)|
   | cal_ingestion | | narr_build| | config (JSON) |
   | g_calendar    | | llm_client| | schema.py     |
   +---------------+ +-----------+ +---------------+
```

## 📂 Directory Structure

- `main.py`: The primary entry point. It uses `argparse` to route commands like `daily-summary`, `ingest-git`, `timeline`, etc.
- `config.py`: Manages the application configuration stored in `~/.ant_manager/config.json`.
- `storage/`:
    - `db.py`: Wrapper for SQLite operations using `sqlite3`. Handles events, artifacts, notes, and narratives.
    - `schema.py`: Defines the database schema and indices.
- `ingestion/`:
    - `git_ingestion.py`: Interfaces with the local `git` binary to extract commit history and diffs.
    - `calendar_ingestion.py`: Uses `pyobjc` to access the macOS `EventKit` for local Apple Calendar events.
    - `google_calendar.py`: Handles OAuth2 and API calls for Google Calendar integration.
- `processing/`:
    - `evidence_collector.py`: A unified service that gathers and deduplicates items from all sources (Git, Cal, DB, Notes) for a given time range.
    - `narrative_builder.py`: Orchestrates the generation of AI summaries. It collects evidence, prepares prompts, and manages the lifecycle of a "Narrative".
    - `llm_client.py`: A unified interface for interacting with various LLM providers (Ollama, Gemini, OpenAI).
    - `prompts.py`: Contains the system and user prompt templates used for summarization and achievement extraction.
- `utils.py`: Common helper functions for ISO date parsing, JSON serialization, and logging.

## 🔄 Core Workflows

### 1. Unified Timeline Retrieval
When the UI requests the timeline, `main.py` calls `evidence_collector.collect_unified_items()`. This function:
1.  Fetches live data from configured Git repos and local/cloud calendars.
2.  Queries the local SQLite database for manual notes and "promoted" events.
3.  Deduplicates items based on source-specific IDs.
4.  Returns a sorted list of events in a standard JSON format.

### 2. Narrative Generation
Generating a daily or weekly summary follows this path:
1.  **Collect Evidence**: Gathers all commits, meetings, and notes for the target period.
2.  **Summarize Commits**: If not already cached, individual commits may be summarized via LLM to provide better context.
3.  **Prompt Construction**: Injects the gathered evidence into a template from `prompts.py`.
4.  **LLM Call**: Sends the prompt to the configured provider (e.g., Ollama for local-first).
5.  **Persistence**: Saves the generated text and a list of "evidence IDs" used to the `narratives` table in SQLite.

## 🛠 Development & Testing

### Prerequisites
- Python 3.10+
- Requirements listed in `requirements.txt`

### Manual Execution
You can run the core directly from the terminal to debug commands:

```bash
# Initialize the database
python3 core/main.py init-db

# Fetch current configuration
python3 core/main.py config-get

# Generate a daily summary for today
python3 core/main.py daily-summary --date 2025-12-21
```

### LLM Providers
The core supports three providers:
- `ollama`: Default, expects a local Ollama server at `localhost:11434`.
- `gemini`: Requires a Google Gemini API key.
- `openai`: Requires an OpenAI API key.

## 🔒 Security & Privacy
- **Local-First**: By default, data is processed and stored locally.
- **Sensitive Data**: API keys and tokens are stored in the user's home directory (`~/.ant_manager/config.json`) with standard file permissions.
- **External Calls**: The core only makes network requests to Google Calendar (if enabled) and configured cloud LLM providers. Git ingestion is strictly local.

