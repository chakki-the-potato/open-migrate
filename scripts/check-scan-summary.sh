#!/usr/bin/env bash
# Checks that every frozen report's scan summary adds up.
#
# procedure.md Step 5 requires each row to satisfy
#
#   Found = Automatic + Approximate + Suggestion + Skipped + Excluded + Impossible
#
# and that all nine checklist categories are present. Nothing verified either. A report is
# the only place a run says how much it found versus how much it moved, so a table that
# does not balance is a run whose accounting is wrong — or, more likely, a table edited by
# hand without re-deriving it.
#
#   ./scripts/check-scan-summary.sh
set -uo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_dir" || { echo "FAIL: cannot enter $repo_dir" >&2; exit 1; }

python3 - <<'PY'
import pathlib
import re
import sys

EXPECTED_COLUMNS = ["Found", "Automatic", "Approximate", "Suggestion",
                    "Skipped", "Excluded", "Impossible"]
CATEGORIES = 9

problems = []
checked = 0

for report in sorted(pathlib.Path("test/golden").rglob(".migrate/*/migration-report.md")):
    name = report.parts[2]
    lines = report.read_text().split("\n")

    header_at = None
    for i, line in enumerate(lines):
        if line.strip().startswith("| Category |"):
            header_at = i
            break
    if header_at is None:
        problems.append(f"{name}: no scan summary table")
        continue

    header = [c.strip() for c in lines[header_at].strip().strip("|").split("|")]
    if header[1:] != EXPECTED_COLUMNS:
        problems.append(f"{name}: columns are {header[1:]}, expected {EXPECTED_COLUMNS}")
        continue

    rows = 0
    for line in lines[header_at + 2:]:
        if not line.strip().startswith("|"):
            break
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) != len(EXPECTED_COLUMNS) + 1:
            problems.append(f"{name}: row '{cells[0]}' has {len(cells)} cells")
            continue
        label, nums = cells[0], cells[1:]
        if not all(re.fullmatch(r"\d+", n) for n in nums):
            problems.append(f"{name}: row '{label}' has a non-numeric cell: {nums}")
            continue
        found, *parts = (int(n) for n in nums)
        if found != sum(parts):
            problems.append(
                f"{name}: row '{label}' does not balance — "
                f"Found {found} but the parts sum to {sum(parts)} ({'+'.join(str(p) for p in parts)})")
        rows += 1

    if rows != CATEGORIES:
        problems.append(f"{name}: {rows} category rows, expected {CATEGORIES}")
    checked += 1

for p in problems:
    print(f"FAIL: {p}")

if problems:
    sys.exit(1)
print(f"OK: {checked} scan summaries balance, {CATEGORIES} categories each")
PY
