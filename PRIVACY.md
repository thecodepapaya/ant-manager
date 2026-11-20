# Privacy

Ant Manager is personal, local-first software ([PHILOSOPHY.md](./PHILOSOPHY.md)). This page says what it collects,
where that lives, and what leaves your machine. It describes v1 as built; [docs/SPEC.md](./docs/SPEC.md) is the
authoritative spec and [THREAT_MODEL.md](./THREAT_MODEL.md) covers attacks and known gaps.

There are no Ant Manager servers. Nothing is sent to the project or its authors.

## What is collected

Only from sources you add. Git, GitHub and GitLab match the identities (emails, usernames) you list in a profile;
Linear and Jira use the connected account; calendars capture the calendars you connect (SPEC §4–5):

| Source | What is stored |
|---|---|
| Local git | Commits on all branches whose author or committer email is yours: message, stats, and the full diff (diffs over 200 KB are dropped, the commit is kept). |
| GitHub / GitLab | PRs/MRs that involve you or that you reviewed (title, description, state, merge time), review comments, approvals, and issues you opened, closed or commented on. |
| Linear / Jira Cloud | Issues you created, completed, transitioned, were assigned or commented on. |
| Google / Apple Calendar, ICS | Events: title, times, description, location, attendee count, and organizer where the source provides it (not Apple). Apple Calendar reads every calendar in Calendar.app. |
| Transcripts | `.vtt` / `.srt` / `.txt` files you drop in. |
| Notes, recognition, screenshots | Text, links and images you add, including quick-capture region screenshots (macOS). |

The app also stores what it derives from these: per-item summaries and importance scores, Narrative facts with their
history, reports and their versions, projects, curation rules, templates and settings.

It does not record the screen in the background, log keystrokes, record audio, or score you.

## Where it is stored

All on your machine, under the OS application-support folder (`…/ant_manager/`):

- `profiles/<id>.sqlite`: one SQLite database per profile (evidence, facts, reports, settings).
- `blobs/<id>/`: attachments (screenshots, images) per profile.
- `app.sqlite`: profile list, AI providers and models (base URLs, custom CA, header names; no secret values).
- `logs/`: local diagnostic logs (#126), `ui.log` and `engine.log`, each rotated at 1 MB keeping 3 files (about
  3 MB each, oldest lines dropped). Lines are structural: timestamps, event names, job and source kinds, random
  ids, counts, durations, AI route, provider kind, provider **host name**, model name, token counts, HTTP status, and
  error type with a redacted message and the top stack frames. They are built to leave out secrets and tokens,
  evidence content, prompts and model output, fact statements, note text, source, provider and profile names, URLs,
  file paths and email addresses: AI errors are logged as type and HTTP status only, and other error text is
  redacted before it is written (URLs, emails, paths, quoted text, JSON bodies and key-like strings removed), so some
  detail is lost on purpose. Redaction is pattern-based, so an unusual fragment in an error message could slip
  through (THREAT_MODEL.md §7).
- **Secrets** (source tokens, Google OAuth tokens, provider API keys, custom header values) are kept in the OS secret
  store, never in the databases:
  - macOS: the login keychain (the data-protection keychain needs a signed build, DECISIONS #101).
  - Windows: via `flutter_secure_storage` 4.1.0, which encrypts all values with DPAPI (tied to your Windows login)
    into `flutter_secure_storage.dat` in the app-support folder.
  - Linux: libsecret (GNOME Keyring / KWallet). Required; there is no fallback (#77).

The databases and attachments are **not encrypted** at rest; they rely on your OS account and disk encryption.

## What leaves your machine

Only these, and only once you set them up:

1. **The AI provider(s) you configure** (OpenRouter, OpenAI, Anthropic, Gemini, or a custom endpoint). Each
   enrichment, extraction and report call sends evidence content from **every source**: diffs, PR and issue text,
   meeting details, transcripts, screenshots and notes (DECISIONS #17). There is no per-source filter. Long items are
   cut to an excerpt (about 6,000 characters per item for summaries, 1,500 for fact extraction); reports send facts,
   not raw evidence. That provider's own privacy policy applies.
   - A provider on `localhost` / loopback keeps everything on this machine.
   - Any other address (LAN included) shows a one-time consent notice before the first request, per base URL;
     changing the URL asks again (#74, #105). Plain `http://` to a non-local host shows a warning.
   - Consent is checked on every request: if you decline after changing a provider's URL, the new URL is saved but
     nothing is sent to it until you agree (#118).
2. **The source APIs you connect** (GitHub / GitHub Enterprise, GitLab, Linear, Jira Cloud, Google Calendar, ICS
   URLs). The app sends your token and fetches your activity; it never writes to them.
   Google sign-in uses the system browser with PKCE and a loopback redirect.
3. **Crash reports: opt-in, off by default** (#8, #105). Intended to send stack traces only, no content, to Sentry.
   **Not wired yet:** v1 only stores the preference and sends nothing.

Nothing else: no analytics, no usage telemetry, no background uploads. Logs never leave the machine on their own:
**Settings → General → Copy diagnostics** puts a plain-text report on your clipboard for a bug report (app, OS,
Flutter and Dart versions; profile count; per source its kind, enabled flag and last sync status; providers by
kind and loopback or remote with model counts; database schema versions; job counts; the last 200 log lines). It has
no names, URLs or credentials; read it before you paste it anywhere.

**Auto-update is not wired yet** (docs/lld/README.md "Known gaps"): the app does not check for updates. When it is,
it will fetch an appcast feed (Sparkle / WinSparkle). Download new versions from GitHub Releases meanwhile.

Links you open (evidence links, the git download page) open in your browser.

## Backups and export

- Backups go to **a local folder you choose** (default `…/ant_manager/backups/<profile>/`), daily plus "Back up now",
  keeping the last 14 (#78, #80). There are no cloud-storage connectors: if you pick a Drive / iCloud / Dropbox /
  OneDrive folder, that service gets a copy.
- An `.antbackup` is a zip of the profile database snapshot, its attachments and a manifest. **It is not encrypted**
  (#36); Settings says so.
- **Secrets are never included.** Providers live in `app.sqlite` and are not backed up either. A restored profile's
  sources have no credentials and start disabled: sign in to each again (#118).
- The optional readable export (`<profile>-export/`, Markdown + JSON of facts, reports, wins, notes and evidence
  metadata) is rewritten on each backup. It has no source configs or credential references (#108).

## Deleting data

- **Delete permanently** on an evidence item (SPEC §7, LLD 04 §4.12, #85) removes it, all its payload revisions,
  attachments, summaries and search-index entries, and deletes facts left with no citations (with their history).
  There is no undo.
- It does not touch existing backups, the last readable export (until the next backup rewrites it), locked reports,
  or anything already sent to an AI provider. SQLite may keep deleted bytes in free pages until they are reused
  (unverified: no `secure_delete` or vacuum is run).
- **Hide** only sets importance to 0; the data stays. **Removing a source** only disables it: its evidence and stored
  token are kept (#102).
- To remove everything, quit the app and delete the `ant_manager` folder, your backup folder, and the app's
  entries in your keychain / Credential Manager / libsecret.

## Your responsibility

- Make sure you may store and send to an AI provider what your sources contain (employer code, meeting content).
- Get consent where the law requires it before importing meeting transcripts.
- Protect your device, your account and wherever you keep backups.
