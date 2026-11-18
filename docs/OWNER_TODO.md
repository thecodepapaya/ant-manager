# Owner To-Do (things only you can do)

External accounts, registrations and decisions needed for the v1 rewrite ([SPEC.md](./SPEC.md)).
None of these block development; placeholders are used until each is done. Tick items off as you complete them.

## Signing & distribution
- [ ] **Apple Developer Program** ($99/yr) → create a *Developer ID Application* certificate. Export it as a `.p12` and add it to GitHub Actions secrets with an app-specific password or App Store Connect API key for notarization.
- [ ] **Windows code-signing certificate** (OV/EV, or Azure Trusted Signing) → add to CI secrets. Until then SmartScreen warns users.
- [ ] Decide the **bundle ID** (e.g. `com.<you>.antmanager`). It's used by signing, OAuth redirects and keychain entries, so it's hard to change later.
- [ ] Host **appcast feeds** (GitHub Releases works; or under the `web/` site via Cloudflare). Confirm which domain.
- [ ] Generate a **Sparkle EdDSA key pair** for update signing and store the private key in CI secrets. (I'll give you the command.)

## Google Calendar
- [ ] Create a **Google Cloud project**, enable the Calendar API.
- [ ] Configure the **OAuth consent screen** (external, scope `calendar.readonly`) and create a *Desktop app* OAuth client. Give me the client ID (and the non-confidential desktop secret).
- [ ] Publish a **privacy policy URL** and **home page** (the `web/` site can host both).
- [ ] Submit for **sensitive-scope verification**: demo video plus written justification. Takes weeks. Until approved: an "unverified app" warning and a 100-user cap.

~~Microsoft / Outlook (Azure app registration)~~: **removed.** Outlook is supported via ICS links only (DECISIONS #82).
~~Backup destinations (Drive scope, Azure permission, Dropbox app)~~: **removed.** Backups go to a local folder only (#80).

## Crash reporting
- [ ] Create a **Sentry project** (free tier is fine) and give me the DSN. Reports stay opt-in in the app.

## Testing infrastructure
- [ ] **GitHub Enterprise Server** trial licence (or access to a real GHES instance) for self-hosted testing.
- [ ] Test accounts: Linear workspace, Jira Cloud site, an Outlook / M365 account (for its ICS link) and a Google account with sample calendar data.
- [ ] (GitLab self-managed: I'll run GitLab CE in Docker. Nothing needed from you.)

## Content & legal
- [ ] Review the updated **PRIVACY.md / THREAT_MODEL.md** (the cloud-provider "send everything" policy + opt-in crash reports change the promises).
- [ ] Update the **web/ landing page** with new download links once release artifacts exist.
- [ ] Approve the **design direction** (palette from the logo, Linear-style) when I present it.
- [ ] Approve a **menu-bar / tray icon**: a simplified single-colour single-ant version of the logo (two ants don't read at 16–22 px; macOS wants a template image). The full logo is used everywhere else.
