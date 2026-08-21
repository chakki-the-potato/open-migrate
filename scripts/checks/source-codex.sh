# source-codex.sh — checks for the source-dependent strings that must appear in
# migration-report.md when Codex was the source. Uses only what _common.sh exports
# (mig_dir, chk/chk_not), so it combines safely with any target — it never depends on
# variables that a target-*.sh creates. _common.sh already verified that
# migration-report.md itself exists.

chk "report: keybindings non-migratable" grep -qi "keybinding" "${mig_dir}migration-report.md"
chk "report: source model noted"       grep -qF "gpt-5.6-sol" "${mig_dir}migration-report.md"
chk "report: disabled server noted"    grep -qF "disabled_one" "${mig_dir}migration-report.md"
chk "report: secret re-entry listed"   grep -qF "X-API-Key" "${mig_dir}migration-report.md"
chk "report: approval policy suggested" grep -qE "approval_policy|sandbox_mode|defaultMode" "${mig_dir}migration-report.md"
