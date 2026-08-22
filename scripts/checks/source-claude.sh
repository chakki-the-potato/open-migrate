# source-claude.sh — checks for the source-dependent strings that must appear in
# migration-report.md when Claude Code was the source. Uses only what _common.sh exports
# (mig_dir, chk/chk_not), so it combines safely with any target — it never depends on
# variables that a target-*.sh creates. _common.sh already verified that
# migration-report.md itself exists.

chk "report: source model noted"         grep -qF "claude-fable-5" "${mig_dir}migration-report.md"
chk "report: dropped ConfigChange hook noted" grep -qF "ConfigChange" "${mig_dir}migration-report.md"
chk "report: approval policy suggested"  grep -qE "approval_policy|sandbox_mode|defaultMode" "${mig_dir}migration-report.md"

# Secret-report coverage for this source is currently absent. The one secret in this
# fixture used to sit in an MCP header, and MCP is no longer migrated. Restoring it means
# putting a secret-shaped value in a surface this source still migrates and regenerating
# this direction's targets — see source-codex.sh, where that has been done.
chk "report: secret env key listed for re-entry" \
  grep -qF "SERVICE_API_KEY" "${mig_dir}migration-report.md"
