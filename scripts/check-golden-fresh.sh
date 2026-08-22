#!/usr/bin/env bash
# Fails when a knowledge doc moved ahead of the golden output it produced.
#
# The migration is performed by an agent reading core/, so CI cannot re-run it. Without
# this gate a wrong edit to core/tools/claude.md ships green: every automated check here
# tests the verifier, not the conversion. Pinning each golden to the hash of the docs it
# came from turns "the docs changed and nobody re-measured" into a build failure.
#
#   ./scripts/check-golden-fresh.sh
#
# When it fails, regenerate the named directions:
#   ./scripts/seed-target.sh <target-tool> /tmp/g
#   /open-migrate <source> <target>     # pointed at /tmp/g
#   ./scripts/freeze-golden.sh <source> <target-tool> /tmp/g
set -uo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_dir" || { echo "FAIL: cannot enter the repository at $repo_dir" >&2; exit 1; }

manifest="test/golden/manifest.json"
if [ ! -f "$manifest" ]; then
  echo "SKIP: no $manifest yet — nothing frozen"
  exit 0
fi

python3 - <<'PY'
import hashlib, json, pathlib, sys

manifest = json.loads(pathlib.Path("test/golden/manifest.json").read_text())
directions = manifest.get("directions", {})
if not directions:
    print("SKIP: manifest has no directions")
    sys.exit(0)

stale, missing = [], []
for name, entry in directions.items():
    if not pathlib.Path("test/golden", name).is_dir():
        missing.append(name)
        continue
    drifted = [
        doc for doc, pinned in entry["docs"].items()
        if not pathlib.Path(doc).exists()
        or hashlib.sha256(pathlib.Path(doc).read_bytes()).hexdigest() != pinned
    ]
    if drifted:
        stale.append((name, drifted))

# The reverse direction matters just as much and is easier to hit. Both CI jobs walk the
# manifest, so a golden tree with no entry is verified by nothing and pinned to nothing — it
# looks like coverage and is not. A half-applied commit produces exactly that: the tree lands,
# the manifest hunk does not.
orphans = sorted(
    p.name for p in pathlib.Path("test/golden").iterdir()
    if p.is_dir() and p.name not in directions
)

for name in missing:
    print(f"FAIL: {name} is in the manifest but test/golden/{name}/ does not exist", file=sys.stderr)
for name, drifted in stale:
    print(f"FAIL: {name} was produced by an older revision of: {', '.join(drifted)}", file=sys.stderr)
for name in orphans:
    print(
        f"FAIL: test/golden/{name}/ has no manifest entry — nothing verifies or pins it. "
        f"Re-freeze it, or delete it.",
        file=sys.stderr,
    )

if stale or missing or orphans:
    print(
        "\n      A golden is the only evidence that the current docs still convert correctly.\n"
        "      Re-run the affected directions and re-freeze them, or revert the doc change.",
        file=sys.stderr,
    )
    sys.exit(1)

print(f"OK: {len(directions)} golden direction(s) match the current knowledge docs")

# A green build here protects only the directions that are frozen. Saying so is the
# difference between "checked" and "checked what exists" — without this line a partially
# frozen manifest reads as full coverage, which is the failure this whole gate exists to
# prevent. Derived from core/tools/ so a fifth tool widens the gap rather than hiding in it.
tools = sorted(p.stem for p in pathlib.Path("core/tools").glob("*.md") if p.stem != "_template")
expected = {f"{s}-to-{t}" for s in tools for t in tools if s != t}
unfrozen = sorted(expected - set(directions))
if unfrozen:
    print(
        f"NOTE: {len(unfrozen)} of {len(expected)} home-scope direction(s) have no golden and "
        f"are NOT gated by this check:\n      " + ", ".join(unfrozen)
    )
PY
