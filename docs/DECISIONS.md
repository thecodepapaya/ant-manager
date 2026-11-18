# Ant Manager v1 — Decision Log

Every scoping and design decision for the v1 rewrite, with rationale and the discussion that led to it.
All decided on **2026-11-18** in one scoping session. [SPEC.md](./SPEC.md) is the authoritative "what";
this file is the "why". If they ever disagree, the spec wins and this log should be corrected.

Related: [OWNER_TODO.md](./OWNER_TODO.md) (things only the owner can do) · [design/](./design/) (tokens + mockup).

---

## 0. Starting point

The previous app was a Flutter UI calling a Python CLI (`app/core`) through `Process.run`, with JSON on stdout.
It needed a Python runtime (a venv plus `pip install` on first launch) and used Firebase for Google sign-in. An untracked
Go port (`core/`) and a Go migration plan had been started. All of it now lives in [`/legacy`](../legacy).

**Goal stated by the owner:** redo it from scratch as **one standalone .exe/.dmg with no dependencies**, with the same
core idea, a **highly polished UX/UI**, Flutter, greenfield (no backward compatibility), plus **OpenRouter** and
**local model URLs** (Ollama / LM Studio).

---

## 1. Architecture

| # | Decision | Rationale / context |
|---|---|---|
| 1 | **Pure Dart in a single Flutter process.** No backend sidecar. | The workload is network-, LLM- and SQLite-bound, so a second language buys no speed. It would add two codebases, a JSON/IPC contract, an extra binary to sign and notarize, and process-lifecycle handling. The owner asked "how does single Dart code work?" and then "pros/cons of Dart+Go or Dart+Rust?" before deciding ("dart as final"). |
|   | *Rejected: Dart + Go sidecar* | It would continue the `core/` work and the owner's Go learning, but needs a process boundary, sidecar signing and JSON everywhere, and Go can't do EventKit anyway. |
|   | *Rejected: Dart + Rust (FFI)* | In-process, and `git2` would remove the git dependency, but the learning curve is steep, the toolchain heavy, and the speed isn't needed. |
| 2 | **Platforms:** macOS universal .dmg, Windows Inno Setup .exe, Linux AppImage, all in v1. | Owner's choice. |
| 3 | **Git via system `git`**, auto-detected, with a guided install if missing. | Users with repos almost always have git. Detection must avoid triggering the macOS `/usr/bin/git` Xcode-CLT stub. *Rejected:* bundling libgit2 (≈5 MB + native builds per platform), a pure-Dart git reader (fragile packfile parsing). |
| 4 | **Code signing:** build the pipeline now; ship unsigned/ad-hoc until certificates exist. | The owner has no certs yet. Gatekeeper/SmartScreen workarounds go in the release notes meanwhile. |
| 5 | **Tech picks** (mine, not contested): Riverpod, drift + bundled sqlite3, dio, isolates, window_manager / tray_manager / hotkey_manager / launch_at_startup / local_notifier, auto_updater, sentry_flutter, flutter_secure_storage (Linux: libsecret with an encrypted-file fallback). | Standard, maintained Flutter desktop packages. **⟶ Linux libsecret fallback removed by #77.** |

## 2. Distribution & operations

| # | Decision | Rationale / context |
|---|---|---|
| 6 | **In-app auto-update:** Sparkle (macOS) / WinSparkle (Windows) via an appcast from GitHub Releases; Linux shows an "update available" notice. | Polished-product expectation. |
| 7 | **Delivery: all at once** (one big v1). | The owner rejected my 3-milestone plan. I'll still build so the app runs end to end early, with every integration behind one `EvidenceSource` interface. |
| 8 | **Telemetry: opt-in crash reports** (Sentry, off by default, stack traces only), plus local logs and "Copy diagnostics". | The owner chose opt-in over "none". PRIVACY.md must change: it previously promised no telemetry. |

## 3. Profiles & sources

