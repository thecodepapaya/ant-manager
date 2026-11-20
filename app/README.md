# app — Ant Manager Flutter shell

Composition root, platform adapters and desktop shell. Design: `docs/lld/03-class-design.md` §3.1, §3.3.

- `lib/engine/`: engine isolate (#68). `EngineHandle.start` spawns `engineMain`, which opens
  `ant_manager/app.sqlite` + `ant_manager/profiles/<id>.sqlite` (active profile only, #77), builds `AntEngine`
  and runs the IO / LLM job lanes, the recompute drain and the scheduler tick. The UI connects to both DBs through
  drift's `serializableConnection()` for `watch()` reads, and writes only via `EngineHandle.run` / `runtime`
  (closures copied to the engine isolate; build them in `commands.dart`). Plugin-backed ports (keychain,
  notifications, EventKit) are proxied back to the UI isolate (`port_bridge.dart` ⇄ `ui_port_host.dart`).
- `lib/platform/`: port adapters (secure storage, blob store, file watcher, notifier, EventKit bridge, screen
  capture, launch at login, system time zone, rotating log files).
- `lib/shell/`: tray menu, global hotkey (⌥⌘N / Ctrl+Alt+N), close-to-tray, quick capture.
- `lib/features/`: screens per sidebar section; `lib/state/` Riverpod providers; `lib/widgets/` shared widgets.
- `macos/Runner/MainFlutterWindow.swift`: EventKit channels `ant/calendar` + `ant/calendar/changes`, and the
  `launch_at_startup` channel via `SMAppService` (macOS 13+).
- Dev: `flutter run --dart-define=ANT_DATA_DIR=<dir>` uses a separate data folder; `packages/core/tool/seed_demo.dart`
  fills it with demo data (#107).
