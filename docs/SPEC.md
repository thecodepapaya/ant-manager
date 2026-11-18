# Ant Manager v1 — Product & Technical Spec

Status: **Scope locked** (2026-11-18). Greenfield rewrite; no backward compatibility with the Python/Go versions.

## 1. Goal

A polished, self-contained desktop app that builds an evidence-backed timeline of your work and turns it
into narratives (daily / weekly / monthly / custom), Wins lists and review documents.

- One download per OS, **no runtime dependencies** (no Python, no Go sidecar, no venv).
- Only external expectation: a system `git`, detected automatically with a guided install if missing.
- Philosophy unchanged — see [PHILOSOPHY.md](../PHILOSOPHY.md): reflection, not surveillance; no scores.

## 2. Platforms & distribution

| Platform | Artifact | Min OS | Notes |
|---|---|---|---|
| macOS | Universal (arm64 + x64) `.app` in `.dmg` | 10.15+ | Sparkle auto-update |
| Windows | Inno Setup `.exe` installer (x64) | Windows 10+ | WinSparkle auto-update |
| Linux | AppImage (x64) | Ubuntu 22.04-class | "Update available" notice; tray lib bundled |

- **Signing:** pipeline built now (Developer ID + notarization, Authenticode), runs ad-hoc/unsigned until certs exist.
  Release notes document the Gatekeeper / SmartScreen workaround meanwhile.
- **Releases:** GitHub Actions matrix builds all three, publishes to GitHub Releases + appcast feeds.
- **Delivery:** single v1 release with the full scope below (no milestone split).

## 3. Architecture

**Pure Dart in a single Flutter process.** No backend process, no IPC.

