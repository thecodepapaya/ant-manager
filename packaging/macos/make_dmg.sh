#!/usr/bin/env bash
# Packages a built macOS .app into an UNSIGNED (ad-hoc signed) .dmg.
#
# Usage: packaging/macos/make_dmg.sh <version> [app_path] [out_dir]
#   app_path defaults to the single .app in app/build/macos/Build/Products/Release
#   out_dir  defaults to dist/
# Output: <out_dir>/AntManager-<version>-macos.dmg
#
# Signing with a Developer ID + notarization comes later (docs/RELEASE.md).
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
version="${1:?usage: make_dmg.sh <version> [app_path] [out_dir]}"
app="${2:-}"
out_dir="${3:-$root/dist}"

if [[ -z "$app" ]]; then
  apps=("$root"/app/build/macos/Build/Products/Release/*.app)
  [[ ${#apps[@]} -eq 1 && -d "${apps[0]}" ]] || { echo "Expected exactly one .app in app/build/macos/Build/Products/Release" >&2; exit 1; }
  app="${apps[0]}"
fi
[[ -d "$app" ]] || { echo "Not found: $app" >&2; exit 1; }

# The release must be universal (SPEC §2).
exe="$app/Contents/MacOS/$(defaults read "$app/Contents/Info" CFBundleExecutable)"
archs="$(lipo -archs "$exe")"
echo "Architectures: $archs"
[[ "$archs" == *x86_64* && "$archs" == *arm64* ]] || { echo "Not a universal binary: $exe" >&2; exit 1; }

# Ad-hoc signature so the app runs on Apple Silicon. Gatekeeper still warns (unsigned).
codesign --force --deep -s - "$app"
codesign --verify --deep --strict "$app"

mkdir -p "$out_dir"
dmg="$out_dir/AntManager-$version-macos.dmg"
staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT

cp -R "$app" "$staging/"
ln -s /Applications "$staging/Applications"
rm -f "$dmg"
hdiutil create -volname "Ant Manager" -srcfolder "$staging" -fs HFS+ -format UDZO -ov "$dmg"
echo "Created $dmg"
