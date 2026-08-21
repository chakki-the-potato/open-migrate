# source-cursor.sh — checks for the source-dependent strings that must appear in
# migration-report.md when Cursor was the source. Uses only what _common.sh exports
# (mig_dir, chk/chk_not), so it combines safely with any target — it never depends on
# variables that a target-*.sh creates. _common.sh already verified that
# migration-report.md itself exists.

chk "report: secret re-entry listed"      grep -qF "X-API-Key" "${mig_dir}migration-report.md"
chk "report: approval policy suggested"   grep -qE "approvalMode|approval_policy|sandbox_mode|defaultMode" "${mig_dir}migration-report.md"

# User Rules has no local file — it lives only in the Cursor account (cloud-synced), which
# makes automatic migration fundamentally impossible (core/tools/cursor.md, the User Rules
# row of "Config inventory" plus the global-rules conversion rule). The report must state
# both that fact and that it cannot be migrated automatically.
# The Korean alternatives are kept for reports generated before the docs switched to English.
chk "report: User Rules noted as account-stored" grep -qF "User Rules" "${mig_dir}migration-report.md"
chk "report: User Rules manual action"    grep -qE "User Rules.*(수동|manual|직접)" "${mig_dir}migration-report.md"

# Cursor permissions have only allow/deny, so there is no ask tier at all (core/tools/
# cursor.md, permission rules inventory). The report must cover both directions: (1) another
# tool's ask rules have nothing to map onto in Cursor, and (2) conversely, when Cursor is the
# source, a command absent from both allow and deny is implicitly prompted by the Cursor
# runtime — but that is not an explicitly recorded rule, so there is no explicit expression
# on the source side to carry over.
chk "report: approvalMode value quoted"   grep -qF "allowlist" "${mig_dir}migration-report.md"
chk "report: app-managed area noted"      grep -qF "skills-cursor" "${mig_dir}migration-report.md"
