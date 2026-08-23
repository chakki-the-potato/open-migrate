#!/usr/bin/env bash
# Checks that a run stopped at Confirm left the target untouched.
#
# "Write nothing before approval" is the claim every other safety guarantee rests on, and
# until this script existed nothing verified it. The other checks all inspect a target
# *after* a migration; this one inspects a target that was deliberately not migrated.
#
#   ./scripts/verify-declined.sh <target root> <tool>
#
# The target must be byte-identical to a freshly seeded one, and — unlike the rollback
# check — `.migrate/` must not exist at all. procedure.md creates the run directory in
# Step 4, so a run that stopped at Step 3 has no artifacts to keep: no backup, no report,
# no ledger. A run directory here means writing began before approval.
set -uo pipefail

TARGET="${1:?usage: verify-declined.sh <target root> <tool>}"
TOOL="${2:?usage: verify-declined.sh <target root> <tool>}"
fail=0

chk()     { local d="$1"; shift; if "$@" >/dev/null 2>&1; then echo "PASS: $d"; else echo "FAIL: $d"; fail=1; fi; }
chk_not() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then echo "FAIL: $d"; fail=1; else echo "PASS: $d"; fi; }

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

# ── Nothing was written ────────────────────────────────────────────────
# No --exclude here. The rollback check excludes .migrate/ because a rollback keeps the
# run record on purpose; a declined run has no record to keep.
diff_out="$(diff -r "$reference/seed" "$TARGET" 2>&1)"
if [ -z "$diff_out" ]; then
  echo "PASS: target is byte-identical to a fresh seed"
else
  echo "FAIL: target differs from a fresh seed — something was written before approval"
  printf '%s\n' "$diff_out" | sed 's/^/    /'
  fail=1
fi

# ── No run artifacts at all ────────────────────────────────────────────
chk_not "no run directory"  test -d "$TARGET/.migrate"
chk_not "no ledger"         test -f "$TARGET/.migrate/ledger.json"

# ── The seed itself is still intact ────────────────────────────────────
# A target wiped clean would pass the two checks above for the wrong reason. Seeded
# content must still be there: declining must change nothing in either direction.
seeded=$(find "$reference/seed" -type f | wc -l | tr -d ' ')
present=$(find "$TARGET" -type f 2>/dev/null | wc -l | tr -d ' ')
if [ "$seeded" -eq "$present" ]; then
  echo "PASS: seeded content still present ($present files)"
else
  echo "FAIL: seed had $seeded files, target has $present"
  fail=1
fi

exit $fail
