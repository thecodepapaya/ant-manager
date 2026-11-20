#!/usr/bin/env bash
# Builds the UNSIGNED macOS .dmg on a local Mac: dist/AntManager-<version>-macos.dmg
# Same steps as the macOS job in .github/workflows/build.yml.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
[[ "$(uname)" == "Darwin" ]] || { echo "build_local.sh builds the macOS dmg and must run on macOS" >&2; exit 1; }

version="$("$root/scripts/version.sh")"
echo "Building Ant Manager $version (macOS, unsigned)"

cd "$root"
flutter pub get
cd "$root/app"
flutter build macos --release
"$root/packaging/macos/make_dmg.sh" "$version"
