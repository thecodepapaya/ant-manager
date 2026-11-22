# Releasing Ant Manager

Releases are **public** GitHub Releases with **unsigned** installers (DECISIONS #4, #94). Signing and auto-update
come later (checklist at the bottom).

## Cut a release

1. On `main` (after `v1.1` is merged), set `version:` in `app/pubspec.yaml` to `X.Y.Z+N` (bump the `+N` build number every release).
2. Commit and wait for CI to pass.
3. Tag and push:
   ```sh
   git tag vX.Y.Z && git push origin vX.Y.Z
   ```
   The tag (without `v`) must equal the pubspec version (without `+N`), or the build fails. A tag with a `-`
   (e.g. `v1.0.0-beta.1`) is published as a pre-release.
4. The **Build** workflow builds all three platforms and publishes the release. Edit the generated notes on GitHub
   if needed.

## What CI does

| Workflow | Trigger | Does |
|---|---|---|
| `ci.yml` | every push, every PR | `flutter pub get`; build_runner in `packages/core` and fail if generated code isn't committed; `dart analyze` + `dart test --exclude-tags live` in core; `flutter analyze` + `flutter test` in `ui` and `app`; `dart run packages/ui/tool/check_tokens.dart`. All steps run even if one fails. A second job on `macos-latest` seeds a demo data folder (`seed_demo.dart`) and runs `app/integration_test/smoke_test.dart` against it (#117). |
| `build.yml` | tags `v*`, manual (not on commits, #133) | Builds release installers on macOS / Windows / Ubuntu 22.04 and uploads them as workflow artifacts. On `v*` tags, also creates the GitHub Release with the three files and the install notes from `packaging/release-notes.md`. |

Artifacts (manual branch builds get version `X.Y.Z-<sha7>`):

| Platform | File | Made by |
|---|---|---|
| macOS | `AntManager-<version>-macos.dmg` (universal, ad-hoc signed) | `packaging/macos/make_dmg.sh` |
| Windows | `AntManager-<version>-windows-setup.exe` (x64, per-user install) | `packaging/windows/installer.iss` (Inno Setup) |
| Linux | `AntManager-<version>-x86_64.AppImage` | `packaging/linux/make_appimage.sh` (appimagetool 1.9.1, checksum-pinned) |

The Linux AppImage bundles libnotify (notifications); GTK, glib, X11 and libsecret (SPEC #77) come from the host. Tray (D-Bus StatusNotifierItem) and hotkeys (X11) are in nativeapi's own `.so`, built by its native-asset
hook (needs `libgtk-3-dev libx11-dev libxi-dev`), so no ayatana/keybinder. `make_appimage.sh` fails if any bundled
`.so` has an unresolved dependency. Users need a secret service (gnome-keyring / KWallet) and, on GNOME, the
AppIndicator extension for the tray. The Windows installer ships the MSVC runtime DLLs.

CI runs every check step even after an earlier one fails (`if: ${{ !cancelled() }}`), so one red test suite
doesn't hide the others. Branch builds: `gh workflow run build.yml --ref <branch>`.

## Build locally (macOS)

```sh
scripts/build_local.sh   # → dist/AntManager-<version>-macos.dmg
```

## Unsigned caveats

- **macOS:** Gatekeeper blocks the first launch. Right-click → Open (macOS 15+: System Settings → Privacy &
  Security → Open Anyway), or `xattr -dr com.apple.quarantine /Applications/<app>.app`.
- **Windows:** SmartScreen: More info → Run anyway.
- **Linux:** no signing involved; users need FUSE 2 or `--appimage-extract-and-run`.
- No auto-update yet: users download new versions from the Releases page.

These notes are attached to every release (`packaging/release-notes.md`).

## Later: signing & updates

Owner prerequisites are tracked in [OWNER_TODO.md](./OWNER_TODO.md) under *Signing & distribution*.

- [ ] **macOS Developer ID:** import the `.p12` into a temporary keychain in CI (secrets `MACOS_CERT_P12`,
      `MACOS_CERT_PASSWORD`); in `make_dmg.sh` replace the ad-hoc `codesign -s -` with
      `codesign --force --options runtime --timestamp --entitlements app/macos/Runner/Release.entitlements -s "Developer ID Application: …"`
      (sign nested frameworks first, not `--deep`), then sign the .dmg.
- [ ] **Notarization:** `xcrun notarytool submit AntManager-….dmg --wait` with an App Store Connect API key
      (secrets `APPSTORE_KEY_ID`, `APPSTORE_ISSUER_ID`, `APPSTORE_KEY_P8`), then `xcrun stapler staple` the .dmg.
- [ ] **Windows Authenticode:** sign `ant_manager.exe` before packaging and the setup .exe after (`signtool sign
      /fd sha256 /tr <timestamp-url> /td sha256 …`, or Azure Trusted Signing action). Inno Setup's `SignTool=`
      directive can sign the installer + uninstaller.
- [ ] **Sparkle / WinSparkle appcast (DECISIONS #6):** generate the EdDSA key pair (Sparkle `generate_keys`), keep
      the private key in `SPARKLE_ED_PRIVATE_KEY`, put the public key in the macOS `Info.plist` (`SUPublicEDKey`) and
      the Windows resources; implement the commented `appcast` job in `build.yml` (`sign_update` each installer,
      write `appcast-macos.xml` / `appcast-windows.xml`, publish to the chosen feed URL, set `SUFeedURL`).
      Sparkle updates should ship only after Developer ID signing, so the signing identity stays stable.
- [ ] **Linux AppImage update info:** pass `-u "gh-releases-zsync|thecodepapaya|ant-manager|latest|AntManager-*-x86_64.AppImage.zsync"`
      to appimagetool (TODO in `make_appimage.sh`), attach the generated `.zsync` to the release; the app's
      "update available" notice can read the GitHub Releases API.
- [ ] Remove the unsigned workaround text from `packaging/release-notes.md`.
