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
| 5 | **Tech picks** (mine, not contested): Riverpod, drift + bundled sqlite3, dio, isolates, window_manager / tray_manager / hotkey_manager / launch_at_startup / local_notifier, auto_updater, sentry_flutter, flutter_secure_storage (Linux: libsecret with an encrypted-file fallback). | Standard, maintained Flutter desktop packages. |

## 2. Distribution & operations

| # | Decision | Rationale / context |
|---|---|---|
| 6 | **In-app auto-update:** Sparkle (macOS) / WinSparkle (Windows) via an appcast from GitHub Releases; Linux shows an "update available" notice. | Polished-product expectation. |
| 7 | **Delivery: all at once** (one big v1). | The owner rejected my 3-milestone plan. I'll still build so the app runs end to end early, with every integration behind one `EvidenceSource` interface. |
| 8 | **Telemetry: opt-in crash reports** (Sentry, off by default, stack traces only), plus local logs and "Copy diagnostics". | The owner chose opt-in over "none". PRIVACY.md must change: it previously promised no telemetry. |

## 3. Profiles & sources

| # | Decision | Rationale / context |
|---|---|---|
| 9 | **Multiple profiles** (e.g. Work / Side projects), each with its own DB file, sources, identities, models, templates, schedule and backups. Each profile has multiple identities (emails/usernames). | Owner's choice over "multi-email single profile". |
| 10 | **Calendars:** Google (OAuth), Apple (EventKit Swift bridge, macOS only), Outlook/M365 (Graph), ICS URL/file. | The Google `calendar.readonly` scope is *sensitive*: verification is needed, and there's a 100-user cap plus an "unverified app" warning until it's approved. |
| 11 | **OAuth clients:** the owner registers Google + Azure clients that ship in the app (PKCE), with a BYO client-ID override. | One-click sign-in for users; power users can bring their own. |
| 12 | **More sources:** GitHub, GitLab, Linear, Jira, meeting transcripts (.vtt/.srt/.txt matched to calendar events). | Catches work local git can't see (reviews, tickets, meetings). |
| 13 | **Self-hosted support:** GitHub Enterprise Server (custom API URL), GitLab self-managed, Jira Data Center (separate adapter: API v2, PAT, usernames), plus a custom-CA trust option. | The owner asked "why do we need self-hosted?" Answer: the core audience (enterprise devs writing reviews) often works on internal servers. GHES/GitLab are nearly free to support (same API, different URL); Jira DC costs a medium amount. Owner: "let's support self hosted". |
| 14 | **Repo setup:** scan watched root folders, list repos with recent activity by your identities, tick to include, auto-suggest new repos; manual add too. | Lower setup friction than picking folders one by one. |

## 4. AI

| # | Decision | Rationale / context |
|---|---|---|
| 15 | **Providers:** OpenRouter, OpenAI, Anthropic, Gemini, and **custom endpoints**: any number of named URLs (localhost, **LAN machines**, or remote servers), OpenAI-compatible or Ollama-native, with optional API key/headers, HTTP or custom-CA TLS, and connection test + model listing. Localhost Ollama/LM Studio auto-detection kept as a convenience. | Owner request ("add option to set a url for openai compatible endpoint instead of local models. they may be on the local network"): models often run on a separate GPU box. Private-network endpoints are labelled as such; remote ones get the cloud consent notice. Note: macOS 15+ shows a Local Network permission prompt for LAN hosts. |
| 16 | **Per-task model routing:** one default + optional per-task overrides. | E.g. a cheap local model for commit summaries, a strong cloud model for reviews. **UX correction (from mockup review):** the global model must be the obvious primary control; per-task overrides go in a collapsed "Customize per task" with an "inherits default" state. |
| 17 | **Privacy: send everything** (full diffs, meeting details, transcripts, screenshots) to whichever provider is configured. | The owner rejected per-source toggles. Mitigation: a one-time consent notice when a cloud provider is first enabled. PRIVACY.md / THREAT_MODEL.md must be rewritten (they promised "only the text required is sent"). |
| 18 | **Image understanding** is its own per-task model setting, using a **vision model only** (no OS OCR). | The owner chose vision-model-only over on-device OCR. If the chosen model can't read images, the UI says so and suggests one (local `llava`/`qwen2.5-vl`, or cloud). With a cloud model, screenshots leave the machine; this is covered by the consent notice. |

