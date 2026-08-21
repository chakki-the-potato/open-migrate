#!/usr/bin/env bash
# set -e is deliberately omitted — run every check to the end so a single pass diagnoses everything.
set -uo pipefail
TARGET="${1:?usage: verify-migration.sh <target-root> <target-tool> <source-tool> [scope]}"
TOOL="${2:?usage: verify-migration.sh <target-root> <target-tool> <source-tool> [scope]}"
SOURCE="${3:?usage: verify-migration.sh <target-root> <target-tool> <source-tool> [scope]}"
# scope defaults to "home" so every existing three-argument invocation keeps working.
SCOPE="${4:-home}"
fail=0

chk() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then echo "PASS: $d"; else echo "FAIL: $d"; fail=1; fi; }
chk_not() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then echo "FAIL: $d"; fail=1; else echo "PASS: $d"; fi; }

script_dir="$(cd "$(dirname "$0")" && pwd)"
if [ "$SCOPE" = "project" ]; then
  tool_checks="$script_dir/checks/target-$TOOL-project.sh"
else
  tool_checks="$script_dir/checks/target-$TOOL.sh"
fi
# The source-dependent report strings are the same in either scope, so this file is
# not scope-qualified.
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
if [ "$SCOPE" = "project" ]; then
  . "$script_dir/checks/project-common.sh"
fi
. "$tool_checks"
. "$source_checks"

exit $fail
