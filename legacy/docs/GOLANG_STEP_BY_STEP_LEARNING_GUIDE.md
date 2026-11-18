# Self-Guided Go Migration & Learning Handbook

> **Philosophy**: The best way to achieve fluency in Go is not by reading tutorials or copy-pasting code, but by building a real, production-grade system and learning how idiomatic Go solves problems differently from dynamic languages like Python.
>
> This guide is structured as a series of architectural milestones. Each milestone outlines the component responsibilities, highlights the core Go concepts you will learn, gives you nudges and architectural questions to guide your implementation, and warns you about common pitfalls without spoiling the exact code.

---

## 🧭 The Go Mental Model (Unlearning Python Habits)

Before writing your first Go file, keep these four philosophical differences in mind:

1. **Explicit Error Handling vs. Exceptions**: 
   - In Python, you write `try ... except Exception as e`. Errors bubble up automatically.
   - In Go, errors are normal values returned as the last item in a multi-value return (`func() (Result, error)`). You handle errors where they occur with `if err != nil`. Resist the urge to ignore errors or `panic()`.
2. **Implicit Interfaces vs. Inheritance**:
   - In Python or Java, a class explicitly says `class MyService(BaseService)`.
   - In Go, interfaces are satisfied **implicitly**. If a struct implements all the methods of an interface, it satisfies that interface automatically without an `implements` keyword. *Rule of thumb: define interfaces where they are consumed, not where they are implemented.*
3. **Pointers vs. Values**:
   - In Python, all custom objects are references on the heap.
   - In Go, a struct can be passed by value (a complete memory copy) or by pointer (`*MyStruct`). When should you use a pointer receiver on a method? (Hint: when mutating state or when the struct is large).
4. **Visibility is Controlled by Capitalization**:
   - In Python, `_private` is a convention.
   - In Go, if an identifier begins with an uppercase letter (`Config`, `LoadConfig`), it is **exported** (public). If it begins with lowercase (`config`, `loadConfig`), it is **unexported** (package-private).

---

## 🗺️ Milestone Roadmap Overview

```text
Milestone 0: Workspace & Toolchain Setup
      │
Milestone 1: Config Management (JSON, Structs, File I/O)
      │
Milestone 2: SQLite Storage Engine (database/sql, pure Go SQLite)
      │
Milestone 3: CLI Subcommand Dispatcher (Matching Python CLI)
      │
Milestone 4: Git Ingestion & Concurrent Scanning (Goroutines & Context)
      │
Milestone 5: Google Calendar OAuth2 & Ingestion
      │
Milestone 6: Polymorphic LLM Client (Interfaces, HTTP & SDKs)
      │
Milestone 7: Narrative Builder & Evidence Aggregation
      │
Milestone 8: Flutter Handshake & Cross-Compilation
```

---

## Milestone 0: Workspace & Toolchain Setup

### Objective
Establish the project layout following standard Go community conventions (`cmd/`, `internal/`) and initialize Go modules.

### Go Concepts to Explore
- Go Modules (`go.mod`, `go.sum`, `go mod init`, `go mod tidy`)
- Package namespace semantics (why package names match folder names)
- The special meaning of the `internal/` directory in Go (packages inside `internal/` cannot be imported by external modules)

### Architecture & Directory Layout
Create a root directory `core-go/` alongside `app/`:
```text
core-go/
├── cmd/
│   └── ant-manager-core/
│       └── main.go
├── internal/
│   ├── config/
│   ├── storage/
│   ├── ingestion/
│   ├── processing/
│   ├── llm/
│   └── utils/
├── go.mod
└── go.sum
```

### Nudges & Guiding Questions
- *How do you initialize a module named `ant-manager-core`?* Look up `go mod init`.
- *Why is `main.go` located inside `cmd/ant-manager-core/` rather than the root?* (Think about what happens if you later want to build a secondary binary or debugging utility).
- *How do you run and compile Go code during development?* Contrast `go run` vs `go build`.

### Verification Checkpoint
Create a dummy `main.go` that prints `"Ant Manager Go Core"`. Ensure you can build it with `go build -o bin/ant-manager-core ./cmd/ant-manager-core` and run the resulting binary.

---

## Milestone 1: Config Management (`internal/config`)

### Objective
Re-implement `app/core/config.py` in Go. Read and write `~/.ant_manager/config.json`, support environment overrides (`ANT_MANAGER_CONFIG_DIR`), and manage configuration updates safely.

