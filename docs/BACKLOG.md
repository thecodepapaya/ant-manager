# Backlog (next cycle, `v1.1`)

Owner notes from local runs. Each fix still follows the working rules (DECISIONS + SPEC + LLD, independent tests #99).

## UI
- [x] **Simpler first onboarding page.** The Welcome step feels busy; cut it down to the essentials.
- [x] **Search in Identities** (optional filter field). Repos with many contributors make the list hard to scan.
- [x] **Search in Repositories**, same as Identities.
- [x] **Remove / change the AI key after adding it.** Once an OpenRouter key is saved in the onboarding AI-model step there's no way to undo or remove it.

## Menu bar / tray
- [x] **Menu-bar icon does nothing when clicked** (macOS local run): fixed in #140 (the icon had no listener, so nativeapi never wired clicks). **Owner to confirm** the menu opens with Open, Quick note, Sync now, Pause, Settings and Quit; a smoke test can't click the menu bar.

## Waiting on the owner
- [ ] **Firebase:** configured but not initialized (DECISIONS #138). Decide what it's for; then wire it (skip Linux). See OWNER_TODO.

## Known trade-offs (accepted, revisit if they bite)
- Removing a provider when the keychain delete fails removes the provider but leaves its old key in the keychain (#139).
- Search fields appear only above 8 entries; plain substring match, no fuzzy search (#136).
- The tray defers rebuilds while its menu is open (#141). If macOS ever skips a menu-closed event, the menu stops refreshing until relaunch; no timeout guard.
