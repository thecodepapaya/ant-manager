# Owner To-Do (things only you can do)

External accounts, registrations and decisions needed for Ant Manager (v1 is on `main`; ongoing work on `v1.1`) ([SPEC.md](./SPEC.md)).
None of these block development; placeholders are used until each is done. Tick items off as you complete them.

## Signing & distribution
- [ ] **Apple Developer Program** ($99/yr) → create a *Developer ID Application* certificate. Export it as a `.p12` and add it to GitHub Actions secrets with an app-specific password or App Store Connect API key for notarization.
- [ ] **Windows code-signing certificate** (OV/EV, or Azure Trusted Signing) → add to CI secrets. Until then SmartScreen warns users.
- [x] **Bundle ID:** `dev.thecodepapaya.antmanager` (DECISIONS #135).
- [ ] Host **appcast feeds** (GitHub Releases works; or under the `web/` site via Cloudflare). Confirm which domain.
- [ ] Generate a **Sparkle EdDSA key pair** for update signing and store the private key in CI secrets. (I'll give you the command.)
- [ ] **Protect release tags:** GitHub → Settings → Rules → add a tag ruleset for `v*` so only you can create them. Every `v*` tag publishes a public release ([RELEASE.md](./RELEASE.md)).
- [ ] **Cut the first release** when ready, from `main` after merging `v1.1`: bump `app/pubspec.yaml`, tag `vX.Y.Z`, push ([RELEASE.md](./RELEASE.md)).

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

- [x] **Issue forms live on `main`** (DECISIONS #127): live since v1 was merged to `main`.
- [ ] Check the `bug` and `enhancement` labels exist (GitHub defaults), so issue forms can apply them.

## Crash reporting
- [ ] **Firebase** (`ant-manager-papaya`, DECISIONS #138): decide what it's for (it's configured but unused), and restrict its API keys in Google Cloud → Credentials to the macOS bundle ID / Windows app.
- [ ] Create a **Sentry project** (free tier is fine) and give me the DSN. Reports stay opt-in in the app.

## Testing infrastructure
- [ ] **Click the menu-bar icon** (macOS) and check the menu opens and each item works (DECISIONS #140). Then, with the menu open, pause or switch profile from the main window (e.g. a global shortcut), close the menu, reopen it: items should respond and show the new state (#141); on Windows/Linux too when you smoke-test installers.
- [ ] **GitHub Enterprise Server** trial licence (or access to a real GHES instance) for self-hosted testing.
- [ ] Test accounts: Linear workspace, Jira Cloud site, an Outlook / M365 account (for its ICS link) and a Google account with sample calendar data.
- [ ] **Smoke-test the unsigned installers** from a CI build on a real Windows 10/11 PC and a Linux desktop (install, launch, tray icon). CI builds them but can't run them. On Linux also check a token saves (needs gnome-keyring or KWallet running) and the tray icon on GNOME (AppIndicator extension).
- [ ] (GitLab self-managed: I'll run GitLab CE in Docker. Nothing needed from you.)

## Content & legal
- [ ] Review the v1 **[PRIVACY.md](../PRIVACY.md) / [THREAT_MODEL.md](../THREAT_MODEL.md)** (rewritten 2026-11-20: "send everything" to the chosen provider, opt-in crash reports not wired yet, plaintext backups, known gaps). The `web/` site and `.github/ISSUE_TEMPLATE/config.yml` link both on `main` (DECISIONS #125, #127, #134).
- [ ] **web/ site redesigned** (DECISIONS #125, on `main`): review it, then deploy to Cloudflare Pages and add the custom domain `ant-manager.thecodepapaya.dev` (confirmed, DECISIONS #142; Pages → Custom domains, which adds the DNS record if `thecodepapaya.dev` is on Cloudflare). Download buttons point at the GitHub Releases page; once a release exists, optionally link the artifacts directly, and drop the "unsigned" note once signing is in place.
- [ ] Approve the **design direction** (palette from the logo, Linear-style) when I present it.
- [x] ~~Provide an **SVG version of the logo** (vector source for the app icon, installers, web site and in-app branding; the current logo is raster only).~~ Traced to SVG (DECISIONS #123).
- [x] ~~Share **ideas / sketches for the menu-bar logo** (silhouette, single ant vs. abstract mark, filled vs. outline) so I can draft options.~~ Done: single-ant `ant.svg` (#123).
- [ ] Approve the **menu-bar / tray icon** drafted in #123 (`app/assets/brand/ant.svg`): a simplified single-colour single-ant version of the logo (two ants don't read at 16–22 px; macOS wants a template image). The full logo is used everywhere else.
