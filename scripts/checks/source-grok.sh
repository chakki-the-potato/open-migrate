# source-grok.sh — checks for the source-dependent strings that must appear in
# migration-report.md when Grok Build was the source. Uses only what _common.sh exports
# (mig_dir, chk/chk_not), so it combines safely with any target — it never depends on
# variables that a target-*.sh creates. _common.sh already verified that
# migration-report.md itself exists.
#
# Anything that varies by target (dropping Grok-only subagent fields, dropping the skill's
# user-invocable key) does not belong here — if the target has that surface, no drop occurs.

chk "report: source model noted"       grep -qF "grok-5-code" "${mig_dir}migration-report.md"
chk "report: approval policy suggested" grep -qE "permission_mode|approval_policy|sandbox_mode|defaultMode|approvalMode" "${mig_dir}migration-report.md"

# GROK.md is not a migration target because Grok itself does not read it (core/tools/grok.md,
# global-rules conversion). Do not ignore it silently — the report must record that such a
# file was found, so a user can trace why rules they wrote never got migrated.
chk "report: unread rules file noted"  grep -qF "GROK.md" "${mig_dir}migration-report.md"

# Secret-report coverage for this source is currently absent. The one secret in this
# fixture used to sit in an MCP header, and MCP is no longer migrated. Restoring it means
# putting a secret-shaped value in a surface this source still migrates and regenerating
# this direction's targets — see source-codex.sh, where that has been done.
chk "report: secret env key listed for re-entry" \
  grep -qF "SERVICE_API_KEY" "${mig_dir}migration-report.md"
