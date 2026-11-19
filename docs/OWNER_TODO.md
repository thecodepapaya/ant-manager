# Owner To-Do (things only you can do)

External accounts, registrations and decisions needed for the v1 rewrite ([SPEC.md](./SPEC.md)).
None of these block development; placeholders are used until each is done. Tick items off as you complete them.

## Signing & distribution
- [ ] **Apple Developer Program** ($99/yr) → create a *Developer ID Application* certificate. Export it as a `.p12` and add it to GitHub Actions secrets with an app-specific password or App Store Connect API key for notarization.
- [ ] **Windows code-signing certificate** (OV/EV, or Azure Trusted Signing) → add to CI secrets. Until then SmartScreen warns users.
- [ ] Decide the **bundle ID** (e.g. `com.<you>.antmanager`). It's used by signing, OAuth redirects and keychain entries, so it's hard to change later.
- [ ] Host **appcast feeds** (GitHub Releases works; or under the `web/` site via Cloudflare). Confirm which domain.
- [ ] Generate a **Sparkle EdDSA key pair** for update signing and store the private key in CI secrets. (I'll give you the command.)
- [ ] **Protect release tags:** GitHub → Settings → Rules → add a tag ruleset for `v*` so only you can create them. Every `v*` tag publishes a public release ([RELEASE.md](./RELEASE.md)).
- [ ] **Cut the first release** when ready: bump `app/pubspec.yaml`, tag `vX.Y.Z`, push ([RELEASE.md](./RELEASE.md)).

- [ ] After signing exists: switch secrets to the data-protection keychain (`keychain-access-groups`), enable hardened runtime, review entitlements (DECISIONS #101).

## Google Calendar
- [ ] Create a **Google Cloud project**, enable the Calendar API.
- [ ] Configure the **OAuth consent screen** (external, scope `calendar.readonly`) and create a *Desktop app* OAuth client. Give me the client ID (and the non-confidential desktop secret). They replace the `TODO_GOOGLE_CLIENT_ID` / `TODO_GOOGLE_CLIENT_SECRET` placeholders in `packages/core/lib/src/capture/sources/google_oauth.dart`. Until verified, refresh tokens of a testing-mode app expire after 7 days.
- [ ] Publish a **privacy policy URL** and **home page** (the `web/` site can host both).
- [ ] Submit for **sensitive-scope verification**: demo video plus written justification. Takes weeks. Until approved: an "unverified app" warning and a 100-user cap.

~~Microsoft / Outlook (Azure app registration)~~: **removed.** Outlook is supported via ICS links only (DECISIONS #82).
~~Backup destinations (Drive scope, Azure permission, Dropbox app)~~: **removed.** Backups go to a local folder only (#80).

## GitHub
- [ ] Register a **GitHub OAuth App** with **device flow enabled** (Settings → Developer settings → OAuth Apps) and give me the client ID. Until then GitHub sign-in is PAT only (DECISIONS #106).

## Crash reporting
- [ ] Create a **Sentry project** (free tier is fine) and give me the DSN. Reports stay opt-in in the app.

## Testing infrastructure
- [ ] **GitHub Enterprise Server** trial licence (or access to a real GHES instance) for self-hosted testing.
- [ ] Test accounts: Linear workspace, Jira Cloud site, an Outlook / M365 account (for its ICS link) and a Google account with sample calendar data.
- [ ] **Smoke-test the unsigned installers** from a CI build on a real Windows 10/11 PC and a Linux desktop (install, launch, tray icon). CI builds them but can't run them. On Linux also check a token saves (needs gnome-keyring or KWallet running) and the tray icon on GNOME (AppIndicator extension).
- [ ] (GitLab self-managed: I'll run GitLab CE in Docker. Nothing needed from you.)

## Content & legal
- [ ] Review the v1 **[PRIVACY.md](../PRIVACY.md) / [THREAT_MODEL.md](../THREAT_MODEL.md)** (rewritten 2026-11-20: "send everything" to the chosen provider, opt-in crash reports not wired yet, plaintext backups, known gaps). The `web/` landing page still says the app is "completely offline"; decide whether to reword it and link these docs.
- [ ] Update the **web/ landing page** with new download links once release artifacts exist.
- [ ] Approve the **design direction** (palette from the logo, Linear-style) when I present it.
- [ ] Provide an **SVG version of the logo** (vector source for the app icon, installers, web site and in-app branding; the current logo is raster only).
- [ ] Share **ideas / sketches for the menu-bar logo** (silhouette, single ant vs. abstract mark, filled vs. outline) so I can draft options.
- [ ] Approve a **menu-bar / tray icon**: a simplified single-colour single-ant version of the logo (two ants don't read at 16–22 px; macOS wants a template image). The full logo is used everywhere else.