### Go Concepts to Explore
- Structs and Struct Tags (`json:"repo_paths"`, `json:"llm_provider"`)
- The `encoding/json` package (`json.MarshalIndent`, `json.Unmarshal`)
- Operating system file utilities (`os.UserHomeDir`, `os.MkdirAll`, `os.ReadFile`, `os.WriteFile`, `os.Getenv`)
- Value receivers vs. pointer receivers on struct methods

### Nudges & Guiding Questions
- *How does Go handle default values for structs?* Unlike Python dataclasses with `field(default_factory=...)`, Go initializes fields to their **zero value** (`""`, `0`, `nil`, `false`). How can you write a constructor function (`NewDefaultConfig()`) to populate default values like `"ollama"` and `"llama3.1:8b"`?
- *What happens if `config.json` doesn't exist yet on the user's computer?* How should your code detect `os.IsNotExist(err)` and write out defaults?
- *How do you write methods that modify the config?* Why does `func (c *AppConfig) AddRepo(path string)` need a pointer receiver `*AppConfig` rather than a value receiver `AppConfig`?

### Common Pitfalls
- **Accidental Pass-by-Value**: Modifying a copy of `AppConfig` instead of the original struct because you forgot the pointer `*`.
- **Unexported Fields**: If struct field names start with lowercase (`repoPaths`), `encoding/json` will silently ignore them during serialization! Always export struct fields that need JSON tags.

### Verification Checkpoint
Write a unit test `config_test.go` that:
1. Sets a temporary directory via `ANT_MANAGER_CONFIG_DIR`.
2. Calls `LoadConfig()` and verifies defaults are created.
3. Adds a repo path, saves, reloads, and asserts the path exists.

---

## Milestone 2: SQLite Storage Engine (`internal/storage`)

### Objective
Re-implement `app/core/storage/schema.py` and `app/core/storage/db.py` using pure Go SQLite (`modernc.org/sqlite`) without CGO dependencies.

### Go Concepts to Explore
- Standard library `database/sql` package and driver registration via blank import (`_ "modernc.org/sqlite"`)
- Connection pooling and thread-safety: why `*sql.DB` is a pool, not a single connection
- Executing queries: `db.Exec` vs `db.Query` vs `db.QueryRow`
- Transactions: `db.BeginTx`, `tx.Commit()`, and `defer tx.Rollback()`
- Mapping SQL rows to structs with `rows.Scan(...)`

### Nudges & Guiding Questions
- *How should schema creation and migrations be handled?* Look at how Python runs `conn.executescript(SCHEMA_SQL)`. How can you execute multiline DDL statements in Go?
- *How do you handle nullable columns like `timestamp_end` or `author` in Go?* In Python they are `None`. In Go, scanning a `NULL` into a regular `string` throws an error. Research `sql.NullString` vs using pointers (`*string`). Which one serializes cleanly to JSON?
- *Why is WAL mode (`PRAGMA journal_mode = WAL;`) important for SQLite in a multi-threaded Go application?* SQLite locks during writes; WAL mode allows concurrent readers while a write is occurring.
- *How do you implement atomic upsert for events?* Check the `ON CONFLICT(id) DO UPDATE SET ...` syntax in SQLite.

### Common Pitfalls
- **Resource Leaks**: Forgetting to call `rows.Close()` or `defer rows.Close()`. In Go, unclosed rows keep database connections busy and will exhaust the connection pool under load.
- **Forgetting `rows.Err()`**: A `for rows.Next()` loop can terminate early due to a network or disk read error. Always check `if err := rows.Err(); err != nil` after the loop.

### Verification Checkpoint
Write an integration test `storage_test.go`:
1. Initialize an in-memory SQLite database (`:memory:`) or a temporary file.
2. Insert an event, attach an artifact, retrieve them, and assert that foreign key cascades work when the event is deleted.

---

## Milestone 3: The CLI Subcommand Router (`cmd/ant-manager-core`)

### Objective
Recreate the CLI command interface from `app/core/main.py`. This ensures your Go binary responds to the exact subcommands and flags that Flutter already sends.

### Go Concepts to Explore
- Standard library `flag` package with `flag.NewFlagSet` OR a CLI library like `github.com/spf13/cobra`
- Command routing and argument slicing (`os.Args`)
- JSON serialization to standard output using `json.NewEncoder(os.Stdout)`
- Process exit codes (`os.Exit(0)` vs `os.Exit(2)`)