| # | Decision | Rationale / context |
|---|---|---|
| 9 | **Multiple profiles** (e.g. Work / Side projects), each with its own DB file, sources, identities, models, templates, schedule and backups. Each profile has multiple identities (emails/usernames). | Owner's choice over "multi-email single profile". **⟶ Only the active profile runs: #77.** |
| 10 | **Calendars:** Google (OAuth), Apple (EventKit Swift bridge, macOS only), Outlook/M365 (Graph), ICS URL/file. | The Google `calendar.readonly` scope is *sensitive*: verification is needed, and there's a 100-user cap plus an "unverified app" warning until it's approved. **⟶ Outlook via ICS only: #82.** |
| 11 | **OAuth clients:** the owner registers Google + Azure clients that ship in the app (PKCE), with a BYO client-ID override. | One-click sign-in for users; power users can bring their own. **⟶ Built-in clients only, no BYO override (#76); no Azure client (#82).** |
| 12 | **More sources:** GitHub, GitLab, Linear, Jira, meeting transcripts (.vtt/.srt/.txt matched to calendar events). | Catches work local git can't see (reviews, tickets, meetings). **⟶ Transcripts are attached by suggestion, never fuzzy auto-match: #57 grouping rules.** |
| 13 | **Self-hosted support:** GitHub Enterprise Server (custom API URL), GitLab self-managed, Jira Data Center (separate adapter: API v2, PAT, usernames), plus a custom-CA trust option. | The owner asked "why do we need self-hosted?" Answer: the core audience (enterprise devs writing reviews) often works on internal servers. GHES/GitLab are nearly free to support (same API, different URL); Jira DC costs a medium amount. Owner: "let's support self hosted". **⟶ Jira Cloud only: #81.** |
| 14 | **Repo setup:** scan watched root folders, list repos with recent activity by your identities, tick to include, auto-suggest new repos; manual add too. | Lower setup friction than picking folders one by one. |

## 4. AI

| # | Decision | Rationale / context |
|---|---|---|
| 15 | **Providers:** OpenRouter, OpenAI, Anthropic, Gemini, and **custom endpoints**: any number of named URLs (localhost, **LAN machines**, or remote servers), OpenAI-compatible or Ollama-native, with optional API key/headers, HTTP or custom-CA TLS, and connection test + model listing. Localhost Ollama/LM Studio auto-detection kept as a convenience. | Owner request ("add option to set a url for openai compatible endpoint instead of local models. they may be on the local network"): models often run on a separate GPU box. Private-network endpoints are labelled as such; remote ones get the cloud consent notice. Note: macOS 15+ shows a Local Network permission prompt for LAN hosts. **⟶ Privacy label replaced by consent for any non-localhost provider: #74. All models must support structured output: #70.** |
| 16 | **Per-task model routing:** one default + optional per-task overrides. | E.g. a cheap local model for commit summaries, a strong cloud model for reviews. **UX correction (from mockup review):** the global model must be the obvious primary control; per-task overrides go in a collapsed "Customize per task" with an "inherits default" state. **⟶ Four routes only (Default, Vision, Extraction, Reports): #75.** |
| 17 | **Privacy: send everything** (full diffs, meeting details, transcripts, screenshots) to whichever provider is configured. | The owner rejected per-source toggles. Mitigation: a one-time consent notice when a cloud provider is first enabled. PRIVACY.md / THREAT_MODEL.md must be rewritten (they promised "only the text required is sent"). |
| 18 | **Image understanding** is its own per-task model setting, using a **vision model only** (no OS OCR). | The owner chose vision-model-only over on-device OCR. If the chosen model can't read images, the UI says so and suggests one (local `llava`/`qwen2.5-vl`, or cloud). With a cloud model, screenshots leave the machine; this is covered by the consent notice. **⟶ Folded into the Vision route: #75.** |

## 5. Core product flow

| # | Decision | Rationale / context |
|---|---|---|
| 19 | **Loop: Capture → Review → Narrate → Share.** | Replaces the old disconnected Timeline/Notes/Narrative/Wins tabs with one daily habit; your daily curation improves everything downstream. |
| 20 | **Home = Today page:** the day's evidence grouped by project, beside that day's narrative draft. | It fits "reflection" and the daily loop. *Rejected:* timeline feed as home, inbox as home. |
| 21 | **Narrative periods:** daily, weekly, monthly, custom range. | Owner's choice. |
| 22 | **Generation:** automatic on a **configurable schedule** + on demand anytime; narratives are **editable** (an edit locks against auto-regeneration; regenerate with an instruction; version history). | The owner wrote this answer in their own words. **⟶ Editing part superseded by #49:** reports are not editable. The schedule + on-demand generation still stand. |
| 23 | **Hybrid roll-up:** weekly is built from the (edited) dailies + starred evidence + annotations, using raw evidence for days without a daily; monthly is built from weeklies. | User edits carry forward and prompts stay bounded over long ranges. *Rejected:* strict roll-up (misses days with no daily), always-raw (ignores edits, huge prompts). **⟶ Superseded by #49:** every report queries the Narrative for its period instead of summarizing lower-level reports. |
| 24 | **Curation on evidence (all four):** star/mark as win, hide/exclude (with bulk rules), annotate (the model sees it), group into projects (auto-suggested, user-confirmed). | Owner picked all four. |
| 25 | **Wins = a living Wins log:** starred items + model-suggested wins the user accepts or rejects, with citations; it feeds review export. | Replaces per-period Wins generation. **⟶ Refined by #51:** Wins are a view over Outcome facts + starred evidence. |
| 26 | **Daily nudge:** a gentle notification at the chosen time; skipped on empty days and weekends (configurable). **No streaks.** | Streaks conflict with the "no scores" philosophy (PHILOSOPHY.md). |
| 27 | **Share formats:** Slack mrkdwn, rich text/HTML, Markdown, PDF; the default is configurable. | Owner: "configurable from all of these". |
| 28 | **Navigation:** profile switcher · Today · Timeline · Narratives · Wins · Projects · Reviews · (bottom) Sources, Settings. | No separate Notes tab, because notes live everywhere (see 30). |
| 29 | **Prompt templates per output** (Standup, Manager update, Weekly review, Wins, Brag doc): duplicable, editable, with variables, live preview and reset. | More approachable than raw prompt fields. |
| 30 | **Generic notes & context:** notes can be standalone or attached to a day, project, narrative, win or review, and can carry images and a link. **Anything not locked can be regenerated with added context.** Day notes must be easy to find. | Owner: "Until things are not locked, I should be able to add context and regenerate anything based on additional context." The mockup's note entry points were too hard to find. |
| 31 | **Recognition / praise:** capture by quick-capture **screenshot-region mode** or drag-drop into any add-note flow, with an **optional link to the original message** (so anyone can navigate to it) and who/where/date. Text read by the image-understanding model. **Just evidence** (star it to make it a win). No Slack/Teams APIs. | Chat APIs need workspace/tenant admin approval, while screenshots work with any app. Region capture needs macOS Screen Recording permission (asked on first use). |
| 32 | **Extra v1 features:** review/brag-doc export (with citations), global quick-capture hotkey, GitHub/GitLab PRs & reviews. **Full-text search is out of v1** (offered, not picked). | **⟶ Partly superseded by #52:** the full-text *index* ships in v1 (chat needs it); a search UI is still not committed. |
| 33 | **Background:** a menu bar / tray app that hosts sync, scheduled generation, nudges, the hotkey and backups. | Required for scheduled work and the global hotkey. |

## 6. Backup & export (the owner's idea)

| # | Decision | Rationale / context |
|---|---|---|
| 34 | **Outputs:** a restorable `.antbackup` bundle (`VACUUM INTO` snapshot + manifest) **and** an optional Markdown/JSON readable export. | Backup is for disaster recovery; export is for owning your data. |
| 35 | **Destinations (all):** local folder (also covers Drive/iCloud/Dropbox/OneDrive sync folders), Google Drive API (`drive.file`, non-sensitive), OneDrive API (app folder), Dropbox, WebDAV, S3-compatible. | **⟶ Superseded by #80: local folder only.** |
| 36 | **No encryption in v1** (owner: "encryption out of scope for now"). | Backups are plaintext; the UI warns for cloud destinations. It may return later without a format change. |
| 37 | **Schedule:** daily via the tray + "Back up now"; rotation 7 daily / 4 weekly / 12 monthly; stale-backup warning. | **⟶ Keep last N (#78); catch up once (#79).** |
| 38 | Secrets are never in backups (re-auth after restore). Backup ≠ sync. Restore into a new or existing profile, with a preview first. | My defaults, stated and not contested. |

## 7. Design

| # | Decision | Rationale / context |
|---|---|---|
| 39 | **Custom unified design system**, Linear-style (dense, keyboard-first, dark-first + light), with native chrome, menus and shortcuts per OS. | *Rejected:* platform-native widgets per OS (triples the UI work), plain Material 3 (looks generic). |
| 40 | **Brand:** keep the name "Ant Manager" and the current logo (`legacy/app/assets/icon.png`: two black ants on warm off-white). Palette derived from it: warm charcoal neutrals, single amber accent `#E8A54B`, Inter + JetBrains Mono. | The mockup used a hand-drawn single-ant SVG, which was a shortcut on my part, not a design choice. The real app uses the real logo. The tray needs a simplified single-ant template icon (owner approval item). |
| 41 | **Reusable design tokens** are a hard requirement: one source (`lib/ui/tokens/`, an `AntTokens` ThemeExtension); semantic colour roles with dark and light sets; accent variants derived from one seed; a radius scale derived from one base; spacing, type, shadow, motion and density tokens; a CI check bans literals outside tokens. | Owner: "if I wanted a global border radius/colour schema and wanted to change it throughout the app, I should be able to do so." Reference implementation: [design/tokens.css](./design/tokens.css). |
| 42 | **The mockup sets the design language, not the final design.** | Owner review: likes the language, but sees too much padding, spacing inconsistency and UX gaps (no obvious global model, notes hard to find), and it's "a little intimidating for a new user". The final UI needs progressive disclosure, calm empty states, advanced settings hidden and a guided first week. Captured in SPEC §10 "UX principles". |

## 8. Repo

| # | Decision | Rationale / context |
|---|---|---|
| 43 | All previous code is moved to `/legacy` (Flutter app + Python core, Go port, Go docs, old README/PRIVACY/THREAT_MODEL). The new project starts from the docs only. `PHILOSOPHY.md`, `LICENSE`, `.gitignore`, `web/` + `wrangler.json` stay at the root. | Owner instruction. `web/` is the Cloudflare Pages landing site (`pages_build_output_dir: web`), so moving it could break the live deploy. PHILOSOPHY.md is still valid and the spec links to it. |
| 44 | Git workflow: no new branches or commits unless the owner asks. | Owner preference observed across sessions. |
| 45 | **Code layout: Dart pub workspace** (built into Dart 3.6+): `app/` (Flutter shell: screens, state, platform glue), `packages/core` (pure Dart: db, sources, ai, narrative, scheduler, backup; no Flutter dependency), `packages/ui` (Flutter: design tokens, component library, widget gallery). Kept to these three packages. | The owner asked for the pros and cons of this vs a single Flutter project, then chose the workspace. Why: layer boundaries enforced by the tooling (core can't import Flutter; ui can't touch the db), fast `dart test` for core logic, the design-token rule is easy to enforce, isolate-safe core, and reusable for a future CLI or headless sync. Accepted costs: more setup, export ceremony, slightly less mainstream tooling. |
| 46 | **LLD process:** done **step by step together**, with both sides reviewing and challenging each other, not written up front and reviewed afterwards. Depth is settled per topic as we go. Starts "in a while", when the owner says so. | Owner: "discuss with me step by step" / "we both review and challenge each other". Proposed topic list (order open): code structure, data model, evidence sources, AI layer, narrative engine, background jobs, security/OAuth, backup, UI architecture, platform layer, reliability/testing. |

## Working preferences (how to collaborate on this project)

- Explain options and tradeoffs in plain terms *before* asking the owner to choose, give a recommendation, and raise
  relevant facts early rather than late.
- Don't expand scope or take git actions (branches, commits) without asking.

## 9. Harness pivot: Narrative as the core (LLD step 1, 2026-11-18)

During the requirements step the owner redefined *narrative*: not the text of a report, but "the defensible timeline
or summary … using which we can answer what all did we work on, what projects, what invisible work was done, what
problems we solved, where time was spent and if there were any hiccups", with "a chat interface to it sometime down
the line". In the owner's words: "this has now become a sort of a harness project."

| # | Decision | Rationale / context |
|---|---|---|
| 47 | **Ant Manager is a harness:** Sources → **Evidence** (raw, cited records) → **Narrative** (structured, continuously maintained memory of the work) → consumers (Reports, Wins, later Chat) that all read through one **tool layer**. | The Narrative, not the reports, is the product. Reports, Wins and a future chat are different views of the same truth, so they can't contradict each other. |
| 48 | **The Narrative is made of typed facts, each citing evidence:** Workstream, Outcome, Problem solved, Invisible work (reviews, mentoring, unblocking, interviews, incidents, meetings), Hiccup, Decision, Time allocation. **Defensibility rules:** every fact cites evidence; each fact is labelled *model-inferred* or *user-confirmed*; time is labelled *measured* (calendar) or *estimated* (activity-based); "unknown" is a valid answer. The Narrative is **updated incrementally** as evidence arrives, not regenerated wholesale. | Answering "what / which projects / invisible work / problems / where time went / hiccups" needs structured, queryable facts, not prose. The owner confirmed this reading and the fact types. |
| 49 | **Reports are not editable.** The only ways to change what a report says are to **correct facts** or **add evidence**, including evidence for a past day. The report is then regenerated from the Narrative. Each report queries the Narrative for its period (no summary-of-summaries). **Locking stays:** a locked report is a frozen snapshot that is never regenerated; it shows "facts changed since lock" and can be unlocked. | Owner: "cannot edit reports, only update facts (evidence) and report follows from it. user can add an evidence for a day." One source of truth keeps every output defensible and consistent. Supersedes the editing part of #22 and all of #23. |
| 50 | **Fact correction:** the user can confirm, edit or reject a fact. User-touched facts are never overwritten or removed by the model. Corrections show up in every unlocked report and future answer. | Follows from #49: facts are now the editing surface. |
| 51 | **Wins are a view** over Outcome facts plus starred evidence. Model-suggested wins (accept/reject) remain. | Keeps the Wins log consistent with the Narrative. Refines #25. |
| 52 | **Full-text index (SQLite FTS5) is in the data model from day one.** Semantic search with embeddings comes later, behind an interface. | A chat over years of evidence needs retrieval; adding the index later would mean a costly migration. The owner agreed. A search UI is not committed for v1. |
| 53 | **Harness tool layer:** `packages/core` exposes typed query tools (e.g. search evidence, get facts, time breakdown, workstream timeline) that reports and Wins already use. A future chat and an **MCP server** will wrap these same tools. **The MCP server and chat UI are deferred (not v1)**, but the tool layer is designed now. | Owner: "don't build the mcp server right now. save it for later." Designing the tools now makes both cheap to add, with access control (off by default) settled when they're built. |
| 54 | The owner's `readme` repo (a personal working manual with a joke promotion/offboarding page) is **not a design input**. | Owner: "the readme is kind of a joke so don't take it very seriously." |

## 10. Entities (LLD step 2, 2026-11-18)

Full model: [lld/02-entities.md](./lld/02-entities.md).

| # | Decision | Rationale / context |
|---|---|---|
| 55 | **"Source" = the connector/origin channel** (GitHub, Google Calendar, git repo, screenshot capture, manual note…). The content type is the **payload kind**. | The owner wanted to keep "source" for connectors. I had flagged that "source" was used both ways. |
| 56 | **Evidence is a moment of work that can hold multiple payloads** (e.g. a calendar payload + a screenshot + a note). Each payload comes from one source with its own external id. 1:1 is the norm; grouping is rare. | Owner: "evidence can contain multiple payloads… we'd mostly have 1:1 mapping". This replaced my single-payload proposal, and it also removes the separate "annotation" concept (an annotation is a NotePayload). |
| 57 | **Citations point to payload revisions**, not evidence. **Grouping is exact-identity only** (same iCal UID, same commit SHA), manual (drag onto evidence), suggested (time overlap, user confirms), and payloads can be split off. | Precise staleness (a rescheduled meeting doesn't invalidate a fact that cites your note), precise "where did this come from", and splits never break citations. The owner agreed after a worked example. |
| 58 | **Enrichment is separate from raw payloads** and can target a payload or a whole evidence item. Raw content is never overwritten by model output. | Model output can be regenerated with better models without losing what was captured. |
| 59 | **Append-only change logs** for payloads (PayloadRevision) and facts (FactRevision). Upstream deletions tombstone; nothing is hard-deleted. | The owner's "update ledger" idea, extended to facts so corrections are traceable. It powers staleness and "facts changed since lock". |
| 60 | **Importance = model score + user overrides** (per item, and bulk **CurationRules** that generalize hide rules into weight rules). **No heuristics.** Importance allocates how much space evidence and facts get in the narrative and reports. | Owner: "a sync update meeting is weak signal… a design handoff meeting would be important"; "only model plus override"; "keep rules". Cost accepted: one batched, cached model call per evidence item, with a neutral default until scored. |
| 61 | **Staleness is enforced, not remembered:** derived items record their exact input revisions (Dependency); staleness is a computed comparison; SQLite triggers write recompute entries **in the same transaction** as each change. Facts recompute eagerly, reports lazily. | Owner: changing evidence must invalidate enrichment, narrative and reports "without having to invalidate manually … (program can exit after evidence updated but reports invalidated)". Atomic queueing + computed staleness can't be skipped or lost. |
| 62 | **Confirmed facts whose evidence changes are flagged `needs_review`**, not re-extracted. | Keeps the rule that user-touched data is never overwritten by the model (#50). Owner agreed. |
| 63 | **Wins are not a separate entity:** a win is an Outcome fact with `win_status = accepted` (`none / suggested / accepted / rejected`). Starring evidence creates or upgrades such a fact. Rejected suggestions are never re-suggested. | The owner asked me to decide. One source of truth for claims; citations, history and staleness come for free; rewording a win = correcting a fact. Trade-off: a "big" win spanning a quarter is one workstream-level Outcome fact citing evidence across the span; links between facts can be added later if needed. |
| 64 | **Providers and Models are global** (app database); **TaskRoutes are per profile**. Everything else lives in the per-profile database. | One key or endpoint serves all profiles, while each profile keeps its own model choices. Owner agreed. |
| 65 | **Workstream is an entity** (a thread facts belong to), not a fact type. | Facts need a container to form the "timeline of sorts" the owner described. Refines #48. Owner agreed. |
| 66 | **Regenerating a report may take a style instruction** ("shorter", "less jargon"), stored on the snapshot. It changes wording only, never facts. | Consistent with read-only reports (#49): templates and style shape presentation, facts shape content. Owner agreed. |

## 11. Class design (LLD step 3, 2026-11-18)

Full design: [lld/03-class-design.md](./lld/03-class-design.md).

| # | Decision | Rationale / context |
|---|---|---|
| 67 | **Guiding principle: simple over complete.** Support the common path well; don't implement every edge case. Prefer not supporting, failing clearly, or asking the user over adding branches, settings and fallbacks. Applies to the whole LLD and implementation. | Owner: "keep the implementations simpler by not supporting every plethora of edge cases … Apply this principle everywhere." |
| 68 | **Dedicated engine isolate** owns the database writer, job queue, sources and LLM calls; the UI reads via drift's cross-isolate reactive queries and sends commands. | The tray keeps working with no window; no UI jank; single DB writer. Owner agreed. |
| 69 | **Sources are pull-based** (sync from a cursor; idempotent). Optional change watchers only *trigger* a sync, never write. | One write path (the Ingestor) for all capture. Owner agreed. |
| 70 | **All models must support native structured output** (JSON schema). Verified by a probe when a model is added; unsupported models are rejected. No prompt-only fallback or repair retries. | Owner's choice over a fallback path. Applies #67: one code path, predictable failures. Cost: some small local models can't be used. |
| 71 | **Expose drift-generated data classes** as the read model; no separate domain classes. Writes only through `AntEngine` commands. | Owner's choice: less code. Cost accepted: the DB schema is visible to the app layer. Invariants stay safe because the write path is still closed. |
| 72 | **Fact extraction runs per day** (incremental), with a separate workstream-assignment pass across days. | Bounded prompts and natural incremental units. Owner agreed. |

### Simplification pass (applying #67, 2026-11-18)

| # | Decision | Rationale / context |
|---|---|---|
| 73 | **Capture behaviour kept as designed** (simplification offered, declined): optional change watchers (git file watching, EventKit change events) that trigger syncs, suggested attach by time overlap, payload split, and automatic grouping by both iCal UID and commit SHA. | Owner: "keep all current capture behaviour". Prompt capture (before squash or force-push) and accurate grouping matter more here than the extra code. |
| 74 | **Consent notice for every non-localhost provider**, LAN included. No private/remote network classification. | Simpler, and errs on the side of privacy. Replaces the "Privacy label" rule from the custom-endpoints decision (#15). |
| 75 | **Four task routes only:** Default, Vision, Extraction (importance, enrichment, facts, wins), Reports. | Fewer settings; still separates the expensive and vision-capable cases. Refines #16. |
| 76 | **No bring-your-own OAuth client**: only the built-in Google client. | Removes an advanced setting. Refines #11. |
| 77 | **Linux requires libsecret** (no encrypted-file fallback), and **only the active profile runs** in the background; others catch up on switch. | Fewer code paths. Refines #5 and #9. |
| 78 | **Backups keep the last N** (default 14), with no daily/weekly/monthly rotation. | Simpler retention. Refines #37. |
| 79 | **Missed schedules catch up once** (the latest due run). | No backfill of every missed occurrence. Refines #22 and #37. |
| 80 | **Backups go to a local folder only.** Cloud backup = choose a synced folder (Drive, iCloud, Dropbox, OneDrive). | Owner cut the five cloud API connectors. Supersedes #35. Removes several owner to-dos (Drive scope, Azure permission, Dropbox app). |
| 81 | **Jira Cloud only.** No Jira Data Center adapter. | Owner cut it. Refines #13 (GitHub Enterprise and GitLab self-managed stay). |
| 82 | **Outlook via ICS feed only.** No Microsoft Graph OAuth or Azure app registration. | Owner cut it. Refines #10 and #11. |
| — | *Kept as-is (simplification offered, declined):* custom CA + self-signed toggle per endpoint (#15), and readable Markdown/JSON export alongside backups (#34). | Owner chose to keep them. |

## 12. Scope audit answers (2026-11-18)

| # | Decision | Rationale / context |
|---|---|---|
| 83 | **Notes are evidence only:** standalone on any day, or a payload on an existing evidence item. "Add context" on a report or win creates a note dated inside that period (with its project). Notes never attach to facts: you correct facts instead. | Resolves a contradiction between SPEC ("attach to day, project, fact, win or report") and the entity model (#56). Owner agreed. |
| 84 | **No tags in v1** (notes have an optional project only). Recognition is a note with a screenshot + link. | Owner: "none in v1". |
| 85 | **"Delete permanently"** on evidence: the single exception to never deleting history. It purges payloads, revisions, attachments, enrichments, FTS entries and citations; facts left uncited are deleted with their history; others are re-extracted or flagged for review. Locked reports and existing backups are not touched (the UI warns). No undo. | Owner agreed: privacy needs a way to remove things captured by mistake. Refines #59 and entity invariant 3. |
| 86 | **The template editor is in v1:** duplicate built-ins, edit prompt/structure/period kinds, live preview, reset. | Owner: "we need template editor". Rejected my proposal to defer it under #67. Moves it from "below the line" to a core requirement (FR14). |
| 87 | **English only in v1; one time zone per profile** (defaults to the system's) defines day boundaries. Evidence stores its local `day` at ingest. | Owner agreed. Simplest correct day boundaries; also fixes the step-4 draft, which used the machine's local time. |

## 13. Implementation choices (LLD step 4, 2026-11-18)

Full algorithms: [lld/04-implementation.md](./lld/04-implementation.md).

| # | Decision | Rationale / context |
|---|---|---|
| 88 | **Initial import = last 30 days** when a source is added. | Owner agreed. Enough for a useful first Narrative without a huge first run. |
| 89 | **Commit patches stored up to 200 KB**, stats only beyond. | Owner agreed. Keeps "send everything" meaningful while bounding DB size. |
| 90 | **Estimated time from commit sessions is kept**, always labelled *estimated* (sessions: commits < 90 min apart, counted from 30 min before the first commit). Measured time comes from calendar durations. Both are computed in code, not by the model. | Owner: "yes keep it". A transparent heuristic is acceptable for time, unlike importance (#60). Otherwise time allocation would only cover meetings. |
| 91 | **Every payload kind gets an enrichment** (commit, PR/review, event, note, image, transcript), batched and cached, re-run only on revision change. | Owner rejected my "images + transcripts only" proposal. Cost accepted: more model calls per sync, mitigated by batching and caching. |
| 92 | **Reports are generated as structured JSON** (sections → items → fact ids) and rendered to Markdown by code; uncited items are dropped. | Owner agreed. Guarantees every line traces to facts (N9). |

## 14. Build kickoff (2026-11-18)

| # | Decision | Rationale / context |
|---|---|---|
| 93 | **Git:** parallel agents work on short-lived branches in their own worktrees, merged into an integration branch **`v1`**; `main` stays docs-only until the owner merges. | Owner's choice. Lifts #44 for this build. |
| 94 | **CI:** pushes are allowed; CI tests every push and builds **unsigned** macOS .dmg / Windows .exe / Linux AppImage; **tagged versions publish public GitHub Releases**. Signing is added later (OWNER_TODO). | Owner's choice. The repo is public. |
| 95 | **No review checkpoint:** foundation and features are built in one run. | Owner's choice (faster); accepted risk that foundation mistakes propagate. |
| 96 | **End-to-end testing uses OpenRouter**, with a key the owner enters in the app (never in chat or the repo). Unit tests use fakes. | Owner's choice. |
| 97 | **Second-opinion reviews** with `sarvam-code` (DeepSeek v4.1 flash), read-only, on each merged area; valid findings are fixed with tests. The first review of the foundation found 25 issues; fixes landed with 18 new tests. Day boundaries take a **per-instant offset function** (DST-correct); v1 uses the system zone, while custom IANA zones per profile need a tz database (later). | Owner instruction in CLAUDE.md. Refines #87. |
| 98 | **Calendar group key = iCal UID + occurrence start (UTC)**, not the UID alone. | Found by the calendar agent: a recurring series shares one UID, so UID-only grouping would merge every occurrence into one evidence. Same meeting from Google/Apple/ICS still groups. Refines #57. |
| 99 | **Separation of code and tests:** the agent that writes code never writes its tests; a different agent writes them, and `sarvam-code` verifies them. A full end-to-end test of the project runs once features are merged. | Owner: "I don't want a single agent writing tests for its own work." Tests written before this rule (sources, AI, reports, foundation) get an independent audit pass. |
| 100 | **Narrative pipeline details:** (a) a day is re-extracted only when its input fingerprint changes (dependency revisions + a curation hash stored in Settings); (b) an **accepted win is protected** like a user-touched fact; (c) facts whose citations are all gone are retired (or proposed for retirement if protected); (d) time allocation emits up to **two facts per project per day** (measured and estimated) so each label stays exact. | Implementation choices by the narrative agent, accepted. (d) refines LLD 04 §4.7. |

