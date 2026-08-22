#!/usr/bin/env bash
# Fails when the distributed content changed but the plugin version did not.
#
# Plugin managers compare version numbers, not content. A change shipped without a
# bump keeps serving the old cache: `claude plugin update` reports "already at the
# latest version" and installs nothing. This has silently invalidated end-to-end
# runs twice — an agent read a stale copy and reported gaps that were already fixed.
#
#   ./scripts/check-version-bump.sh [base-ref]    default base: origin/main
set -uo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_dir" || { echo "FAIL: cannot enter the repository at $repo_dir" >&2; exit 1; }
base="${1:-origin/main}"

if ! git rev-parse --verify --quiet "$base" >/dev/null; then
  echo "SKIP: base ref '$base' not found — nothing to compare against"
  exit 0
fi

now=$(git show HEAD:.claude-plugin/plugin.json 2>/dev/null | sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
was=$(git show "$base:.claude-plugin/plugin.json" 2>/dev/null | sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

if [ -z "$now" ] || [ -z "$was" ]; then
  echo "FAIL: could not read the version from plugin.json on one side" >&2
  exit 1
fi

# The plugin manifest and the npm manifest are two release surfaces for the same content.
# If they disagree, one of them ships stale files under a version number that claims
# otherwise — the exact failure this script exists to prevent. A mismatch is wrong no
# matter what else the commit touched, so it is checked before the shipped-content test
# below can exit early: a commit that moves only .claude-plugin/plugin.json changes
# nothing in the shipped set and used to leave the two manifests disagreeing on main.
# Both sides are read from HEAD. Reading one from the working tree compares a staged-but-
# uncommitted edit against a committed one and reports on a state no commit ever had.
pkg=$(git show HEAD:package.json 2>/dev/null | sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
if [ -z "$pkg" ]; then
  echo "FAIL: could not read the version from package.json at HEAD" >&2
  exit 1
fi
if [ "$pkg" != "$now" ]; then
  echo "FAIL: package.json is $pkg but .claude-plugin/plugin.json is $now — they must match" >&2
  exit 1
fi
echo "OK: package.json matches at $pkg"

# Everything the plugin actually ships. Changes anywhere else (tests, docs/, the
# README) do not reach an installed copy and so do not require a bump.
shipped=$(git diff --name-only "$base"...HEAD -- core adapters/open-migrate skills bin package.json | wc -l | tr -d ' ')
if [ "$shipped" -eq 0 ]; then
  echo "OK: no shipped content changed since $base"
  exit 0
fi

if [ "$now" = "$was" ]; then
  echo "FAIL: $shipped shipped file(s) changed but version is still $now" >&2
  echo "      Bump .claude-plugin/plugin.json, or installed copies keep serving the old content." >&2
  git diff --name-only "$base"...HEAD -- core adapters/open-migrate skills bin package.json | sed 's/^/      /' >&2
  exit 1
fi

echo "OK: shipped content changed and version moved $was -> $now"