### Subcommands to Support
Refer to `docs/BACKEND_GOLANG_ARCHITECTURE_PLAN.md` for the full list:
- Config: `config-get`, `config-add-repo`, `config-remove-repo`, `config-set-model`, `config-set-llm`, etc.
- Storage: `init-db`, `notes`, `add-note`, `update-note`, `delete-note`
- Ingestion: `detect-git-user`, `timeline`, `daily-summary`, `wins`, `event-details`

### Nudges & Guiding Questions
- *How do you structure command handlers cleanly without writing a 1,000-line `switch` statement?* Consider a table-driven or sub-router pattern where each command has its own function: `type CommandHandler func(args []string) error`.
- *Why is `json.NewEncoder(os.Stdout).Encode(response)` preferred over `fmt.Println(string(jsonBytes))`?* It streams bytes directly to stdout without allocating intermediate strings in memory.
- *Where should error messages go?* Flutter expects valid JSON on `stdout`. Any debugging or error diagnostics should be routed to `os.Stderr`.

### Verification Checkpoint
Run your compiled binary from the terminal:
```bash
./bin/ant-manager-core init-db
./bin/ant-manager-core config-get
./bin/ant-manager-core add-note "Testing Go backend from CLI"
./bin/ant-manager-core notes --days=1
```
Verify each outputs valid JSON matching the Python core's output structure.

---

## Milestone 4: Git Ingestion & Goroutines (`internal/ingestion`)

### Objective
Re-implement `app/core/ingestion/git_ingestion.py`. Parse Git commit history and diffs, and leverage Go's native concurrency to ingest multiple repositories in parallel.

### Go Concepts to Explore
- External process execution with `os/exec.CommandContext`
- Delimiter-based byte parsing with `bufio.Scanner` or `bytes.Split`
- Concurrency with goroutines (`go func()`)
- Synchronization with `sync.WaitGroup` or `golang.org/x/sync/errgroup`
- Context timeouts (`context.WithTimeout`) to prevent hanging `git` processes

### Nudges & Guiding Questions
- *In Python, multi-repo ingestion runs sequentially or suffers GIL overhead. How do you run ingestion across 10 repositories simultaneously in Go?* Research `errgroup.Group`. How does it propagate errors and wait for all goroutines to finish?
- *If 10 goroutines are parsing git repos simultaneously, how do you collect all events into a single slice without a race condition?*
  - Approach A: Protect the shared slice with a `sync.Mutex`.
  - Approach B (Idiomatic Go): Have each goroutine send results across a Go **channel**, and consume them in a single collector loop.
- *How do you parse non-printable delimiters?* Python used `--format=%H%x1f%aI%x1f%an%x1f%s%x1e`. In Go, `\x1f` and `\x1e` are byte literals (`byte(0x1f)`, `byte(0x1e)`). How can you split raw output bytes without unnecessary string conversions?

### Common Pitfalls
- **Goroutine Leaks**: Launching a goroutine that blocks forever on an unbuffered channel or hanging sub-command. Always pass a `context.Context` with a reasonable timeout (e.g. 15 seconds) to `exec.CommandContext`.
- **Data Races**: Appending to a slice from multiple goroutines concurrently. Always verify with the race detector: `go test -race ./...`.

### Verification Checkpoint
Run Git ingestion against the `ant-manager` repo itself:
```bash
./bin/ant-manager-core timeline --days=7
```
Confirm commits are detected, correctly attributed to the author, and sorted chronologically.

---

## Milestone 5: Google Calendar OAuth & API (`internal/ingestion`)

### Objective
Re-implement `app/core/ingestion/google_calendar.py` in Go to authenticate and ingest events from Google Calendar.

### Go Concepts to Explore
- `golang.org/x/oauth2` and `golang.org/x/oauth2/google`
- Google API Go client: `google.golang.org/api/calendar/v3`
- Secure token serialization and token refresh lifecycle
- Go HTTP client injection via `oauthConfig.Client(ctx, token)`

### Nudges & Guiding Questions
- *How does the OAuth flow work in Ant Manager?*
  1. Go generates an authorization URL with `oauth2.AccessTypeOffline`.
  2. Flutter opens the browser for the user.
  3. The user inputs the authorization code back into Flutter.
  4. Go exchanges the code for a token and stores the JSON in `config.json`.
- *How do you query events within a date range?* Look up `srv.Events.List("primary").TimeMin(...).TimeMax(...).SingleEvents(true)`.
- *How do you convert Google Calendar ISO RFC3339 timestamps into Ant Manager's internal `time.Time` representation?* Look at `time.Parse(time.RFC3339, ...)`.

