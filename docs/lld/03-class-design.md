# LLD 03 — Class design

Step 3 of the low-level design. **Status: Part 1 agreed, simplification pass done (2026-11-18); implemented. Part 2
(app/ui) was built directly, see the end of this doc.** Sections marked
**[agreed]** have been accepted by the owner; everything else is a proposal to challenge.
Builds on [01-requirements.md](./01-requirements.md) and [02-entities.md](./02-entities.md).

---

## Guiding principle **[agreed]**

**Simple over complete.** Support the common path well; don't build for every edge case. When an edge case
would add a branch, a setting or a fallback, prefer to not support it, fail clearly, or ask the user. Applies to
every step of this LLD and to implementation (DECISIONS #67).

## 3.1 Package boundaries **[agreed]**

```
app/  (Flutter)  ──depends on──►  packages/core  (pure Dart)
   │                                   ▲
   └──────────depends on──────►  packages/ui   (Flutter; knows nothing about core)
```

| Package | Contains | May depend on | Must not depend on |
|---|---|---|---|
| `packages/core` | Domain model, database, sources, AI clients, narrative engine, reports, staleness, jobs, tool layer, **ports** (interfaces for platform services) | Dart SDK, drift + sqlite3, dio, pure-Dart libs | Flutter, `ui`, `app` |
| `packages/ui` | Design tokens (`AntTokens`), components, widget gallery | Flutter | `core`, `app` |
| `app` | Screens and state (Riverpod), **platform adapters** implementing core's ports (keychain, tray, hotkey, EventKit bridge, screen capture, notifications, updater), composition root | Flutter, `core`, `ui`, platform plugins | — |

**Ports and adapters:** anything platform-specific is an interface in `core/ports` and an implementation in `app`.
That keeps core testable with fakes (N8) and Flutter-free.

| Port (in core) | Adapter (in app) |
|---|---|
| `SecretStore` | flutter_secure_storage (Keychain / Credential Manager / libsecret, required on Linux) |
| `BlobStore` | app-support directory on disk |
| `Clock` | system clock (fake in tests) |
| `Notifier` | local_notifier |
| `CalendarBridge` | EventKit via a Swift platform channel (macOS) |
| `GitExecutable` | detected system git (PATH, Homebrew, Xcode CLT, Git for Windows) |
| `FileWatcher` | Dart `FileSystemEntity.watch` with polling fallback |

## 3.2 Inside `packages/core` **[agreed]**

```
core/lib/
  domain/       enums & small value objects only (entities are drift data classes)
  data/         drift tables, triggers, migrations, repositories
  capture/      Source interface, connectors, SourceRegistry, Ingestor, Grouper
  ai/           LlmClient interface, provider adapters, ModelRouter, StructuredOutput
  narrative/    ImportanceScorer, Enricher, FactExtractor, FactReconciler, WorkstreamAssigner
  reports/      ReportGenerator, TemplateRenderer
  staleness/    DependencyRecorder, StalenessService, RecomputeWorker
  jobs/         JobQueue, Scheduler, Worker
  tools/        HarnessTool interface, ToolRegistry, built-in tools
  ports/        platform interfaces (see 3.1)
  engine.dart   AntEngine: the only public entry point the app uses
```

**Public API rule:** `core` exports `engine.dart`, the **drift-generated data classes** (read models), `ports/` and
`tools/`. There are no separate domain classes (DECISIONS #71). **Reads** use the drift classes directly; **writes** go
only through `AntEngine` commands. Repositories, connectors and workers stay internal, so the app can't bypass
invariants (e.g. writing a payload without a revision).

## 3.3 Runtime model **[agreed]**

```
 UI isolate (Flutter)                 Engine isolate (pure Dart, long-lived)
 ───────────────────                  ───────────────────────────────────────
 Riverpod providers  ── commands ──►  AntEngine
 drift watch streams ◄── reads ────   ├─ SQLite (single writer, WAL)
                                      ├─ JobQueue + Scheduler + Workers
                                      ├─ Source watchers / pollers
                                      └─ LLM calls (streaming back to UI)
```

- **One engine isolate per running app** owns the database writer, jobs and network. The UI isolate sends commands and
  reads through drift's cross-isolate connection, so **reactive queries** (`watch()`) still drive the UI.
- **Why:** the tray keeps working with no window (FR10); long syncs, extraction and LLM streaming never cause UI jank (N1);
  there's a single writer to the DB (N3).
- **Only the active profile's engine runs** (#77). Switching profile stops one engine and starts the other, which then
  catches up (missed schedules run once, #79).

## 3.4 Key interfaces **[agreed]**

### Capture

```dart
/// A connector instance (GitHub account, a git repo, Google Calendar, screenshot capture…).
abstract interface class Source {
  SourceKind get kind;
  Future<SourceHealth> validate(SourceContext ctx);
  /// Pull everything new since the stored cursor. Must be idempotent and resumable.
  Stream<PayloadObservation> sync(SourceContext ctx);
}

/// Optional: sources that can be notified of changes (git file watch, EventKit change events).
abstract interface class WatchableSource implements Source {
  Stream<void> changes(SourceContext ctx); // triggers a debounced sync; never writes directly
}

/// What a source saw. The Ingestor turns it into Evidence/Payload/PayloadRevision rows.
final class PayloadObservation {
  final String externalId;          // unique per source
  final PayloadKind kind;           // commit, review, calendar, note, image…
  final Map<String, Object?> content;
  final DateTime occurredStart; final DateTime? occurredEnd;
  final String? groupKey;           // exact identity for grouping: iCal UID, commit SHA
  final bool tombstone;             // upstream deletion
}

class SourceContext { /* cursor get/set, identities, http client, SecretStore, Clock, logger */ }

/// kind → factory. Adding a connector = one class + one registration (N7).
class SourceRegistry { void register(SourceKind kind, Source Function(SourceConfig) factory); }

/// The only writer of capture tables. One transaction per observation batch:
/// upsert payload by (source, externalId) → compare content hash → append PayloadRevision if changed
/// → group by groupKey → tombstone if deleted. DB triggers enqueue recompute work in the same transaction.
class Ingestor { Future<IngestResult> ingest(SourceId source, List<PayloadObservation> batch); }
```

### AI

```dart
abstract interface class LlmClient {
  ModelCapabilities capabilitiesOf(String model);
  Stream<LlmEvent> generate(LlmRequest request); // tokens, usage, done, error; cancellable
}
// Adapters: OpenAiCompatibleClient (OpenRouter, OpenAI, LM Studio, vLLM, custom endpoints),
//           OllamaClient, AnthropicClient, GeminiClient.

class ModelRouter { ResolvedModel resolve(LlmTask task); } // TaskRoute → falls back to the `default` route
// createClient(provider) refuses a non-loopback base URL without consent (#118): every request path goes through it.

/// Typed JSON output. EVERY configured model must support native structured output (JSON schema):
/// OpenAI/OpenRouter response_format, Anthropic structured outputs, Gemini responseSchema, Ollama `format`,
/// LM Studio/vLLM json_schema. Checked once by a probe call when a model is added; models that fail are rejected.
/// No prompt-only fallback, no repair retries. A malformed response is an error.
class StructuredOutput { Future<T> call<T>(LlmTask task, Prompt p, JsonSchema<T> schema); }
```

### Narrative

```dart
class ImportanceScorer { Future<void> scoreBatch(List<EvidenceId> ids); }      // model; skips user/rule-set scores
class Enricher { Future<void> enrich(PayloadId id); }                         // dispatches by payload kind
abstract interface class EnrichmentStrategy { PayloadKind get kind; Future<EnrichmentResult> run(Payload p); }

/// Produces proposed changes for one window (a day), given its evidence, enrichments and existing facts.
class FactExtractor { Future<FactChangeSet> extract(Window window); }

/// Applies a change set while enforcing invariants: citations required, user-touched facts never
/// overwritten (→ needs_review), FactRevision appended, Dependency rows recorded.
class FactReconciler { Future<void> apply(FactChangeSet changes); }

class WorkstreamAssigner { Future<void> assign(List<FactId> facts); }
```

### Reports

```dart
class ReportGenerator {
  /// Gathers facts for the period through the tool layer, renders via the template,
  /// streams the text, then writes an immutable ReportSnapshot + its Dependency rows.
  Stream<ReportEvent> generate(ReportId id, {String? styleInstruction});
}
```

### Staleness & jobs

```dart
class DependencyRecorder { Future<void> record(EntityRef dependent, List<EntityRevisionRef> inputs); }
class StalenessService {
  Future<bool> isStale(EntityRef ref);                    // computed: recorded vs current revisions
  Stream<StalenessState> watch(EntityRef ref);            // for "out of date" badges
}
class RecomputeWorker { Future<void> drain(); }           // queue → handler per entity type, transitive

class JobQueue {                                          // durable, survives restarts
  Future<JobId> enqueue(JobSpec spec);
  Future<Job?> lease(Duration ttl); Future<void> complete(JobId id); Future<void> fail(JobId id, Object err);
}
class Scheduler { void start(); }                         // schedule → jobs; on launch runs each overdue schedule once
```

### Tool layer

```dart
/// Typed query over Evidence and the Narrative. Reports and Wins use these now; chat and MCP later.
abstract interface class HarnessTool<I, O> {
  String get name; String get description;
  JsonSchema<I> get input; JsonSchema<O> get output;
  Future<O> call(I input, ToolContext ctx);
}
// Built-ins: search_evidence (FTS5), get_evidence, get_facts, time_breakdown, workstream_timeline, list_wins.
class ToolRegistry { void register(HarnessTool tool); }
```

### Facade

```dart
/// The only object the app talks to (per profile).
class AntEngine {
  CaptureApi get capture;     // addNote(day, text, images, link), attach(payload → evidence), split, star, hide
  NarrativeApi get narrative; // confirmFact, editFact, rejectFact, setWinStatus, reviewQueue
  ReportsApi get reports;     // generate(period, template, style), lock, unlock, list
  SourcesApi get sources;     // add/validate/remove sources, sync now
  ModelsApi get models;       // providers, models, task routes
  ToolRegistry get tools;     // read-side queries
}
```

## Review outcome (Part 1)

| # | Question | Answer |
|---|---|---|
| 1 | Dedicated engine isolate? | **Yes.** |
| 2 | Pull-based sources; watchers only trigger a sync? | **Yes.** |
| 3 | Structured output strategy | **Require native structured-output support from every model** (local, network, cloud). Probe on add, reject if unsupported; no fallback path. |
| 4 | Fact extraction per day + separate workstream pass? | **Yes.** |
| 5 | Domain classes vs drift data classes | **Expose drift-generated data classes.** Writes still go only through `AntEngine`. |

## Part 2: app and ui (as built)

Not designed up front; built under #67 and recorded as decisions. Layout: [app/README.md](../../app/README.md).

- **Engine isolate:** `EngineHandle` spawns the engine; UI commands are closures run in the engine (`commands.dart`,
  `setup_commands.dart`); plugin-backed ports (keychain, notifications, EventKit) are proxied back to the UI isolate.
  Switching profile restarts the engine isolate (#101).
- **Diagnostics (#126):** `LogSink` port + static `Log` in core (`diagnostics/log.dart`); `RotatingFileLog` adapter
  in `app/platform` used by both isolates (separate files); `diagnosticsCmd` + `diagnosticsReport` in
  `app/engine/diagnostics.dart`; buttons in Settings → General (LLD 04 §4.14).
- **macOS:** App Sandbox off, login keychain until signing, quick capture reuses the main window (#101); native
  channels `ant/calendar` (EventKit) and `ant/clipboard` (rich copy, image paste, #107).
- **Screens:** Today, Timeline, Narrative, Reports, Wins, Projects (#107); Sources, Settings, Onboarding (#105; Welcome step #114, simplified and provider Manage in the model step #NEXT). New
  `AntEngine` commands cover projects/workstreams and starring via `WinService` (#107).
  `todayProvider` re-checks the profile-zone day every minute; Today's focus and the Today count follow it.
  Evidence payloads are listed in insertion (`rowid`) order, so a note's body precedes its annotations (#130).
- **ui tokens:** density/type tokens for sidebar, top bar, chips and prose (#107); `packages/ui/tool/check_tokens.dart`
  enforces no literals. Visual-fidelity pass against the mockup, both themes, 1280–1920 wide (#113).
  Round 2 (#120): `AntDialog` gains `subtitle`/`leadingActions`/`width` and a divided footer (`WideDialog` wraps it);
  `AntInteractive(focusRadius:, focusInset:)` paints the focus ring; `EvidenceRow(compact:)` is the Timeline line.