## 5. Core product flow

| # | Decision | Rationale / context |
|---|---|---|
| 19 | **Loop: Capture → Review → Narrate → Share.** | Replaces the old disconnected Timeline/Notes/Narrative/Wins tabs with one daily habit; your daily curation improves everything downstream. |
| 20 | **Home = Today page:** the day's evidence grouped by project, beside that day's narrative draft. | It fits "reflection" and the daily loop. *Rejected:* timeline feed as home, inbox as home. |
| 21 | **Narrative periods:** daily, weekly, monthly, custom range. | Owner's choice. |
| 22 | **Generation:** automatic on a **configurable schedule** + on demand anytime; narratives are **editable** (an edit locks against auto-regeneration; regenerate with an instruction; version history). | The owner wrote this answer in their own words. |
| 23 | **Hybrid roll-up:** weekly is built from the (edited) dailies + starred evidence + annotations, using raw evidence for days without a daily; monthly is built from weeklies. | User edits carry forward and prompts stay bounded over long ranges. *Rejected:* strict roll-up (misses days with no daily), always-raw (ignores edits, huge prompts). |
| 24 | **Curation on evidence (all four):** star/mark as win, hide/exclude (with bulk rules), annotate (the model sees it), group into projects (auto-suggested, user-confirmed). | Owner picked all four. |
| 25 | **Wins = a living Wins log:** starred items + model-suggested wins the user accepts or rejects, with citations; it feeds review export. | Replaces per-period Wins generation. |
| 26 | **Daily nudge:** a gentle notification at the chosen time; skipped on empty days and weekends (configurable). **No streaks.** | Streaks conflict with the "no scores" philosophy (PHILOSOPHY.md). |
| 27 | **Share formats:** Slack mrkdwn, rich text/HTML, Markdown, PDF; the default is configurable. | Owner: "configurable from all of these". |
| 28 | **Navigation:** profile switcher · Today · Timeline · Narratives · Wins · Projects · Reviews · (bottom) Sources, Settings. | No separate Notes tab, because notes live everywhere (see 30). |
| 29 | **Prompt templates per output** (Standup, Manager update, Weekly review, Wins, Brag doc): duplicable, editable, with variables, live preview and reset. | More approachable than raw prompt fields. |
| 30 | **Generic notes & context:** notes can be standalone or attached to a day, project, narrative, win or review, and can carry images and a link. **Anything not locked can be regenerated with added context.** Day notes must be easy to find. | Owner: "Until things are not locked, I should be able to add context and regenerate anything based on additional context." The mockup's note entry points were too hard to find. |
| 31 | **Recognition / praise:** capture by quick-capture **screenshot-region mode** or drag-drop into any add-note flow, with an **optional link to the original message** (so anyone can navigate to it) and who/where/date. Text read by the image-understanding model. **Just evidence** (star it to make it a win). No Slack/Teams APIs. | Chat APIs need workspace/tenant admin approval, while screenshots work with any app. Region capture needs macOS Screen Recording permission (asked on first use). |
| 32 | **Extra v1 features:** review/brag-doc export (with citations), global quick-capture hotkey, GitHub/GitLab PRs & reviews. **Full-text search is out of v1** (offered, not picked). | |
| 33 | **Background:** a menu bar / tray app that hosts sync, scheduled generation, nudges, the hotkey and backups. | Required for scheduled work and the global hotkey. |

## 6. Backup & export (the owner's idea)

| # | Decision | Rationale / context |
|---|---|---|
| 34 | **Outputs:** a restorable `.antbackup` bundle (`VACUUM INTO` snapshot + manifest) **and** an optional Markdown/JSON readable export. | Backup is for disaster recovery; export is for owning your data. |
| 35 | **Destinations (all):** local folder (also covers Drive/iCloud/Dropbox/OneDrive sync folders), Google Drive API (`drive.file`, non-sensitive), OneDrive API (app folder), Dropbox, WebDAV, S3-compatible. | |
| 36 | **No encryption in v1** (owner: "encryption out of scope for now"). | Backups are plaintext; the UI warns for cloud destinations. It may return later without a format change. |
| 37 | **Schedule:** daily via the tray + "Back up now"; rotation 7 daily / 4 weekly / 12 monthly; stale-backup warning. | |
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
