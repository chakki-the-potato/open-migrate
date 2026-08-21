#!/usr/bin/env bash
# Builds the repository layout (adapters/ + core/) into the plugin layout (skills/open-migrate/).
#
# The plugin loader looks for skills under skills/ at the repository root, so the
# distribution has to be committed. The sources of truth are adapters/open-migrate/SKILL.md
# and core/; skills/ is generated from them — never edit skills/ directly.
#
#   ./scripts/build-plugin.sh          regenerate the distribution
#   ./scripts/build-plugin.sh --check  exit 1 if it drifted from the sources (pre-commit check)
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
out="$repo_dir/skills/open-migrate"

build_into() {
  local dest="$1"
  rm -rf "$dest"
  mkdir -p "$dest"
  cp "$repo_dir/adapters/open-migrate/SKILL.md" "$dest/SKILL.md"
  cp -R "$repo_dir/core" "$dest/core"
  # The template is a development doc for adding new tools — keep it out of the distribution.
  rm -f "$dest/core/tools/_template.md"
}

if [ "${1:-}" = "--check" ]; then
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  build_into "$tmp/open-migrate"
  if [ ! -d "$out" ]; then
    echo "FAIL: skills/open-migrate/ is missing — run ./scripts/build-plugin.sh" >&2
    exit 1
  fi
  if diff -r "$tmp/open-migrate" "$out" >/dev/null 2>&1; then
    echo "OK: distribution matches the sources"
  else
    echo "FAIL: distribution drifted from the sources — run ./scripts/build-plugin.sh" >&2
    diff -r "$tmp/open-migrate" "$out" >&2 || true
    exit 1
  fi
else
  build_into "$out"
  echo "built: $out"
fi