**Code layout: Dart pub workspace** (see DECISIONS #45). The folder sketch below shows the logical layers;
the physical split is `app/` (Flutter shell + platform glue), `packages/core` (pure Dart, no Flutter dependency),
`packages/ui` (tokens + components). Exact module boundaries will be settled in the low-level design.

```
lib/
  core/        pure Dart, no Flutter imports, unit-tested
    db/          drift schema, migrations, DAOs (one SQLite file per profile)
    sources/     EvidenceSource interface + one adapter per integration
    llm/         provider clients, model routing, streaming
    narrative/   evidence selection, prompt templates, generation jobs
    scheduler/   sync + auto-generation scheduling
    secrets/     keychain-backed credential store
  features/    timeline, notes, narratives, wins, review, sources, settings, onboarding, profiles
  ui/          design system: tokens, theme, components, motion, icons
  platform/    tray, hotkey, window, updater, notifications, platform channels
macos/Runner/  Swift: EventKit bridge
```

| Concern | Choice |
|---|---|
| State | Riverpod |
| Storage | drift + bundled SQLite (`sqlite3` native assets), per-profile DB file |
| Secrets | OS keychain (macOS Keychain / Windows Credential Manager / libsecret, with an encrypted-file fallback on Linux) |
| HTTP | `dio`, SSE streaming |
| Heavy work | Isolates (git log parsing, ICS/RRULE expansion, prompt assembly) |
| Desktop shell | `window_manager`, `tray_manager`, `hotkey_manager`, `launch_at_startup`, `local_notifier` |
| Updates | `auto_updater` (Sparkle / WinSparkle) |
| OAuth | Loopback redirect + PKCE in the system browser |
| Crash reports | Sentry, **opt-in**, off by default, stack traces only (no content) |

### EvidenceSource contract

Every integration implements one interface: `connect/validate`, `sync(since, until) -> Stream<EvidenceItem>`,
`identityMatchers`, `detailFor(item)`. Items are upserted by `(source, sourceId)`, so syncs are idempotent and incremental.

## 4. Profiles & identity

- **Multiple profiles** (e.g. "Work", "Side projects"), switched from the sidebar.
  Each profile has its own DB file, sources, identities, model routing, templates and schedule.
- Each profile holds several **identities** (emails, GitHub/GitLab usernames, Jira/Linear accounts).
  These are suggested automatically from scanned repos and connected accounts and decide which evidence is "mine".

## 5. Evidence sources

| Source | Auth | Self-hosted | Captures |
|---|---|---|---|
| Local git | — (system `git`) | n/a | Commits on all branches by your identities, diffs, stats |
| GitHub | PAT / device flow | GitHub Enterprise Server (custom API URL) | PRs opened / merged / reviewed, review comments, issues |
| GitLab | PAT | Self-managed (custom URL) | MRs, approvals, comments, issues |
| Google Calendar | OAuth (built-in client + BYO override) | — | Events you attended |
| Apple Calendar | EventKit (macOS only) | — | Everything synced into Calendar.app |
| Outlook / M365 | MS Graph OAuth (built-in client + BYO override) | — | Events |
| ICS | URL or file | — | Events, RRULE expanded |
| Linear | API key | — (cloud only) | Issues created / completed / commented |
| Jira | Cloud: email + API token | Data Center: PAT on custom URL (separate adapter) | Issues transitioned / commented / assigned |
| Meeting transcripts | Drag-drop `.vtt` / `.srt` / `.txt` | — | Matched to the overlapping calendar event, summarized |
| Notes & context | — | — | Generic notes (see §7): standalone, or attached to a day, project, narrative, win or review. May carry images. |
| Recognition | — | — | Praise and kudos: a screenshot (quick-capture region or drag-drop) + **optional link to the original message** + who/where/date. Text extracted by the image-understanding model. Treated as ordinary evidence (star it to make it a win). No Slack/Teams APIs in v1. |

- **Git setup:** scan watched root folders (e.g. `~/Projects`), list repos showing recent activity by your identities,
  tick to include. New repos under watched roots are suggested automatically. Manual add also works.
- **Git detection:** PATH, Homebrew, Xcode CLT, Git for Windows default paths. Detects the macOS `/usr/bin/git` stub
  without triggering it. If git is missing, show a friendly install screen.
- **Self-hosted networking:** a per-connection "trust custom CA certificate" option (plus an explicit insecure toggle with a warning).

## 6. AI providers & routing

- Providers: **OpenRouter**, **OpenAI**, **Anthropic**, **Gemini**, and **custom endpoints**.
- **Custom endpoints** (any number, each named, e.g. "Home GPU box"):
  - **Any URL**: localhost, a machine on the LAN (`http://192.168.1.20:11434`, `http://gpu-box.local:1234`), or a remote
    server (vLLM, llama.cpp server, LiteLLM, LocalAI, a company gateway). Not limited to models on this machine.
  - **Protocol per endpoint:** OpenAI-compatible (`/v1/models`, `/v1/chat/completions`) or Ollama native (`/api/tags`, `/api/chat`).
  - **Optional auth:** API key (Bearer) and/or custom headers, stored in the keychain.
  - **Networking:** plain HTTP allowed (with a warning when the host isn't on a private network); a per-endpoint custom CA
    or "allow self-signed" toggle; configurable timeout (local models can be slow to load).
  - **Test connection** lists the endpoint's models and detects capabilities (vision, context length where reported);
    model names can also be typed by hand when `/models` isn't supported.
  - **Auto-detect** stays as a convenience: `localhost:11434` (Ollama) and `localhost:1234` (LM Studio) are offered at setup.
  - **Privacy label:** endpoints on loopback/private ranges (127.0.0.0/8, 10/8, 172.16/12, 192.168/16, `.local`) are labelled
    "Private network"; anything else "Remote". Remote custom endpoints get the same one-time consent notice as cloud providers.
  - **macOS Local Network permission:** since macOS 15, reaching LAN hosts triggers a system prompt; the app ships
    `NSLocalNetworkUsageDescription` and explains the prompt before the first LAN connection.
  - Custom endpoints work anywhere a model can be chosen (default model, per-task overrides, image understanding).
- Model pickers list live models. OpenRouter shows price and context length.
- **Per-task routing:** one default model, plus optional overrides per task
  (commit summary, transcript summary, **image understanding**, daily, weekly, monthly, Wins, review export).
- **Image understanding** (screenshots in notes and recognition) uses a vision-capable model. If the chosen model
  can't read images, the UI says so and suggests a vision-capable one (e.g. a local `llava`/`qwen2.5-vl` or a cloud model).
  There is no OS OCR. With a cloud model, screenshots leave the machine; the cloud consent notice covers this.
- Streaming output into the editor, with cancel. Token and cost estimate shown before long runs (where pricing is known).
- **Data sent:** full evidence (including diffs and meeting details) goes to whichever provider is configured.
  A one-time consent notice appears when a cloud provider is first enabled. PRIVACY.md and THREAT_MODEL.md get updated to match.

## 7. Core product flow

Ant Manager is a **harness** (DECISIONS #47–#53): evidence goes in, a structured **Narrative** of your work is
maintained from it, and every output reads from that Narrative.

```
 CAPTURE (passive + notes)    NARRATIVE (maintained)            OUTPUTS (read-only views)
 git, PRs, calendar,     →    typed facts, each citing     →    Reports: daily … quarterly, custom
 tickets, transcripts,        evidence: workstreams,            Wins: outcomes + starred evidence
 notes, screenshots           outcomes, problems solved,        Chat / MCP tools (later)
                              invisible work, hiccups,
 user can add evidence        decisions, time allocation
 for any day                  ↑ user confirms / corrects facts
```

- **Home = Today page.** A journal-style day view: the day's evidence grouped by project, next to the day's facts
  and its (read-only) daily report. Notes are added inline. `←/→` (or `[`/`]`) moves between days, and a date picker jumps anywhere.
- **Navigation (sidebar):** profile switcher at the top · Today · Timeline · Narrative · Reports · Wins · Projects ·
  then Sources and Settings at the bottom (tentative, revisited in the UI step of the LLD; "Reviews" are Reports). Notes have no separate tab; they live in Today and Timeline.
- **Notes & context (generic):** notes are evidence. They can be standalone or attached to a day (including past days),
  project, fact, win or report.
  They can include dropped/pasted images and an optional link. Add-note is visible in Today, Timeline and on every
  narrative/win/review, plus the quick-capture hotkey.
- **Change what a report says by changing its inputs:** reports can't be edited. Add evidence (e.g. a note for that day),
  or confirm, correct or reject a fact, then regenerate. Locked reports must be unlocked first; previous versions are
  kept in history.
- **Quick capture** has a text mode and a **screenshot-region mode** (needs Screen Recording permission on macOS,
  the screenshot portal on Linux Wayland). Fields: note, optional link, project, tags (e.g. Recognition).
- **Curation on any evidence item:**
  - **Star / mark as win:** always included in narratives, and added to the Wins log.
  - **Hide / exclude:** left out of generation. Bulk rules supported (e.g. "ignore events titled *Lunch*", "ignore merge commits").
  - **Annotate:** add context the model sees ("took 3 days because of flaky CI").
  - **Projects:** evidence is grouped into projects/themes, auto-suggested from repo, ticket project and the LLM, then
    confirmed or edited by the user. Narratives and reviews are organized by project.
- **Daily nudge:** a gentle notification at the chosen time ("Your day is drafted, 2-minute review?") that opens Today.
  Snooze or skip. Skipped automatically on days with no evidence and on weekends (configurable). No streaks, no scores.
- **Share:** Slack mrkdwn, rich text/HTML for email or Docs, Markdown (copy or file), PDF. Every format is available;
  the default copy format is configurable per profile.

## 8. Narrative, Reports, Wins

- **Narrative = typed facts, each citing evidence:** Workstream, Outcome, Problem solved, Invisible work, Hiccup, Decision,
  Time allocation. Every fact is labelled *model-inferred* or *user-confirmed*; time is *measured* (calendar) or
  *estimated*; "unknown" is allowed. Updated **incrementally** as evidence arrives. User-touched facts are never
  overwritten by the model.
- **Reports** cover **daily, weekly, monthly, quarterly and custom** ranges. Each report queries the Narrative for its
  period and renders it with a template. Reports are **not editable**. **Lock** freezes a report as a snapshot (never
  regenerated, shows "facts changed since lock", can be unlocked). Version history is kept.
- **Generation:** automatic on a configurable schedule (e.g. daily at 18:00, weekly on Monday 09:00) when the tray app
  is running, plus on demand. Missed runs catch up on next launch.
- Every claim in a report links to the **facts and evidence** behind it.
- **Wins = a view** over Outcome facts + starred evidence, plus model-suggested wins you accept or reject. Filterable
  by period and project.
- **Review / brag doc** = a quarterly or custom report with a review template.
- **Templates:** built-in templates (Standup, Manager update, Weekly review, Wins, Brag doc) that can be duplicated and
  edited, with `{variables}`, a live preview against real data, and reset to default. Templates shape wording and
  structure only, never facts.
- **Retrieval-ready:** a full-text index (FTS5) over evidence and facts ships in v1. A query **tool layer**
  (search evidence, get facts, time breakdown, workstream timeline) serves reports and Wins now, and will serve chat
  and an MCP server later.

## 9. Backup & export

- **Two outputs per run:**
  - **Restorable backup:** an `.antbackup` bundle per profile (a consistent SQLite snapshot via `VACUUM INTO` +
    settings, templates, projects, rules, narrative version history, plus a manifest with app/schema version, item counts and a checksum).
  - **Readable export (optional):** Markdown + JSON of narratives, the Wins log, notes, annotations and evidence metadata.
- **Destinations (any combination, configured per profile):**
  - Local folder: any folder, including Drive / iCloud / Dropbox / OneDrive sync folders and external drives.
  - Google Drive API: `drive.file` scope (non-sensitive), reusing the Google OAuth client.
  - OneDrive API: Graph app folder (`Files.ReadWrite.AppFolder`), reusing the Azure registration.
  - Dropbox: OAuth PKCE, app-folder access.
  - WebDAV: covers Nextcloud and other self-hosted storage.
  - S3-compatible: AWS, R2, B2, MinIO, using the user's own keys.
- **Schedule:** daily by default (run by the tray app; catches up if missed), plus "Back up now". Rotation keeps
  7 daily / 4 weekly / 12 monthly copies (configurable). Warns when the last successful backup is older than a threshold.
  Destination status (last success, last error) appears in Settings.
- **Secrets are never included.** API keys and OAuth tokens stay in the OS keychain; after a restore you sign in again.
- **Restore:** pick a backup (from a file or a configured destination), preview it (profile, date range, item counts,
  backup date), then restore into a new profile or replace an existing one. Newer schema versions refuse to restore with a clear message.
  Backups from older versions are migrated on restore.
- **Not sync.** Restoring on another machine is a one-time copy; the live DB must never sit in a shared folder.
- **No encryption in v1:** backups are plaintext. The UI warns when a cloud destination is chosen, since backups
  contain full diffs and meeting details.

## 10. App shell & UX

- **Design direction: Linear.** Dense, keyboard-first, crisp type, subtle depth. Dark-first with a full light theme.
  One unified design system on all OSes, with native window chrome, menu bar and shortcuts per platform.
  Branding keeps the **Ant Manager** name and the current ant logo; the palette is derived from the logo.
- **Design tokens, one source of truth.** Every visual value is a named token defined in exactly one place
  (`lib/ui/tokens/`). Widgets read tokens only, never literals. Changing a token restyles the whole app.
  - **Colour:** semantic roles (`bg`, `surface`, `raised`, `border`, `text`, `muted`, `accent`, `success`, `danger`…),
    with a **dark** and a **light** set. Accent variants (`accentHover`, `accentText`, `onAccent`) are **derived from one
    `accent` seed**, so changing the brand colour is a one-line edit.
  - **Radius:** one `radius` base; the scale (`xs` / `sm` / `md` / `lg` / `xl`) is derived from it. Setting it to 0 makes
    everything square; 10 makes everything rounder.
  - **Also tokenized:** spacing scale, type scale (Inter + JetBrains Mono), elevation/shadows, motion durations and curves,
    icon sizes, and density.
  - **Flutter shape:** an `AntTokens` `ThemeExtension` (with `lerp` for animated theme switches), accessed through
    `context.tokens`. Light and dark are built from the same seed values.
  - **Enforced:** a CI check fails on `Color(0x…)`, `Colors.*`, `BorderRadius.circular(<number>)`, raw `EdgeInsets`
    numbers or `TextStyle(fontSize:)` outside `lib/ui/tokens/`. A widget gallery screen (debug builds) shows every
    component in both themes.
  - Mockup reference: `tokens.css` in the design canvas uses the same names.
- **UX principles (from mockup review, 2026-11-18).** The mockup sets the design *language* only; the final UI must fix these:
  - **Not intimidating.** Progressive disclosure: a new user sees a calm, mostly empty Today and one obvious next action.
    Advanced controls (per-task models, self-hosted URLs, bulk hide rules, roll-up provenance, template editing) sit
    behind "Advanced" or appear only when relevant. Every screen has a helpful empty state. The first week is guided.
  - **Spacing and padding** come from the spacing tokens on a consistent rhythm. Polish the density, alignment and
    hierarchy screen by screen, with a visual review in both themes.
  - **Model settings:** one obvious global model at the top ("Use X for everything"). Per-task overrides are an optional,
    collapsed "Customize per task" section, with an "inherits default" state, so changing the global model updates every inheriting task.
  - **Notes are first-class and easy to find:** a visible "Add note" in Today and Timeline, the quick-capture hotkey,
    and notes with any date, project and tags (exact scope to be confirmed).
- Keyboard: navigation, actions and a command menu for commands (not full-text search, which is out of v1).
- **Menu bar / tray app:** keeps running when the window is closed. Handles sync, scheduled generation,
  "write your day?" nudge notifications and the quick-capture hotkey. Launch at login is optional.
- **Quick capture:** a global hotkey opens a floating note box from anywhere.
- **Onboarding:** create profile → add identities → scan repos → connect optional sources → pick AI provider
  → first generation. Each step can be skipped.
- Diagnostics: a "Copy diagnostics" button with local rotating logs.

## 11. Repo layout

- **Done (2026-11-18):** all previous code moved to `legacy/`: the Flutter app (`legacy/app`, including the Python core
  `legacy/app/core` and the logo assets), the untracked Go port (`legacy/core-go`), the Go docs (`legacy/docs`), and the old
  README / PRIVACY / THREAT_MODEL (to be rewritten for v1). `legacy/` is reference only; nothing new imports from it.
- Root now: `docs/` (SPEC, DECISIONS, OWNER_TODO, design/), `PHILOSOPHY.md` (unchanged), `LICENSE`, `.gitignore`,
  and `web/` + `wrangler.json` (Cloudflare Pages landing site; left in place so deploys keep working).
- The new Flutter project will be created fresh (location set in the low-level design). Firebase is not used.

## 12. Out of scope for v1

Full-text search UI (the index ships in v1), chat interface, MCP server (tool layer is designed for both), backup encryption, mobile, cloud sync between devices, team or manager features, Slack ingestion, local embeddings.

## 13. Owner to-dos (external)

Tracked as a checklist in [OWNER_TODO.md](./OWNER_TODO.md). Summary:

- Apple Developer ID (signing + notarization) and a Windows code-signing cert, when available.
- Google Cloud project: Calendar read-only scope, OAuth consent screen, **verification** (100-user cap with an
  "unverified app" warning until approved; needs a privacy policy URL and a demo video).
- Azure app registration (multi-tenant, public client) for Microsoft Graph.
- Sentry project (DSN) for opt-in crash reports.
- Trial instances for testing GitHub Enterprise and Jira Data Center (GitLab CE runs in Docker).
