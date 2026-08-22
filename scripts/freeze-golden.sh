#!/usr/bin/env bash
# Freezes a freshly migrated target into test/golden/<direction>/ and records which
# revision of the knowledge docs produced it.
#
# The verifier proves that a migrated target is correct. Nothing proved that the target
# still matches what the current docs would produce — a doc edit shipped green because
# the migration itself cannot run in CI. A frozen target plus a doc-hash manifest closes
# that: check-golden-fresh.sh fails the moment a doc moves ahead of the output it made.
#
#   ./scripts/freeze-golden.sh <source> <target-tool> <migrated-dir> [scope]
#
# Example:
#   ./scripts/seed-target.sh claude /tmp/t
#   /open-migrate codex claude          # pointed at /tmp/t
#   ./scripts/freeze-golden.sh codex claude /tmp/t
#
# Absolute paths inside the run artifacts are rewritten to <REPO> and <TARGET> so the
# frozen tree is identical on every machine. The verifier asserts neither, but a golden
# carrying one developer's home directory produces a diff on every regeneration and hides
# the change that matters.
set -euo pipefail

usage() {
  echo "usage: freeze-golden.sh <source> <target-tool> <migrated-dir> [scope]" >&2
  exit 2
}

source_tool="${1:-}"; target_tool="${2:-}"; migrated="${3:-}"; scope="${4:-home}"
[ -n "$source_tool" ] && [ -n "$target_tool" ] && [ -n "$migrated" ] || usage
[ -d "$migrated" ] || { echo "FAIL: no such directory: $migrated" >&2; exit 1; }

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
migrated_abs="$(cd "$migrated" && pwd)"

case "$scope" in
  home)    direction="$source_tool-to-$target_tool" ;;
  project) direction="$source_tool-to-$target_tool-project" ;;
  *) echo "FAIL: scope must be 'home' or 'project', got '$scope'" >&2; exit 1 ;;
esac

dest="$repo_dir/test/golden/$direction"

# A run that found everything already in the ledger writes an empty changes.json and a
# report saying "already migrated". Freezing that would pin a no-op as the expected
# output and every content check would pass against a target that never changed.
run_dir="$(ls -d "$migrated_abs/.migrate/"*/ 2>/dev/null | sort | tail -1 || true)"
[ -n "$run_dir" ] || { echo "FAIL: $migrated has no .migrate/<run-id>/ — nothing was migrated" >&2; exit 1; }
if grep -qE "already migrated|이미 이관됨" "$run_dir/migration-report.md" 2>/dev/null; then
  echo "FAIL: that run was a ledger no-op — seed a fresh target and migrate into it" >&2
  exit 1
fi
run_count="$(ls -d "$migrated_abs/.migrate/"*/ 2>/dev/null | wc -l | tr -d ' ')"
if [ "$run_count" -ne 1 ]; then
  echo "FAIL: $run_count runs under .migrate/ — a golden must come from exactly one run" >&2
  exit 1
fi

rm -rf "$dest"
mkdir -p "$dest"
cp -R "$migrated_abs/." "$dest/"

# Rewrite machine-specific prefixes. Longest first: migrated_abs often sits under repo_dir,
# and replacing the shorter one first would leave a half-substituted path behind.
while IFS= read -r f; do
  tmp="$f.freeze-tmp"
  sed -e "s|$migrated_abs|<TARGET>|g" -e "s|$repo_dir|<REPO>|g" "$f" > "$tmp"
  mv "$tmp" "$f"
done < <(find "$dest/.migrate" -type f \( -name '*.json' -o -name '*.md' \))

python3 - "$repo_dir" "$direction" "$source_tool" "$target_tool" "$scope" <<'PY'
import hashlib, json, pathlib, sys

repo, direction, source, target, scope = sys.argv[1:6]
repo = pathlib.Path(repo)

# A direction depends on the shared procedure and on exactly the two tool docs it pairs.
# Pinning all four tool docs would mark every direction stale whenever any tool changed,
# which is the blunt version of this gate and the reason people stop regenerating.
docs = ["core/procedure.md", "core/security.md", "core/rollback.md"]
docs += sorted({f"core/tools/{source}.md", f"core/tools/{target}.md"})

manifest_path = repo / "test/golden/manifest.json"
manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {"directions": {}}

manifest["directions"][direction] = {
    "source": source,
    "target": target,
    "scope": scope,
    "docs": {d: hashlib.sha256((repo / d).read_bytes()).hexdigest() for d in docs},
}
manifest["directions"] = dict(sorted(manifest["directions"].items()))

manifest_path.parent.mkdir(parents=True, exist_ok=True)
manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
print(f"frozen: test/golden/{direction} ({len(docs)} docs pinned)")
PY
