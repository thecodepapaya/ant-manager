## Installing (unsigned build)

These installers are **not code-signed yet**, so your OS will warn the first time you open them.

**macOS** (`AntManager-*-macos.dmg`, universal: Apple Silicon + Intel, macOS 12+)
1. Open the .dmg and drag **Ant Manager** to Applications.
2. The first time, **right-click the app → Open → Open**. (On macOS 15+, if there's no Open button: System Settings → Privacy & Security → **Open Anyway**.)
3. Or, from Terminal: `xattr -dr com.apple.quarantine "/Applications/ant_manager.app"` (use the app's name as it appears in Applications).

**Windows** (`AntManager-*-windows-setup.exe`, x64, Windows 10+)
- If SmartScreen shows "Windows protected your PC", click **More info → Run anyway**. The installer is per-user and needs no admin rights.

**Linux** (`AntManager-*-x86_64.AppImage`, Ubuntu 22.04 or newer class)
- `chmod +x AntManager-*-x86_64.AppImage && ./AntManager-*-x86_64.AppImage`
- Needs FUSE 2 (`sudo apt install libfuse2` on Ubuntu 22.04, `libfuse2t64` on 24.04+), or run with `--appimage-extract-and-run`.
- The tray icon needs an AppIndicator-capable desktop (GNOME needs the AppIndicator extension).
