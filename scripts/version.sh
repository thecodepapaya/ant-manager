#!/usr/bin/env bash
# Prints the release version.
#   - Tag builds (GITHUB_REF_TYPE=tag): the tag without its leading "v". It must match app/pubspec.yaml,
#     because the app reports its pubspec version to the updater.
#   - Everything else: app/pubspec.yaml version without the "+build" suffix, plus "-<short sha>" in CI.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
pub="$(sed -n 's/^version:[[:space:]]*\([^+[:space:]]*\).*/\1/p' "$root/app/pubspec.yaml")"
[[ -n "$pub" ]] || { echo "No version in app/pubspec.yaml" >&2; exit 1; }

if [[ "${GITHUB_REF_TYPE:-}" == "tag" ]]; then
  tag="${GITHUB_REF_NAME#v}"
  if [[ "$tag" != "$pub" ]]; then
    echo "Tag v$tag does not match app/pubspec.yaml version $pub" >&2
    exit 1
  fi
  echo "$tag"
elif [[ -n "${GITHUB_SHA:-}" ]]; then
  echo "$pub-${GITHUB_SHA:0:7}"
else
  echo "$pub"
fi
