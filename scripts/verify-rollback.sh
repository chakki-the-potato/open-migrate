#!/usr/bin/env bash
# Checks that a rollback actually undid a migration.
#
# The test is exact rather than approximate: a target that has been migrated and then rolled
# back must be byte-identical to a freshly seeded target of the same tool. Anything left over
# — a copied skill, a merged settings key, an empty directory — shows up as a difference.
# `.migrate/` is excluded because rollback deliberately keeps the run record.
#
#   ./scripts/verify-rollback.sh <target root> <tool> [run-id]
#
# With a run-id, the run's changes.json is validated too: the manifest must exist, parse, and
# agree with what is in backup/. Without one, only the seed comparison runs.
set -uo pipefail

TARGET="${1:?usage: verify-rollback.sh <target root> <tool> [run-id]}"
TOOL="${2:?usage: verify-rollback.sh <target root> <tool> [run-id]}"
RUN="${3:-}"
fail=0

chk() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then echo "PASS: $d"; else echo "FAIL: $d"; fail=1; fi; }

script_dir="$(cd "$(dirname "$0")" && pwd)"

if [ ! -d "$TARGET" ]; then
  echo "ERROR: target root not found: $TARGET"
  exit 1
fi

reference="$(mktemp -d)"
trap 'rm -rf "$reference"' EXIT

if ! "$script_dir/seed-target.sh" "$TOOL" "$reference/seed" --force >/dev/null 2>&1; then
  echo "ERROR: could not seed a reference for tool '$TOOL'"
  exit 1
fi

# ── The target must match a fresh seed exactly ──────────────────────────
diff_out="$(diff -r --exclude=.migrate "$reference/seed" "$TARGET" 2>&1)"
if [ -z "$diff_out" ]; then
  echo "PASS: target is byte-identical to a fresh seed"
else
  echo "FAIL: target differs from a fresh seed — rollback did not fully undo the run"
  printf '%s\n' "$diff_out" | sed 's/^/    /'
  fail=1
fi

# ── The run record survived ─────────────────────────────────────────────
chk "run records kept (.migrate/ still present)" test -d "$TARGET/.migrate"

# ── Manifest checks, when a run-id was given ────────────────────────────
if [ -n "$RUN" ]; then
  run_dir="$TARGET/.migrate/$RUN"
  changes="$run_dir/changes.json"

  chk "run directory exists"          test -d "$run_dir"
  chk "changes.json exists"           test -f "$changes"
  chk "changes.json is valid JSON"    jq -e . "$changes"
  chk "changes.json names the run"    jq -e --arg r "$RUN" '.run == $r' "$changes"
  chk "changes.json has modified[]"   jq -e 'has("modified") and (.modified | type == "array")' "$changes"
  chk "changes.json has created[]"    jq -e 'has("created")  and (.created  | type == "array")' "$changes"
  chk "paths are relative to the root" \
    jq -e '[.modified[]?, .created[]?, .created_dirs[]?] | all(startswith("/") | not)' "$changes"
  chk "no path is both modified and created" \
    jq -e '[.modified[]?] - ([.modified[]?] - [.created[]?]) | length == 0' "$changes"

  # Every modified file must have a backup, or rollback cannot restore it.
  if [ -f "$changes" ]; then
    missing=0
    while IFS= read -r rel; do
      [ -n "$rel" ] || continue
      if [ ! -f "$run_dir/backup/$(basename "$rel")" ]; then
        echo "FAIL: no backup for modified file: $rel"
        missing=1
      fi
    done < <(jq -r '.modified[]?' "$changes" 2>/dev/null)
    if [ "$missing" -eq 0 ]; then
      echo "PASS: every modified file has a backup"
    else
      fail=1
    fi
  fi

  chk "after-digests cover every written path" \
    jq -e '([.modified[]?, .created[]?] | sort) == (.after // {} | keys | sort)' "$changes"

  chk "rollback report written" test -f "$run_dir/rollback-report.md"
fi

exit $fail
