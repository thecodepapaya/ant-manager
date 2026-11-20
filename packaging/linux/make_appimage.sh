#!/usr/bin/env bash
# Packages the Flutter Linux bundle into an AppImage (x86_64, unsigned).
#
# Usage: packaging/linux/make_appimage.sh <version> [bundle_dir] [out_dir]
#   bundle_dir defaults to app/build/linux/x64/release/bundle
#   out_dir    defaults to dist/
# Output: <out_dir>/AntManager-<version>-x86_64.AppImage
#
# Run on Ubuntu 22.04 (the oldest glibc we support) with the plugin -dev packages installed.
set -euo pipefail

APPIMAGETOOL_VERSION=1.9.1
APPIMAGETOOL_SHA256=ed4ce84f0d9caff66f50bcca6ff6f35aae54ce8135408b3fa33abfc3cb384eb0

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
version="${1:?usage: make_appimage.sh <version> [bundle_dir] [out_dir]}"
bundle="${2:-$root/app/build/linux/x64/release/bundle}"
out_dir="${3:-$root/dist}"
[[ -x "$bundle/ant_manager" ]] || { echo "No Flutter bundle at $bundle" >&2; exit 1; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
appdir="$work/AppDir"

# 1. AppDir: templates + Flutter bundle + icon.
cp -R "$here/AppDir" "$appdir"
chmod +x "$appdir/AppRun"
cp -R "$bundle" "$appdir/app"
cp "$root/app/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png" "$appdir/ant-manager.png"

# 2. Bundle libnotify (notifications), which minimal distros may lack. libsecret stays a host
#    requirement (SPEC #77). Tray (D-Bus StatusNotifierItem) and hotkeys (X11) are in nativeapi's own .so,
#    which Flutter already puts in app/lib. GTK, glib and X11 come from the host system.
{ ldd "$appdir/app/ant_manager" "$appdir"/app/lib/*.so || true; } \
  | awk '/=> \// {print $3}' \
  | { grep -E '/libnotify\.so' || true; } \
  | sort -u \
  | while read -r lib; do
      echo "Bundling $lib"
      cp -L "$lib" "$appdir/app/lib/"
    done

# Fail on unresolved libraries (e.g. a plugin needing a -dev package the workflow didn't install).
missing="$(for f in "$appdir/app/ant_manager" "$appdir"/app/lib/*.so; do
  LD_LIBRARY_PATH="$appdir/app/lib" ldd "$f" | sed "s|^|$(basename "$f"): |"
done | grep 'not found' || true)"
[[ -z "$missing" ]] || { echo "Unresolved libraries:" >&2; echo "$missing" >&2; exit 1; }
echo "Bundled libraries:"; ls "$appdir/app/lib"

# 3. Build the AppImage with a pinned, checksum-verified appimagetool.
tool="$work/appimagetool"
curl -fsSL -o "$tool" \
  "https://github.com/AppImage/appimagetool/releases/download/$APPIMAGETOOL_VERSION/appimagetool-x86_64.AppImage"
echo "$APPIMAGETOOL_SHA256  $tool" | sha256sum -c -
chmod +x "$tool"

mkdir -p "$out_dir"
out="$out_dir/AntManager-$version-x86_64.AppImage"
# TODO(updates): pass `-u "gh-releases-zsync|thecodepapaya|ant-manager|latest|AntManager-*-x86_64.AppImage.zsync"`
# once Linux update info is wired up (docs/RELEASE.md, "Later").
ARCH=x86_64 APPIMAGE_EXTRACT_AND_RUN=1 "$tool" "$appdir" "$out"
echo "Created $out"
