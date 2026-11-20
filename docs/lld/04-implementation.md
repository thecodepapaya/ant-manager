# LLD 04 — Implementation (key algorithms)

Step 4 of the low-level design. **Status: agreed (2026-11-18)** after owner review (#88–#92); implemented, with
later choices folded in (#100–#108). Every choice follows DECISIONS #67 (simple over complete). Choices that go beyond agreed decisions are
tagged ; open points are at the end. Builds on [02-entities.md](./02-entities.md) and
[03-class-design.md](./03-class-design.md).

```
 sync / note ─► Ingestor ─► payload rows ──trigger──► RecomputeQueue ─► RecomputeWorker
                                                                         ├─ score importance   (Extraction route)
                                                                         ├─ enrich             (Vision / Extraction)
                                                                         ├─ extract day facts  (Extraction route)
                                                                         ├─ compute time facts (deterministic, no model)
                                                                         └─ assign workstreams (Extraction route)
 schedule / open / on demand ─────────────────────────────────────────► generate report    (Reports route)
```

## 4.1 Ingest & grouping

```
ingest(source, observations):            # one SQLite transaction per batch
  for o in observations:
    p = payload where (source, o.externalId)
    if p is null:
      if o.tombstone: continue
      e = (o.groupKey != null) ? evidence owning a live payload with the same groupKey : null   # iCal UID / commit SHA
      e ??= new Evidence(occurred = o.occurredStart..o.occurredEnd, day = localDate(o.occurredStart, profile.tz), title = titleOf(o))
      insert Payload(rev 1, hash = sha256(canonicalJson(o.content))) + PayloadRevision(1, cause: sync)
    else if o.tombstone and p.tombstonedAt == null:
      set p.tombstonedAt = now; p.revision += 1; append PayloadRevision(cause: sync)        # change → triggers fire
    else if sha256(canonicalJson(o.content)) != p.contentHash:
      update content/hash; p.revision += 1; append PayloadRevision(cause: sync)
    # else: identical → no write, nothing goes stale (invariant 2)
  cursors staged by the batch are written in the same transaction (#102), so a failed sync keeps earlier batches
```

- **Canonical JSON** (sorted keys, no volatile fields such as `fetched_at`) makes hashes stable, so re-syncs are no-ops.
- **Evidence title/time** come from its first payload. If that payload is tombstoned, the next live payload takes over.
  Evidence with no live payloads is hidden from views but kept (history).
- **Manual attach / split / suggested attach** are engine commands that move a payload between evidence rows in one
  transaction (`cause: merge | split`), which bumps the payload revision so dependents go stale.

## 4.2 Staleness

**Recording (on every derived write):** the producer writes `Dependency(dependent, dependent_revision, input, input_revision)`
for each input it actually read, in the same transaction as the derived row.

**Triggers (enqueue atomically with the change):**

```sql
CREATE TRIGGER payload_changed AFTER UPDATE OF revision ON payload BEGIN
  INSERT INTO recompute_queue(entity_type, entity_id, reason, enqueued_at)
  SELECT d.dependent_type, d.dependent_id, 'payload ' || NEW.id || ' r' || NEW.revision, unixepoch()
  FROM dependency d WHERE d.input_type = 'payload' AND d.input_id = NEW.id;
  -- plus: a 'day' entry for the evidence's day, so new/changed evidence re-runs that day's extraction
  INSERT INTO recompute_queue(entity_type, entity_id, reason, enqueued_at)
  SELECT 'day', e.day, 'evidence changed', unixepoch()   -- day precomputed in the profile time zone (#87)
  FROM evidence e WHERE e.id = NEW.evidence_id;
END;
-- Same pattern: AFTER INSERT ON payload (new evidence → its day), AFTER UPDATE OF revision ON fact
-- (→ dependents: reports, workstreams), AFTER UPDATE OF starred, hidden, importance ON evidence (→ its day).
```

**Computed check (source of truth for "out of date" badges):**

```sql
-- stale iff any recorded input revision differs from the current one, or the input row is gone (#103)
SELECT EXISTS (
  SELECT 1 FROM dependency d
  LEFT JOIN payload p ON p.id = d.input_id
  WHERE d.dependent_type = ? AND d.dependent_id = ? AND d.input_type = 'payload'
    AND (p.id IS NULL OR p.revision <> d.input_revision)
  UNION ALL
  SELECT 1 FROM dependency d
  LEFT JOIN fact f ON f.id = d.input_id
  WHERE d.dependent_type = ? AND d.dependent_id = ? AND d.input_type = 'fact'
    AND (f.id IS NULL OR f.revision <> d.input_revision)
  -- same for enrichment
);
```

**RecomputeWorker:** drains the queue (de-duplicated by entity, oldest first), debounced by about 30 s so a burst of
sync changes becomes one recompute per day. It dispatches by type: `day` → importance → enrichment → fact extraction →
time facts → workstreams. `report` → only marks it; reports regenerate lazily (invariant 6).
**Model calls never run inside a transaction (#103):** each stage reads its inputs, calls the model, then writes in a
short transaction that first re-checks the inputs (payload revisions; for extraction the day's input fingerprint). If
they moved, the result is discarded and the day re-queued. The worker deletes the queue rows only **after** the
handler's writes have committed, so a crash leaves the work queued; stages are idempotent, so a re-run is safe.

## 4.3 Capture (core sources)

| Source | Sync (pull) | Change trigger | "Mine" filter | Payload content |
|---|---|---|---|---|
| **git repo** | `git log --all --since=<cursor> --format=… --numstat` per repo; cursor = last seen commit time minus 1 day (overlap is free thanks to hashes) | watcher on `.git/refs/` and `.git/logs/HEAD` → debounced sync | author or committer email ∈ identities | sha, message, author, timestamps, branches containing it, stats, **patch up to 200 KB, then stats only [proposed]** |
| **GitHub / GHES / GitLab** | Search API for PRs/MRs updated since the cursor where you're author, reviewer or commenter; then each PR's reviews and comments by you | none (poll every 15 min) | login ∈ identities | PR: title, body, state, repo, URL, merged_at, your reviews/comments; commits referenced by SHA (→ grouping) |
| **GitHub / GHES issues** (#106) | `GET /issues?filter=created` and `filter=subscribed` (`state=all&since=<cursor>`; commenting, assignment and mentions subscribe you; `filter=all` would be every visible issue), all pages, entries with `pull_request` dropped; then your comments and, if closed, the issue (`closed_by`). Own cursor scope `issue` | none (same poll) | you opened, closed or commented | issue: title, body, state, repo, URL, labels, closed_by, roles, your comments |
| **GitLab issues** (#106) | `GET /issues?scope=created_by_me` updated after the cursor, plus your `GET /events` (`target_type=issue&action=closed`; `action=commented` on an Issue noteable) since the cursor's day; then your non-system notes. Own cursor scope `issue` | none (same poll) | you opened, closed or commented | as GitHub issue, minus stateReason and comment URLs |
| **Google Calendar** | `events.list` with `syncToken` (incremental by design) | none (poll every 15 min) | events where you're not `declined` | title, start/end, attendees count, organizer, description, iCalUID (→ grouping) |
| **Apple Calendar** | EventKit fetch for the window [cursor − 7 d, now + 1 d] | `EKEventStoreChanged` → sync | not declined | same as Google |
| **ICS (incl. Outlook)** | HTTP GET (ETag), parse, expand RRULE within the window | none (poll every 60 min) | all events in the feed | same as Google; external id = UID + recurrence id |
| **Notes / screenshots** | n/a: written directly by engine commands | — | always mine | text, link?, attachment refs |

- **Remote → repo mapping:** each git repo's `origin` URL is parsed into (host, owner, repo). If the host matches a
  connected GitHub/GHES/GitLab source, that source covers the repo; otherwise the UI offers to connect that host.
- **Initial import:** the last **30 days** when a source is added .
- **Polling intervals** are constants in v1, not settings .
- **Sync service (#102):** a source is due 15 min after its last success (ICS 60 min), watched sources included as a
  backstop; at most one pending sync job per source. Status (`lastSuccessAt`, `lastError`) lives on the source's
  `''`-scope SyncCursor row. Removing a source only disables it (evidence, cursors, secret kept); editing its config
  keeps its cursors. The git picker treats only enabled repos as "Added"; ticking a removed repo re-enables its
  existing source (and syncs it) rather than adding a second one for the same path (#115).
- **git hardening (#118):** every call runs `git -C <repo> -c log.showSignature=false …`; capture's `log` and `show` add
  `--no-textconv --no-ext-diff`, so a repo's config / `.gitattributes` can't make our reads run its commands.

## 4.4 Importance scoring

- **Batch:** up to 50 unscored or changed evidence items per call (Extraction route, structured output):
  `[{evidence_id, score: 0..1, reason}]`. The input is title + kind + short content excerpt per item.
- **Precedence when stored:** user per-item (star = 1.0, hide = 0) > CurationRule (highest priority match) > model.
  The model never overwrites `set_by = user | rule`.
- **Neutral default** 0.5 until scored.

## 4.5 Enrichment (every payload kind, #91)

Every payload gets an enrichment through a per-kind `EnrichmentStrategy`:
- **Image → description** (Vision route): text in the image, who/what/where if visible, any praise/recognition wording.
- **Transcript → summary** (Extraction route): decisions, action items, who said what that matters.
- **Commit → summary** (what changed and why, from message + patch), **PR/review → summary** (purpose, outcome,
  your role), **calendar event → summary** (purpose, your role, from title/description/attendees), **note → normalized
  summary** (Extraction route).
- Batched where possible (several small payloads per call), cached, re-run only when the payload revision changes.
  Fact extraction reads enrichments **plus** raw excerpts.

## 4.6 Fact extraction (per day)

**Input** (prompt budget allocated by importance, highest first, until ~60% of the model's context is used; anything
left is listed as one line per item):
- the day's evidence (not hidden), with payload ids, content excerpts and enrichments
- the day's existing facts (id, type, statement, origin, citations)
- the profile's projects and the workstreams active in the last 30 days (for hints only)

**Output** (structured):

```json
{ "ops": [
  { "op": "create", "type": "Outcome", "statement": "…", "details": {}, "citations": ["payload-id", "…"],
    "project_id": "…|null", "importance": 0.8, "suggest_win": true },
  { "op": "update", "fact_id": "…", "statement": "…", "citations": ["…"] },
  { "op": "retire", "fact_id": "…", "reason": "evidence removed" } ] }
```

**Prompt (#119):** each fact type has a definition, an example and a "not this" line (tests/docs/CI of a change fold
into its outcome; when unsure, not an outcome); importance follows a rubric (0.1-0.2 routine, 0.3-0.4 normal,
0.5-0.6 notable, 0.7-0.8 significant, 0.9-1.0 exceptional); `suggest_win` only for outcomes at >= 0.7. Op fields are
ordered citations → statement → type → importance.

**FactReconciler rules (enforce invariants, one transaction per day):**
1. Drop any op whose citations reference payloads not in the input (logged as an extraction error, counted for evals).
2. `create` → new Fact (origin `inferred`, revision 1) + FactRevision + Citations pinned to current payload revisions.
   `suggest_win` → `win_status = suggested` (unless the same statement was rejected before for these citations).
3. `update`/`retire` on a model-owned fact (`origin = inferred`) → apply, bump revision, append FactRevision.
4. `update`/`retire` on a user-touched fact (`confirmed | user-edited | user-created`) → **don't apply**; set
   `review_state = needs_review` with the proposal attached for the user to accept or dismiss (invariant 7).
5. Record Dependency rows (fact ← cited payload revisions; the day ← all its input payload revisions).

**Also (#100):** a day is re-extracted only when its input fingerprint changes (dependency revisions + a curation hash
in Settings); an **accepted win is protected** like a user-touched fact; facts whose citations are all gone are
retired (or proposed for retirement if protected). **Accepting a proposal** applies statement/details/retire and
re-pins citations to the proposal's payloads at current revisions (#103).

## 4.7 Time allocation (deterministic: no model) 

Time facts are computed in code, so they're reproducible and defensible:
- **Measured:** sum of durations of non-declined, non-hidden calendar events per project per day (overlaps merged).
- **Estimated:** commit activity sessions (#109): only commits **authored** by your email identities count (one with
  no or an empty author email counts too, #115). The day's commits across **all projects** form sessions: consecutive commits less than
  90 min apart; a session counts from 30 min before its first commit to its last commit. Each commit owns the stretch
  since the previous commit of its session (the first commit: its 30 min lead), credited to that commit's project;
  summed per project per day, excluding time already measured by meetings.
- **Time zone:** days, schedules, report periods and the nudge use the profile's IANA zone through the bundled
  `timezone` database (`latest_10y`); unknown names fall back to the system offset (#109).
- Output: up to **two** `Time allocation` facts per project per day, one per basis (#100), `details = {minutes, basis:
  measured|estimated}`, citing the payloads used. Weekly and longer periods sum these.

## 4.8 Workstream assignment

After a day's extraction, new facts without a workstream go to the Extraction route with the active workstreams
(last 30 days: id, title, summary). Structured output: per fact, an existing workstream id **or** a new title. Users can
rename, merge or move facts between workstreams (user changes are never overwritten). Workstream span updates from its
facts; the same call refreshes an existing workstream's summary (`new_summary` on an assignment to it, by id or
by a reused title, ignored for user-touched workstreams, #109, #115). A workstream created in the same batch with a
blank summary takes the first later non-blank one (#116). A workstream with no live facts has a null span and is not active (#110).

## 4.9 Report generation

1. **Gather** through the tool layer: `get_facts(period, profile)` (not rejected; ordered by importance) +
   `time_breakdown(period)` + `list_wins(period)`.
2. **Budget:** include facts by importance until ~60% of the Reports model's context; the rest become per-project counts.
3. **Generate** (Reports route, structured output):
   `{ "sections": [{ "heading": "…", "items": [{ "text": "…", "fact_ids": ["…"] }] }] }`, guided by the template
   prompt + optional style instruction.
4. **Validate:** every `fact_ids` entry must be in the gathered set; items with none are dropped (no uncited claims, N9).
5. **Render** to Markdown deterministically (`# <title>`, `## <heading>`, `- <text> [^f1][^f2]`; markers numbered by
   first appearance, then footnotes `[^fN]: <fact statement> (fact:<id>)` that the UI links, #108), store a ReportSnapshot (JSON + Markdown)
   and Dependency rows (snapshot ← fact revisions). The snapshot's fact inputs are **all** live facts in the period
   (`get_facts` has no limit), so that set is its period fingerprint: the snapshot is stale when a recorded input
   changed (transitively, invariant 5) **or** a live fact in the period isn't among its inputs, e.g. evidence added
   for a past day (#104).
6. **When:** on schedule (job kinds `report:daily|weekly|monthly|quarterly`, LLM lane, args `{schedule_id, due}`; daily
   covers its own day, longer kinds the period that just ended; the kind's default built-in template), or on demand (an
   engine command, not a job). Opening a stale report shows "Out of date"; it isn't regenerated automatically yet.
   **Locked** reports skip steps 1–6 and only show staleness.
7. **Templates (#86, #108):** built-ins ship in code (`builtin.<name>`) and are re-seeded on launch; editing one
   duplicates it. A copy of a built-in gets the id `<builtinId>/<ulid>`, so reset-to-default finds its origin without a
   schema column. Templates used by reports can't be deleted.

## 4.10 Wins

- `win_status = suggested` comes from extraction (§4.6). Accept/reject is a user command (user-touched from then on).
- **Star an evidence item:** if an Outcome fact already cites one of its payloads → set that fact `accepted`. Otherwise,
  enqueue a one-off extraction for that evidence that must produce an Outcome fact, created as `accepted` with
  origin `user-created`.
  That call (`win` schema: `fact_id|null`, `statement`, `citations`) also lists the live model-owned facts citing the
  evidence; if the model returns one's `fact_id`, that fact becomes the win (only an outcome, problem-solved or invisible-work fact; type Outcome, the new statement, importance 1, citations + the call's, origin
  `confirmed`, `accepted`) instead of a new fact (#119).
- The Wins view = `type = Outcome AND win_status = accepted`, filterable by period and project.

## 4.11 Jobs & scheduler

- **Job table** with `state ∈ queued | running | done | failed`, `run_after`, `attempts`, `lease_until`.
- **One worker loop** in the engine isolate with two lanes: **IO** (syncs, backups) and **LLM** (one model call at a time,
  so a local model isn't swamped). A job leased but not finished when the app dies is re-queued when `lease_until` passes.
- **Retries:** exponential backoff (1 min, 5 min, 30 min), then `failed` and shown in Settings .
- **Scheduler:** per profile, a list of `{kind, rule}` (daily 18:00 weekdays, weekly Mon 09:00, monthly 1st 09:00,
  quarterly first day 09:00, backup 02:00, nudge weekdays 18:05, #105). Editing a schedule sets `lastRunAt = now`, so it
  never fires a missed run. On launch and every minute: for each schedule, if its latest due time is
  after its last run → enqueue once (catch up once, #79). Each occurrence converts its wall time with the profile
  offset at that instant, not the current one (#117); a wall time skipped by spring-forward lands an hour off.

## 4.12 Delete permanently (#85)

One transaction, user command only:
1. Collect the evidence's payloads → delete their PayloadRevisions, Attachments (rows now, files after commit),
   Enrichments, FTS rows, and Citations pointing to them; then the payloads and the evidence.
2. Facts that now have **no citations** → delete them with their FactRevisions and Dependency rows.
3. Facts that kept some citations → model-owned: enqueue re-extraction of their day; user-touched: `needs_review`.
4. Report snapshots that depended on deleted facts go stale through the normal mechanism. **Locked** snapshots keep their
   text until unlocked; the UI warns that locked reports and existing backups may still contain the deleted content.

No undo. A confirmation dialog states exactly what will be removed.

**Orphan sweep (#NEXT):** on engine start, before any command runs, `FileBlobStore.sweep` deletes every file under
`blobs/<profileId>/` not in `EvidenceDeleter.referencedBlobPaths` (`attachments.path` ∪ payload `attachments` lists).
This cleans up after a crash between the delete's commit and its blob deletes, or between writing a blob and its row.

## 4.13 Backup & readable export (#105, #108)

- `<folder>/<profile>-<profileId>-<yyyymmddThhmmssZ>.antbackup` (zip: `manifest.json`, `db.sqlite` from `VACUUM INTO`,
  `attachments/…`), written as `<name>.tmp` then renamed, pruned to the last `backup.keep` of this profile id. The
  attachment list, counts and day range are read from the snapshot file; a blob missing by then is skipped (logged
  `backup.blob_missing`). Older `<profile>-<stamp>` bundles are no longer listed or pruned but still restore (#NEXT). Restore always creates a new profile (#105); if it fails, the profile row, its
  `.sqlite` file and its `blobs/<id>/` folder are deleted (#115). Restore writes the DB to `<target>.tmp`, sets `credential_ref = NULL, enabled = 0` on every
  source that had a credential, then renames it into place (#NEXT); saving it with a new secret re-enables it (#118) under a fresh `source:<id>:<newId>` ref, so the original profile's keychain item is untouched (#121).
- **Readable export** (if `backup.readableExport`): `<folder>/<profile>-<profileId>-export/`, deleted and rewritten each run:
  `facts.json|md`, `wins.json|md` (live facts by day), `reports.json` (every snapshot version) +
  `reports/<start>_<kind>_<template-slug>.md` (latest per report; skipped unless `<start>` is `YYYY-MM-DD`, #NEXT), `evidence.json` (metadata + payload ids, no
  content), `notes.md`. Source configs and credential refs are left out.

## 4.14 Diagnostics (#126)

- **Log (core, pure Dart):** `Log.info/warn/error(event, fields)` formats one line
  `<ISO UTC ms> <LEVEL> <isolate> <event> key=value…` and hands it to `Log.sink` (a `LogSink` port, set per
  isolate; null in tests drops lines). String values go through `redact()`; errors become `errorSummary()` (type +
  redacted message; an `LlmFailure`, or text containing one, is reduced to `LlmFailure(<status>)` because its message
  can quote provider names, raw bodies or model output) and `stackSummary()` (top 6 frames). `redact()` cuts at the first `{`, then replaces URLs,
  emails, `Bearer`/`Basic` credentials, `key=`/`token:`-style pairs, known token prefixes, 32+ char alphanumeric
  runs, absolute/relative paths and quoted strings, and caps at 240 chars. A warn/error with the same event and
  fields (ignoring `ms`, `stack`) is written at most once per 10 min, the next one carrying `repeated=<n>`.
- **Events:** `app.start` (version, build, OS, OS version, Dart), `engine.start|ready|stop|restart|exit|failed|
  uncaught`, `engine.loop|scheduler|watchers` errors, `command.fail`, `job.start|finish|fail` (kind, lane, attempt,
  ms, retry/gave_up), `sync.ok|fail` (source id, kind, ms, created/updated/tombstoned/unchanged),
  `llm.ok|fail` (route, provider kind, host, model, ms, in/out tokens, HTTP status), `flutter.error`, `uncaught`.
  The engine isolate's uncaught errors are logged UI-side from the `Isolate.spawn` error port.
- **Files (app adapter `RotatingFileLog`):** `<dataDir>/logs/{ui,engine}.log` (one writer per file, so no locking),
  synchronous appends; past 1 MB the file shifts to `.1.log`, `.2.log` and the oldest is deleted (3 files each).
- **Copy diagnostics:** `diagnosticsCmd()` (engine) reports profile count, schema versions, pause flag, each
  source's kind/enabled/last sync status (redacted error), providers by kind/protocol/loopback with model counts,
  routes set, job counts by state and by kind/state (not done), and the latest redacted job error. The UI adds
  app/OS/Flutter/Dart versions and the last 200 lines of all log files merged by timestamp (`tailLogs`), copies it to
  the clipboard and toasts. "Open folder" launches `logs/` with `url_launcher`.
- **About (#127):** below Diagnostics; version from `engineConfigProvider.appVersion`; GitHub / Report a bug /
  Request a feature open `ProjectLinks` URLs (`settings/project_links.dart`) with `url_launcher` (external browser;
  error toast if it fails). The bug form asks for the Copy diagnostics output.

## Review outcome

| # | Open point | Answer |
|---|---|---|
| 1 | Initial import window | **Last 30 days** when a source is added (#88). |
| 2 | Patch size cap | **200 KB per commit**, stats only beyond (#89). |
| 3 | Estimated time from commit sessions | **Keep it**, labelled *estimated* (#90). |
| 4 | Enrichment scope | **Every payload kind** (#91). Rejected my "images + transcripts only" proposal. |
| 5 | Structured reports rendered by code | **Yes** (#92). |
