# AntManager

AntManager is a local-first macOS desktop application designed to help developers and professionals maintain an evidence-backed timeline of their work. It automates the collection of activity from various sources and uses Large Language Models (LLMs) to generate meaningful daily/weekly narratives and "Wins" lists.

## 🚀 Key Features

- **Local-First & Privacy-Focused**: All data (commits, notes, events, and narratives) is stored locally in a SQLite database. No data leaves the machine unless configured to use external LLM providers (Gemini/OpenAI).
- **Automated Evidence Ingestion**:
    - **Git Commits**: Automatically pulls commit history from configured local repositories.
    - **Calendar Integration**: Fetches events from local Apple Calendar and Google Calendar.
- **Manual Context Capture**: Fast and lightweight manual note-taking to capture thoughts, blockers, or offline activities.
- **AI-Powered Narratives**:
    - **Daily/Weekly Summaries**: Generates structured narratives of work done over a period using LLMs.
    - **Wins List**: Automatically extracts and highlights key achievements.
    - **Commit Summarization**: Individual commits can be summarized by AI for better readability in the timeline.
- **Customizable LLM Backend**: Supports local LLMs via **Ollama** (e.g., Llama 3) for 100% private operation, as well as **Gemini** and **OpenAI** for high-quality cloud-based summaries.
- **Interactive Timeline**: A unified view of all work evidence, searchable and filterable by date.

## 🏗 Architecture

The project follows a decoupled architecture consisting of a Flutter frontend and a Python core backend, communicating via a structured CLI interface.

### System Overview Diagram

```text
+-----------------+    (CLI Call)    +-------------------+
| Flutter Frontend| ---------------> | Python Core       |
| (macOS Desktop) | <--------------- | (Entry: main.py)  |
+--------+--------+    (JSON Out)    +---------+---------+
         |                                     |
    (UI Rend)            +----------------+----+----------------+
         |               | Local Storage  |    | LLM Services   |
         +-------------- | (SQLite/Config)|    | (Ollama/Cloud) |
                         +----------------+    +----------------+
```

### 1. Frontend (Flutter)
- **Location**: `app/lib/`
- **Role**: Provides the user interface, manages application state, and handles user interactions.
- **Communication**: The Flutter app communicates with the Python core via **CLI commands** (using `Process.run`). There is no persistent server or port management, ensuring a simple and robust local setup.
- **Screens**:
    - `Timeline`: The central feed of all ingested events and notes.
    - `Narrative`: UI for generating, viewing, and locking AI-generated summaries.
    - `Wins`: Dedicated view for achievement-focused summaries.
    - `Settings`: Configuration for Git repos, LLM providers, and prompts.

### 2. Backend (Python Core)
- **Location**: `app/core/`
- **Role**: Handles data ingestion, processing, LLM orchestration, and storage.

#### Data Ingestion Pipeline

```text
Sources:       Ingestors:          Processing:        Storage:
+-------+   +---------------+
| Git   |-->|git_ingestion  | \
+-------+   +---------------+  \  +------------------+   +--------+
                                > |evidence_collector|-->| SQLite |
+-------+   +---------------+  /  +------------------+   | (DB)   |
| Cal / |-->|cal_ingestion  | /                          +--------+
| GCal  |   +---------------+
+-------+
```

- **Key Modules**:
    - `main.py`: The CLI entry point that routes commands from the Flutter UI.
    - `ingestion/`: Specialized scripts for fetching data from Git and Calendars.
    - `processing/`:
        - `evidence_collector.py`: Merges and deduplicates data from various sources into a unified event format.
        - `narrative_builder.py`: Implements the logic for constructing LLM prompts and managing the generation lifecycle.
        - `llm_client.py`: A unified interface for interacting with Ollama, Gemini, and OpenAI.
    - `storage/`: Manages the SQLite database (`db.py`) and defines the data model (`schema.py`).

### 3. Workflow: Narrative Generation

```text
1. Request (Date/Period) -> User triggers via Flutter UI
2. Execute CLI Command   -> Python (narrative_builder.py)
3. Fetch Evidence        -> Query SQLite + Live Git/Cal Check
4. Build Prompt          -> prompts.py (Evidence + Templates)
5. Call LLM              -> llm_client.py (Ollama or Cloud API)
6. Save & Return         -> Upsert SQLite -> JSON to Flutter
```

### 4. Storage & Configuration
- **Database**: SQLite, stored in the macOS `Application Support` directory.
- **Configuration**: A JSON file located at `~/.ant_manager/config.json` stores user preferences, repository paths, and API keys.
- **LLM Prompts**: Default prompts are built-in but can be customized via the settings UI, allowing users to tune how narratives are generated.

## 🛠 Tech Stack

- **UI**: Flutter (Dart)
- **Logic/Processing**: Python 3.10+
- **Database**: SQLite
- **LLM Integration**: Ollama (local), Google Gemini API, OpenAI API
- **Version Control Ingestion**: Git (via CLI)
- **Calendar Ingestion**: `EventKit` (macOS) and Google Calendar API

## 📋 Overall View

AntManager bridges the gap between raw technical activity (commits) and human-readable work reporting. It is designed for individuals who want to keep a better record of their contributions with minimal manual effort, while retaining full control over their data.

