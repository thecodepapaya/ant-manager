# Backlog (next cycle, `v1.1`)

Owner notes from local runs. Each fix still follows the working rules (DECISIONS + SPEC + LLD, independent tests #99).

## UI
- [x] **Simpler first onboarding page.** The Welcome step feels busy; cut it down to the essentials.
- [x] **Search in Identities** (optional filter field). Repos with many contributors make the list hard to scan.
- [x] **Search in Repositories**, same as Identities.
- [x] **Remove / change the AI key after adding it.** Once an OpenRouter key is saved in the onboarding AI-model step there's no way to undo or remove it.

## Menu bar / tray
- [ ] **Menu-bar icon does nothing when clicked** (macOS local run): no menu, so no Quit, Sync now or Open. Fix the click handler / context menu and cover it in the smoke test.
