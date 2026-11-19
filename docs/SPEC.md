# Ant Manager v1 — Product & Technical Spec

Status: **Scope locked** (2026-11-18); **implemented on `v1`**, independent tests and e2e in progress (known gaps:
[lld/README.md](./lld/README.md)). Greenfield rewrite; no backward compatibility with the Python/Go versions.

## 1. Goal

A polished, self-contained desktop app that captures evidence of your work, maintains a defensible **Narrative**
(typed facts, each citing evidence), and renders it into reports (daily / weekly / monthly / quarterly / custom),
a Wins log and review documents. It's a harness: a future chat and MCP server read the same Narrative (§7–8).

- One download per OS, **no runtime dependencies** (no Python, no Go sidecar, no venv).
- Only external expectation: a system `git`, detected automatically with a guided install if missing.
- Philosophy unchanged — see [PHILOSOPHY.md](../PHILOSOPHY.md): reflection, not surveillance; no scores.

## 2. Platforms & distribution

| Platform | Artifact | Min OS | Notes |
|---|---|---|---|
| macOS | Universal (arm64 + x64) `.app` in `.dmg` | 12+ (Flutter 3.47 minimum) | Sparkle auto-update |
| Windows | Inno Setup `.exe` installer (x64) | Windows 10+ | WinSparkle auto-update |
| Linux | AppImage (x64) | Ubuntu 22.04-class | "Update available" notice; libnotify bundled; tray via D-Bus SNI (#111) |

- **Signing:** pipeline built now (Developer ID + notarization, Authenticode), runs ad-hoc/unsigned until certs exist.
  Release notes document the Gatekeeper / SmartScreen workaround meanwhile.
- **Releases:** GitHub Actions matrix builds all three, publishes to GitHub Releases + appcast feeds.
- **Delivery:** single v1 release with the full scope below (no milestone split).

## 3. Architecture

**Pure Dart in a single Flutter process.** No backend process. Inside the process, a dedicated **engine isolate**
owns the database, jobs, sources and LLM calls; the UI isolate reads via reactive queries and sends commands (#68).

**Code layout: Dart pub workspace** (#45): `app/` (Flutter shell, screens, platform adapters, Swift EventKit bridge),
`packages/core` (pure Dart: database, sources, AI, narrative, reports, staleness, jobs, tool layer, ports),
`packages/ui` (design tokens + components). Full design: [lld/03-class-design.md](./lld/03-class-design.md).

| Concern | Choice |
|---|---|
| State | Riverpod |
| Storage | drift + bundled SQLite (`sqlite3` native assets), per-profile DB file |
| Secrets | OS keychain (macOS Keychain / Windows Credential Manager / libsecret). **Linux requires libsecret**: no fallback, clear error if missing (#77). macOS uses the login keychain until signing exists; App Sandbox is off (#101). |
| HTTP | `dio`, SSE streaming |
| Heavy work | The engine isolate (#68); the UI isolate never does IO or parsing |
| Desktop shell | `window_manager`, `tray_manager`, `hotkey_manager`, `launch_at_startup`, `local_notifier` |
| Updates | `auto_updater` (Sparkle / WinSparkle) |
| OAuth | Loopback redirect + PKCE in the system browser |
| Crash reports | Sentry, **opt-in**, off by default, stack traces only (no content). v1 stores the preference only; DSN pending (#105). |

### Source contract

Every connector implements `Source` (`validate`, `sync` → a stream of payload observations, pull-based from a cursor;
optionally `changes()` to trigger syncs). The Ingestor upserts payloads by `(source, external_id)`, so syncs are
idempotent and incremental. Details: [lld/03-class-design.md §3.4](./lld/03-class-design.md).

## 4. Profiles & identity

- **Multiple profiles** (e.g. "Work", "Side projects"), switched from the sidebar.
  Each profile has its own DB file, sources, identities, model routing, templates and schedule.
- **Only the active profile runs** (#77): the tray syncs and runs schedules for the profile you're on. Other profiles
  catch up when you switch to them.
- Each profile holds several **identities** (emails, GitHub/GitLab usernames, Jira/Linear accounts).
  These are suggested automatically from scanned repos and connected accounts and decide which evidence is "mine".
- Each profile has **one time zone** (defaults to the system's) that defines day boundaries for evidence, facts and
  reports (#87), resolved with a bundled IANA tz database (#109).

## 5. Evidence sources

| Source | Auth | Self-hosted | Captures |
|---|---|---|---|
| Local git | — (system `git`) | n/a | Commits on all branches by your identities, diffs, stats |
| GitHub | PAT (device flow later, #106) | GitHub Enterprise Server (custom API URL) | PRs opened / merged / reviewed, review comments, issues opened / closed / commented (#106) |
| GitLab | PAT | Self-managed (custom URL) | MRs, approvals, comments, issues opened / closed / commented (#106) |
| Google Calendar | OAuth (built-in client only, #76) | — | Events you attended |
| Apple Calendar | EventKit (macOS only) | — | Everything synced into Calendar.app |
| Outlook / M365 | **ICS feed only** (paste the calendar's ICS link, #82). No Graph OAuth. | — | Events |
| ICS | URL or file | — | Events, RRULE expanded |
| Linear | API key | — (cloud only) | Issues created / completed / commented |
| Jira | Cloud: email + API token | **None: Jira Cloud only** (#81) | Issues transitioned / commented / assigned |
| Meeting transcripts | Drag-drop `.vtt` / `.srt` / `.txt` | — | Becomes a payload; **suggested** for attaching to the overlapping calendar event (you confirm, per the grouping rules), then summarized |
| Notes & context | — | — | Generic notes (see §7): a note payload, either standalone evidence on any day or attached to an existing evidence item. May carry images and a link. |
| Recognition | — | — | Praise and kudos: a screenshot (quick-capture region or drag-drop) + **optional link to the original message** + who/where/date. Text extracted by the image-understanding model. Treated as ordinary evidence (star it to make it a win). No Slack/Teams APIs in v1. |

- **Git setup:** scan watched root folders (e.g. `~/Projects`), list repos showing recent activity by your identities,
  tick to include. New repos under watched roots are suggested automatically. Manual add also works.
- **Git detection:** PATH, Homebrew, Xcode CLT, Git for Windows default paths. Detects the macOS `/usr/bin/git` stub
  without triggering it. If git is missing, show a friendly install screen.
- **Self-hosted networking:** a per-connection "trust custom CA certificate" option (plus an explicit insecure toggle with a warning). *Not built yet for sources; providers have it (§6).*
- **Sync:** each source is due 15 min after its last success (ICS 60 min), watched sources included; status (last success,
  last error) is shown per source. Removing a source only disables it (evidence kept) (#102); re-adding
  a removed git repo re-enables that source instead of adding a duplicate (#115).

## 6. AI providers & routing

- Providers: **OpenRouter**, **OpenAI**, **Anthropic**, **Gemini**, and **custom endpoints**.
- **Custom endpoints** (any number, each named, e.g. "Home GPU box"):
  - **Any URL**: localhost, a machine on the LAN (`http://192.168.1.20:11434`, `http://gpu-box.local:1234`), or a remote
    server (vLLM, llama.cpp server, LiteLLM, LocalAI, a company gateway). Not limited to models on this machine.
  - **Protocol per endpoint:** OpenAI-compatible (`/v1/models`, `/v1/chat/completions`) or Ollama native (`/api/tags`, `/api/chat`).
  - **Optional auth:** API key (Bearer) and/or custom headers, stored in the keychain.
  - **Networking:** plain HTTP allowed (warning shown for any non-localhost host); a per-endpoint custom CA
    or "Disable TLS verification" toggle (`allowSelfSigned`, with a warning, #108); configurable timeout (local models can be slow to load).
  - **Test connection** lists the endpoint's models and detects capabilities (vision, context length where reported);
    model names can also be typed by hand when `/models` isn't supported.
  - **Structured output is required** (#70): adding any model (local, network or cloud) runs a probe call; models without
    native JSON-schema output are rejected with a clear message.
  - **Auto-detect** stays as a convenience: `localhost:11434` (Ollama) and `localhost:1234` (LM Studio) are offered at setup.
  - **Consent:** every provider that isn't on this machine (anything but `localhost`/loopback, LAN included) gets the
    one-time consent notice, per base URL (changing the URL asks again, #105). No private/remote network classification (#74).
  - **macOS Local Network permission:** since macOS 15, reaching LAN hosts triggers a system prompt; the app ships
    `NSLocalNetworkUsageDescription` and explains the prompt before the first LAN connection.
  - Custom endpoints work anywhere a model can be chosen (Default, Vision, Extraction, Reports).
- Model pickers list live models. OpenRouter shows price and context length.
- **Routing: four routes only** (#75): **Default** (the global model), plus optional overrides for **Vision**
  (image understanding), **Extraction** (importance, enrichment text, facts, win suggestions) and **Reports**.
  Unset routes inherit Default.
- **Image understanding** (screenshots in notes and recognition) uses a vision-capable model. If the chosen model
  can't read images, the UI says so and suggests a vision-capable one (e.g. a local `llava`/`qwen2.5-vl` or a cloud model).
  There is no OS OCR. With a cloud model, screenshots leave the machine; the cloud consent notice covers this.
- Streaming output into the report view, with cancel. Token and cost estimate shown before long runs (where pricing is known).
- **Data sent:** full evidence (including diffs and meeting details) goes to whichever provider is configured.
  A one-time consent notice appears when any non-localhost provider is first enabled (#74). See [PRIVACY.md](../PRIVACY.md) and [THREAT_MODEL.md](../THREAT_MODEL.md).

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
- **Notes & context (generic):** notes are evidence (a note payload). A note is either standalone evidence on any day
  (including past days) or attached to an existing evidence item; it can include images and a link. "Add context" on a
  report or win creates a note dated inside that period. Add-note is visible in Today, Timeline, reports and Wins, plus
  the quick-capture hotkey (#83). Notes never attach to facts: correct the fact instead.
- **Change what a report says by changing its inputs:** reports can't be edited. Add evidence (e.g. a note for that day),
  or confirm, correct or reject a fact, then regenerate. Locked reports must be unlocked first; previous versions are
  kept in history.
- **Quick capture** has a text mode and a **screenshot-region mode** (needs Screen Recording permission on macOS,
  the screenshot portal on Linux Wayland). Fields: note, optional link, project. No tags in v1 (#84).
- **Curation on any evidence item:**
  - **Star / mark as win:** maximum importance, and creates or upgrades an Outcome fact marked as an accepted win (#63).
  - **Hide / exclude:** importance 0, left out of the Narrative. Bulk **CurationRules** also set weights ("treat *Daily sync* as low", "hide *Lunch*", #60).
  - **Annotate:** add a note payload to the evidence ("took 3 days because of flaky CI"); the model sees it (#56).
  - **Projects:** evidence and facts are grouped into projects, auto-suggested by the Extraction model, then
    confirmed or edited by the user. Reports are organized by project.
  - **Delete permanently** (#85): the one exception to never deleting history, for things captured by mistake. It purges
    the evidence, all its payload revisions, attachments, enrichments and index entries; facts left with no citations are
    deleted with their history. Existing backups are not touched (the UI says so).
- **Daily nudge:** a gentle notification at the chosen time ("Your day is drafted, 2-minute review?") that opens Today.
  Snooze or skip (snooze not built yet). Default weekdays 18:05; skipped automatically on days with no evidence;
  "Include weekends" adds Sat/Sun to it and the daily report (#105). No streaks, no scores.
- **Share:** Slack mrkdwn, rich text/HTML for email or Docs, Markdown (copy or file), PDF. Every format is available;
  the default copy format is configurable per profile. Rich-text copy and image paste use a small native clipboard
  channel on macOS (#107).

## 8. Narrative, Reports, Wins

- **Narrative = typed facts, each citing payload revisions:** Outcome, Problem solved, Invisible work, Hiccup, Decision,
  Time allocation, grouped into **Workstreams** (#65). Every fact is labelled *model-inferred* or *user-confirmed*; time is *measured* (calendar) or
  *estimated*; "unknown" is allowed. Updated **incrementally** as evidence arrives. User-touched facts are never
  overwritten by the model.
- **Reports** cover **daily, weekly, monthly, quarterly and custom** ranges. Each report queries the Narrative for its
  period and renders it with a template. Reports are **not editable**. **Lock** freezes a report as a snapshot (never
  regenerated, shows "facts changed since lock", can be unlocked). Version history is kept. A report is **out of date**
  when any input under it changed (transitively, down to payloads) or a new fact appeared in its period (#104).
- **Generation:** automatic on a configurable schedule (e.g. daily at 18:00, weekly on Monday 09:00) when the tray app
  is running, plus on demand. Scheduled runs use the period kind's default built-in template (#108). Missed runs **catch up once** on next launch: only the latest due run, not every missed one (#79).
- Every claim in a report links to the **facts and evidence** behind it (Markdown footnotes `[^fN]: <statement> (fact:<id>)`, #108).
- **Wins = a view** over Outcome facts + starred evidence, plus model-suggested wins you accept or reject. Filterable
  by period and project. Starred evidence counts as having a win only once an accepted Outcome fact cites it (#115).
- **Review / brag doc** = a quarterly or custom report with a review template.
- **Templates:** built-in templates (Standup, Manager update, Weekly review, Monthly recap, Wins summary, Brag doc) that
  can be duplicated and edited (editing a built-in duplicates it; copies keep their origin for reset, #108), with
  `{period_label}`, `{period_kind}`, `{start}`, `{end}`, a live preview against real data, and reset to default. Templates shape wording and
  structure only, never facts.
- **Retrieval-ready:** a full-text index (FTS5) over evidence and facts ships in v1. A query **tool layer**
  (search evidence, get facts, time breakdown, workstream timeline) serves reports and Wins now, and will serve chat
  and an MCP server later.

## 9. Backup & export

- **Two outputs per run:**
  - **Restorable backup:** an `.antbackup` bundle per profile (a consistent SQLite snapshot via `VACUUM INTO` +
    settings, templates, projects, rules, narrative version history, plus a manifest with app/schema version, item counts and a checksum).
  - **Readable export (optional):** Markdown + JSON of facts, report snapshots, the Wins log, notes and evidence metadata,
    rewritten each run into `<profile>-export/` next to the backups (layout: #108).
- **Destination: a local folder only** (#80): any folder, including Google Drive / iCloud / Dropbox / OneDrive sync
  folders and external drives. Cloud backup = pick a synced folder. No cloud-storage API connectors.
- **Schedule:** daily by default (run by the tray app; catches up once if missed), plus "Back up now". **Keeps the last
  N backups** (default 14) (#78). Warns when the last successful backup is older than a threshold.
  Backup status (last success, last error) appears in Settings; options live in profile Settings (#105).
- **Secrets are never included.** API keys and OAuth tokens stay in the OS keychain; after a restore you sign in again.
- **Restore:** pick a backup file, preview it (profile, date range, item counts,
  backup date), then restore into a **new profile** ("… (restored)"), never over an existing one (#105); a failed restore leaves no profile, database file or attachments
  behind (#115). Newer schema versions refuse to restore with a clear message.
  Backups from older versions are migrated on restore.
- **Not sync.** Restoring on another machine is a one-time copy; the live DB must never sit in a shared folder.
- **No encryption in v1:** backups are plaintext. Settings states this, since a synced folder puts full diffs and
  meeting details in that cloud.

## 10. App shell & UX

- **Design direction: Linear.** Dense, keyboard-first, crisp type, subtle depth. Dark-first with a full light theme.
  One unified design system on all OSes, with native window chrome, menu bar and shortcuts per platform.
  Branding keeps the **Ant Manager** name and the current ant logo; the palette is derived from the logo.
- **Design tokens, one source of truth.** Every visual value is a named token defined in exactly one place
  (`packages/ui/lib/src/tokens/`). Widgets read tokens only, never literals. Changing a token restyles the whole app.
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
    numbers or `TextStyle(fontSize:)` outside the tokens folder (`packages/ui/tool/check_tokens.dart`). A widget gallery screen (debug builds) shows every
    component in both themes.
  - Mockup reference: `tokens.css` in the design canvas uses the same names.
- **UX principles (from mockup review, 2026-11-18).** The mockup sets the design *language* only; the final UI must fix these:
  - **Not intimidating.** Progressive disclosure: a new user sees a calm, mostly empty Today and one obvious next action.
    Advanced controls (model overrides, self-hosted URLs, curation rules, template editing) sit
    behind "Advanced" or appear only when relevant. Every screen has a helpful empty state. The first week is guided.
    Until there is data, a page shows one explanation, not empty controls or filters (#113).
  - **Spacing and padding** come from the spacing tokens on a consistent rhythm. Polish the density, alignment and
    hierarchy screen by screen, with a visual review in both themes.
  - **Model settings:** one obvious global model at the top ("Use X for everything"). The three overrides (Vision,
    Extraction, Reports) sit in a collapsed section with an "inherits default" state (#75).
  - **Notes are first-class and easy to find:** a visible "Add note" in Today and Timeline, the quick-capture hotkey,
    and notes on any date with an optional project (no tags in v1, #84).
- Keyboard: navigation, actions and a command menu for commands (not full-text search, which is out of v1).
- **Menu bar / tray app:** keeps running when the window is closed. Handles sync, scheduled generation,
  "write your day?" nudge notifications and the quick-capture hotkey. Launch at login is optional.
- **Quick capture:** a global hotkey opens a floating note box from anywhere (on macOS the main window shrinks to it, #101).
- **Onboarding:** welcome (what the app is, how it works: Sources → Evidence → Narrative → Reports and wins, plus
  local first / always cited / yours to correct, #114) → create profile → add identities → scan repos → connect optional sources → pick AI provider
  (structured-output probe) → first import and report. Each step can be skipped. Shown once for a profile with no
  identities and no sources, until finished or skipped (#105).
- Diagnostics: a "Copy diagnostics" button with local rotating logs.
- **English only** in v1 (#87); no localization framework.

## 11. Repo layout

- **Done (2026-11-18):** all previous code moved to `legacy/`; **removed (2026-11-20, #112)**: the old app, Python core,
  Go port and docs live only in git history (before `legacy/` was deleted). [PRIVACY.md](../PRIVACY.md) and [THREAT_MODEL.md](../THREAT_MODEL.md) are rewritten for v1 at the root.
- Root: `docs/`, `PHILOSOPHY.md`, `LICENSE`, `web/` + `wrangler.json` (Cloudflare Pages site; left in place),
  v1 code in `app/`, `packages/core`, `packages/ui` (#45), plus `packaging/`, `scripts/` and `.github/workflows/`.
  Firebase is not used. Dev builds can use `--dart-define=ANT_DATA_DIR=…` for a separate data folder (#107).

## 12. Out of scope for v1

Full-text search UI (the index ships in v1), chat interface, MCP server (tool layer is designed for both), backup encryption, mobile, cloud sync between devices, team or manager features, Slack ingestion, local embeddings.

## 13. Owner to-dos (external)

Tracked as a checklist in [OWNER_TODO.md](./OWNER_TODO.md). Summary:

- Apple Developer ID (signing + notarization) and a Windows code-signing cert, when available.
- Google Cloud project: Calendar read-only scope, OAuth consent screen, **verification** (100-user cap with an
  "unverified app" warning until approved; needs a privacy policy URL and a demo video).
- Sentry project (DSN) for opt-in crash reports.
- A GitHub OAuth App with device flow (until then GitHub is PAT only, #106).
- Sparkle EdDSA keys + appcast hosting for auto-update.
- A trial instance for testing GitHub Enterprise (GitLab CE runs in Docker).
