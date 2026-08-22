#!/usr/bin/env bash
# Creates a worktree that cannot read test/golden/, for regenerating a golden.
#
# A regeneration driven from inside a normal checkout can read the golden it is about to
# replace, and a run that finds the expected output will match it. That golden then passes
# every check for the wrong reason — check-golden-fresh.sh compares hashes of the docs and
# verify-migration.sh compares the tree against rules, and neither can tell a conversion
# that followed core/ from one that copied the answer.
#
# This makes the answer absent rather than forbidden. The worktree holds core/, scripts/,
# and test/fixtures/; test/golden/ is not written to disk at all.
#
#   ./scripts/blind-worktree.sh <path>
#
# It is not containment. An agent that leaves the worktree can still read the golden
# through the main checkout, and nothing here detects that. What it removes is the case
# where the answer is simply lying in the working directory of the run.
set -euo pipefail

usage() { echo "usage: blind-worktree.sh <path>" >&2; exit 2; }

dest="${1:-}"
[ -n "$dest" ] || usage
[ -e "$dest" ] && { echo "FAIL: $dest already exists — remove it or pick another path" >&2; exit 1; }

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_dir" || { echo "FAIL: cannot enter the repository at $repo_dir" >&2; exit 1; }

# The worktree is checked out at HEAD, while freeze-golden.sh hashes the knowledge docs from
# THIS tree. If the two disagree, the run reads one revision of core/ and the manifest pins
# another — the mislabelled golden the gate cannot detect, arriving by a different route.
# Committing first is what keeps the two the same.
if ! git diff --quiet HEAD -- core || ! git diff --cached --quiet HEAD -- core; then
  echo "FAIL: core/ differs between HEAD and the working tree." >&2
  echo "      The worktree would run against the committed docs while freeze-golden.sh pins" >&2
  echo "      the ones you have edited, so the golden would be labelled with hashes it did" >&2
  echo "      not come from. Commit the core/ change first, then regenerate." >&2
  git status --short -- core | sed 's/^/      /' >&2
  exit 1
fi

git worktree add --detach --no-checkout "$dest" HEAD >/dev/null
git -C "$dest" sparse-checkout init --no-cone >/dev/null
git -C "$dest" sparse-checkout set '/*' '!/test/golden/' >/dev/null
git -C "$dest" checkout >/dev/null 2>&1

# Assert rather than assume. A sparse pattern that silently stopped matching would leave the
# answer sitting in the run's working directory while this script reported success.
if [ -e "$dest/test/golden" ]; then
  echo "FAIL: test/golden/ is present in $dest — the sparse pattern did not take" >&2
  git worktree remove --force "$dest" >/dev/null 2>&1 || true
  exit 1
fi
for required in core/procedure.md core/tools scripts/seed-target.sh test/fixtures; do
  [ -e "$dest/$required" ] || {
    echo "FAIL: $required is missing from $dest — the worktree is not usable" >&2
    git worktree remove --force "$dest" >/dev/null 2>&1 || true
    exit 1
  }
done

abs="$(cd "$dest" && pwd)"
cat <<EOF
blind worktree: $abs
  core/, scripts/, test/fixtures/ present — test/golden/ absent

Run the migration from there, then freeze from this checkout:

  cd $abs
  ./scripts/seed-target.sh <target-tool> /tmp/g
  /open-migrate <source> <target>                       # destination /tmp/g
  ./scripts/verify-migration.sh /tmp/g <target> <source>

  cd $repo_dir
  ./scripts/freeze-golden.sh <source> <target> /tmp/g   # add "project" for project scope
  git worktree remove $abs
EOF
