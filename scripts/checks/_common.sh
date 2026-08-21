# _common.sh — checks that depend on neither the target tool nor the source tool,
# plus the run-directory resolution mechanism.
#
# Already defined by the caller (verify-migration.sh): TARGET, TOOL, SOURCE,
# script_dir, chk/chk_not, fail. set -uo pipefail is already in effect.
# The load order is _common.sh -> target-$TOOL.sh -> source-$SOURCE.sh, so a
# source-<tool>.sh *can* reference variables created by target-<tool>.sh (mcp_json,
# for example) — but doing so makes that source file safe only when paired with the
# target file that creates the variable (any other combination dies on a set -u
# undefined-variable error). Sticking to the variables this file exports, such as
# mig_dir, keeps a source file safe against every target — prefer that.
#
# What this file exports for target-<tool>.sh / source-<tool>.sh:
#   mig_dir            Path to the newest run directory (with a trailing slash).
#                       When no .migrate/<run-id>/ exists at all, it points at a
#                       nonexistent .migrate/__missing__/ so the checks below fail
#                       naturally with "file not found".
#   is_noop_rerun       "1" | "0". "1" when the newest run's migration-report.md
#                       records "already migrated" — a legitimate no-op re-run.
#                       Only then may artifacts from an earlier run be accepted.
#                       When "0", trust mig_dir alone, so a broken newest run
#                       cannot pass by borrowing an older run's artifacts.
#   find_run_artifact <path relative to the run dir>
#                       Helper that resolves the path of a point-in-time artifact
#                       (backup/CLAUDE.md, for example) while honoring
#                       is_noop_rerun. Artifacts that accumulate across runs
#                       (mcp-commands.sh) combine differently and do not use this
#                       helper — those target files consult is_noop_rerun directly.

mig_dir="$(ls -d "$TARGET/.migrate/"*/ 2>/dev/null | sort | tail -1)"
if [ -z "$mig_dir" ]; then
  echo "ERROR: no .migrate/<run-id>/ directory under $TARGET — every run-output check below fails for this one reason"
  mig_dir="$TARGET/.migrate/__missing__/"
fi

# Per-run artifacts (backups, MCP commands) are looked up in the newest run by default.
# Artifacts from an earlier run are accepted only when the newest run legitimately created
# nothing because the ledger skipped everything (the report records "already migrated").
# Otherwise a broken newest run could pass by borrowing traces from an older one.
# The Korean marker is kept for reports generated before the docs switched to English.
if grep -qE "already migrated|이미 이관됨" "${mig_dir}migration-report.md" 2>/dev/null; then
  is_noop_rerun=1
else
  is_noop_rerun=0
fi

find_run_artifact() {
  local rel="$1"
  if [ "$is_noop_rerun" = "1" ]; then
    ls "$TARGET/.migrate/"*/"$rel" 2>/dev/null | sort | tail -1
  else
    echo "${mig_dir}${rel}"
  fi
}

# Global rules — override precedence (the decoy must not leak through)
chk_not "AGENTS.override precedence"   grep -rqF "OVERRIDDEN-DECOY" "$TARGET"

# The report artifact exists (its contents are verified by the per-target checks)
chk "report exists"                    test -f "${mig_dir}migration-report.md"

# Ledger (exists + valid + records sha256 hashes)
chk "ledger exists"                    test -f "$TARGET/.migrate/ledger.json"
chk "ledger is valid JSON"             jq -e . "$TARGET/.migrate/ledger.json"
chk "ledger records source hashes"     jq -e '[..|strings] | map(select(test("^[0-9a-f]{64}$"))) | unique | length >= 5' "$TARGET/.migrate/ledger.json"

# Secrets must never leak
chk_not "no MCP secret leaked"         grep -rqF "FAKE-SECRET-123" "$TARGET"
chk_not "auth.json never copied"       grep -rqF "AUTH-FAKE-SECRET" "$TARGET"

# ── Which surfaces the source tool actually has ────────────────────────
# Some config surfaces simply do not exist in a given tool. What the source lacks can
# never appear on the target, so target-*.sh wraps those category checks in these flags
# and only asserts them when the source could have supplied the data.
#   if [ "$src_has_commands" = 1 ]; then chk "..." ...; fi
src_has_commands=1
src_has_global_env=1
src_has_ask_tier=1
src_has_notification_hook=1
case "$SOURCE" in
  cursor)
    # Cursor: commands are deprecated (replaced by skills), there is no global env
    # surface, permissions have only allow/deny, and the Notification hook event
    # is unsupported.
    src_has_commands=0
    src_has_global_env=0
    src_has_ask_tier=0
    src_has_notification_hook=0
    ;;
  grok)
    # Grok Build: no custom prompt surface.
    src_has_commands=0
    ;;
esac
