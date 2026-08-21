#!/usr/bin/env bash
# set -e is deliberately omitted — run every check to the end so a single pass diagnoses everything.
set -uo pipefail
TARGET="${1:?usage: verify-migration.sh <target-root> <target-tool> <source-tool>}"
TOOL="${2:?usage: verify-migration.sh <target-root> <target-tool> <source-tool>}"
SOURCE="${3:?usage: verify-migration.sh <target-root> <target-tool> <source-tool>}"
fail=0

chk() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then echo "PASS: $d"; else echo "FAIL: $d"; fail=1; fi; }
chk_not() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then echo "FAIL: $d"; fail=1; else echo "PASS: $d"; fi; }

script_dir="$(cd "$(dirname "$0")" && pwd)"
tool_checks="$script_dir/checks/target-$TOOL.sh"
source_checks="$script_dir/checks/source-$SOURCE.sh"
if [ ! -f "$tool_checks" ]; then
  echo "ERROR: no checks for target tool '$TOOL' ($tool_checks)"
  exit 1
fi
if [ ! -f "$source_checks" ]; then
  echo "ERROR: no checks for source tool '$SOURCE' ($source_checks)"
  exit 1
fi

if [ ! -d "$TARGET" ]; then
  echo "ERROR: target root not found: $TARGET"
  exit 1
fi

. "$script_dir/checks/_common.sh"
. "$tool_checks"
. "$source_checks"

exit $fail