---

## Milestone 6: Polymorphic LLM Engine (`internal/llm`)

### Objective
Re-implement `app/core/processing/llm_client.py` using an idiomatic Go interface that supports Ollama (local), Google Gemini, and OpenAI.

### Go Concepts to Explore
- Interface definition:
  ```go
  type Client interface {
      GenerateText(ctx context.Context, prompt string) (string, error)
      ListModels(ctx context.Context) ([]string, error)
  }
  ```
- Factory pattern: returning an implementation based on the `config.LLMProvider` string
- HTTP client best practices (`net/http.Client` with timeouts, request contexts)
- Consuming external Go SDKs:
  - `github.com/google/generative-ai-go/genai`
  - `github.com/sashabaranov/go-openai`

### Nudges & Guiding Questions
- *Why is an interface crucial here?* When writing unit tests for your narrative builder, you can pass a `MockLLMClient` that returns predetermined strings without burning API credits or needing Ollama running!
- *How should the Ollama client make requests?* Research `http.NewRequestWithContext`. Why should you reuse a single `http.Client` across requests rather than creating a new `&http.Client{}` every time? (Hint: TCP connection pooling and keep-alives).

### Verification Checkpoint
```bash
./bin/ant-manager-core llm-list-models --provider=ollama
```
Verify it queries your local Ollama instance and returns the list of installed models as JSON.

---

## Milestone 7: Evidence Aggregator & Narrative Builder (`internal/processing`)

### Objective
Re-implement `app/core/processing/evidence_collector.py`, `prompts.py`, and `narrative_builder.py`.

### Go Concepts to Explore
- String construction: why `strings.Builder` is vastly superior to `str += "..."` concatenation in loops
- Timezone manipulation in Go:
  - `time.Now().In(time.Local)`
  - Formatting with Go's reference time: `"2006-01-02T15:04:05Z07:00"` (remember: `1 2 3 4 5 6 7`)
  - Converting local start/end of day into UTC bounds
- Sorting slices: `sort.Slice` or the Go 1.21+ `slices.SortFunc`

### Nudges & Guiding Questions
- *How does narrative locking work?* If a narrative for a date range already exists in SQLite and has `locked == 1`, what should `GenerateNarrative` return when `--regenerate` is passed?
- *How do you build the prompt template cleanly in Go?* Look into Go's `text/template` package or simple `strings.ReplaceAll` placeholders. Which one gives you cleaner control?

### Verification Checkpoint
```bash
./bin/ant-manager-core daily-summary --date=2026-03-18
./bin/ant-manager-core wins --period=weekly
```
Verify the generated summaries are saved into the `narratives` SQLite table and output to stdout.

---

## Milestone 8: Flutter Handshake & Production Packaging

### Objective
Update Flutter's `app/lib/services/python_service.dart` to talk to your new Go binary and compile the final release.

### Tasks
1. **Refactor Flutter Service**:
   - In `app/lib/services/python_service.dart`, strip out all lines related to `ant_manager_python_venv`, `pip install`, and `requirements.txt`.
   - Update the executable path to point directly to `bin/ant-manager-core`.
2. **Cross-Compilation**:
   - For macOS Apple Silicon:
     ```bash
     CGO_ENABLED=0 GOOS=darwin GOARCH=arm64 go build -ldflags="-s -w" -o bin/ant-manager-core ./cmd/ant-manager-core
     ```
   - Notice the `-ldflags="-s -w"` flags. What do they do? (They strip debug symbols and reduce the binary size by ~30–40%).
3. **App Bundle Embedding**:
   - Configure Flutter's macOS build script to bundle the binary inside `App.app/Contents/MacOS/`.

### Final Acceptance Test
Launch the Flutter app:
```bash
flutter run -d macos
```
1. Observe startup time — the app should open **instantly** without waiting for any Python environment initialization.
2. Browse the Timeline, add notes, and trigger an AI summary.
3. Check memory usage in macOS Activity Monitor: notice the Go binary executes in milliseconds with negligible memory footprint.

---

## 💡 How to Get Help Along the Way

When you start implementing:
1. Work milestone by milestone.
2. Ask for conceptual clarification: *"I'm working on Milestone 2. What's the idiomatic way to handle optional SQL parameters in Go?"*
3. Ask for code reviews: *"Here is my `config.go` implementation. Are there any anti-patterns or race conditions?"*

You now have the full architectural blueprint. Take your time, embrace the Go type system and concurrency primitives, and enjoy building a blistering-fast native core!
