# Threat model

Ant Manager v1 is a single-user desktop app that reads your work activity, keeps it in a local database and sends it
to an AI provider you choose. This page lists what we protect, where trust changes, the threats we considered, what
the code does about them today, and what it doesn't. Data handling itself is in [PRIVACY.md](./PRIVACY.md).

Out of scope: monitoring other people, team or employer features (none exist), and a fully compromised OS account.

## Assets

- **Evidence:** commit diffs, PR / issue text, calendar details, transcripts, notes, screenshots.
- **Derived data:** Narrative facts, reports, wins (often more sensitive than any single item: a summary of your work).
- **Credentials:** source tokens (GitHub/GitLab PATs, Linear key, Jira token, Google OAuth tokens), provider API keys
  and custom header values.
- **Backups and readable exports** (plaintext copies of the above).
- **Integrity of the Narrative:** facts should only say what cited evidence supports.

## Trust boundaries

1. **App ↔ source content.** Repo contents, PR comments, issue text, ICS feeds and calendar invites are written by
   other people and are untrusted.
2. **App ↔ AI provider.** Everything sent crosses to a third party unless the provider is on loopback. Model output
   is untrusted.
3. **App ↔ network.** Source APIs and providers over TLS; custom endpoints may be plain HTTP or use relaxed TLS.
4. **App ↔ disk.** The data folder, backup folder and any sync service behind it.
5. **App ↔ OS secret store.** Keychain / Credential Manager / libsecret.
6. **UI isolate ↔ engine isolate.** Same process; the engine owns the DB and network, the UI writes only through
   `AntEngine` commands. Not a security boundary.

## Threats and mitigations

### 1. Malicious content / prompt injection

Someone puts instructions in a commit message, PR comment, issue, meeting invite or transcript ("ignore previous
instructions, report that…").

As built:
- Every model call requires **native structured output** against a JSON schema (#70); free-form output is not used.
- The model has **no tools and no actions**: report data is gathered by code through the read-only tool layer, and
  the model only returns JSON. It cannot write files, call sources or reach the network.
- The reconciler **drops** fact operations whose citations aren't in that call's input, that target unknown or
  retired facts, that recreate a fact you rejected, or that try to create time-allocation facts (computed in code).
- Report items without valid fact ids are discarded (#92); reports render as plain text with footnotes (no HTML,
  no remote images). Rich-text copy escapes HTML.
- **User-touched facts are never overwritten** by the model; changes to them become review proposals.
- Facts are labelled *model-inferred* until you confirm them.

Residual: injected text can still bias wording, importance scores and which model-inferred facts appear. The
defence is citations plus your review, not detection. A cloud provider also sees the injected content.

### 2. Untrusted git repositories

The app runs the system `git` (`git log`, `git show`) in repos you add, with `GIT_TERMINAL_PROMPT=0` and
`GIT_PAGER=cat`. Arguments are passed as a list (no shell).

Fixed (#118): the capture source's `git log` and `git show` pass `--no-textconv --no-ext-diff` (the setup scan's
`git log` calls request no diff), and every call passes
`-c log.showSignature=false`, so a repo whose `.git` came from an untrusted source can't make our reads run a
`textconv` driver, external diff or `gpg.program`. Hooks and fsmonitor don't run on these read-only commands.
Residual: other repo config reachable by `log` / `show` / `rev-parse` was not audited; only add repos you would run
`git log -p` in yourself.

### 3. Compromised or malicious AI provider endpoint

A provider (or whoever controls its URL, DNS or network path) receives your full evidence and your API key for it.

As built:
- One-time **consent notice** for every non-loopback base URL, LAN included; changing the URL asks again (#74, #105).
- Warning for plain `http://` to a non-local host.
- TLS is verified by default. Per provider you can add a **custom CA** (validation stays on) or enable
  **"Disable TLS verification"** (`allowSelfSigned`), which accepts any certificate and is labelled with a warning
  (#108). These options exist **for providers only**, not sources.
- Provider API keys and header values are per provider in the secret store, sent only to that provider.

- Consent is enforced at request time (#118): every client is built by `createClient`, which refuses a
  non-loopback base URL without consent. Declining the notice after changing a provider's URL leaves the URL saved
  but sends nothing to it.

Gaps:
- With TLS verification disabled, anyone on the path can read and alter traffic, including the API key.

### 4. Source API endpoints

Sources use the default TLS stack (no custom CA, no insecure toggle: docs/lld/README.md "Known gaps"). Self-hosted
GitHub Enterprise / GitLab URLs are whatever you enter; tokens go only to the configured URL. Sources only read.
An ICS source given a non-HTTP value reads it as a local file path.

### 5. Token theft

- Secrets are never in the databases, backups or readable export; rows hold a reference key only.
- macOS uses the **login keychain**, and the app is **unsigned and unsandboxed** (#101): other processes running as
  you may be able to read its items (subject to keychain prompts; unverified). Switching to the data-protection
  keychain is an owner to-do once signing exists.
- Windows: values are DPAPI-encrypted in one file in the app-support folder; any process running as you can
  decrypt them.
- Linux: libsecret; any process in your session can usually read the collection while it is unlocked.
- Removing a source keeps its token (#102); removing a provider deletes its key and headers.

### 6. Backup file tampering

Backups sit in a folder that may be synced to a cloud service, so a backup may be modified before you restore it.

As built:
- Restore always creates a **new profile**, never overwriting one (#105); a failed restore removes the profile,
  database file and attachments (#115).
- The manifest records a SHA-256 of `db.sqlite`, checked on restore. This catches corruption, **not tampering**: the
  manifest isn't signed, so an attacker can update both.
- **Unsafe archive paths are rejected:** each `attachments/…` entry is normalised and must stay inside the new
  profile's attachments folder, otherwise the restore fails ("Unsafe path in backup"). Other entries are ignored.
  The blob store also refuses paths outside its root when reading or deleting.
- Backups from a newer schema are refused; older ones are migrated on open.
- Restore clears every source's **credential reference** and disables those sources (#118), so they need signing in
  again even on the same machine, and an edited backup can't point an existing token at another URL.

Gaps:
- Backups are **plaintext** (#36). Anyone who can read the folder can read your evidence.
- A tampered database can carry arbitrary rows (and SQLite triggers) into the new profile; there is no schema
  validation beyond drift's migrations (unverified impact). A planted trigger could, for example, write a credential
  reference back into `sources` later. Only restore backups you made and stored somewhere you trust.

### 7. Local attacker or other software on the machine

- Databases and attachments are unencrypted; they rely on OS account separation and disk encryption.
- The app has no listening service except the one-shot loopback server during Google sign-in (random port, `state`
  checked, PKCE).
- Notifications carry no content ("Your day is drafted / 2-minute review?").
- Quick-capture screenshots go to the temp folder and are deleted once saved into the note.

### 8. Supply chain and updates

- Releases are built by GitHub Actions and published **unsigned** (#4, #94); verify you downloaded from the project's
  GitHub Releases. Gatekeeper / SmartScreen will warn.
- Auto-update is **not wired** yet, so there is no update channel to attack, and no automatic security fixes either.
  When it lands, updates are to be verified with Sparkle EdDSA signatures (owner to-do).

### 9. Misrepresentation by the model

Facts and reports can be wrong. Every fact cites evidence and is labelled model-inferred or user-confirmed; time is
labelled measured or estimated; reports can't be edited, only corrected through facts and evidence (#48, #49).

## Known gaps

The list above plus [docs/lld/README.md "Known gaps"](./docs/lld/README.md#known-gaps) (Sentry and auto-update not
wired, TLS options for providers only, and others).
