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

# ── Argv-prefix rules that cannot become target permissions ────────────
# codex.md: a rule converts only when joining its tokens with spaces yields
# something the target can match. Three shapes never do — a token holding a quote
# or paren, a token holding whitespace, and a joined string past ~200 characters.
# Converting them anyway produces permission entries that match nothing and bury
# the rules that work, so each must be skipped and handed back as a manual action.
# Uses only $TARGET and mig_dir, so it stays safe against every target.
chk_not "inline-script rule not converted"   grep -rqF --exclude-dir=.migrate 'console.log(require' "$TARGET"
chk_not "shell-wrapper rule not converted"   grep -rqF --exclude-dir=.migrate '/bin/zsh -lc' "$TARGET"
chk_not "over-length rule not converted"     grep -rqF --exclude-dir=.migrate 'LONGRULE-TAILMARKER-9f2c' "$TARGET"

# Skipping silently is the other half of the failure: the user cannot re-enter a
# rule that was never named. Each skipped rule appears verbatim in the report.
chk "report: inline-script rule listed verbatim" grep -qF 'console.log(require' "${mig_dir}migration-report.md"
chk "report: shell-wrapper rule listed verbatim" grep -qF '/bin/zsh' "${mig_dir}migration-report.md"
chk "report: over-length rule listed verbatim"   grep -qF 'LONGRULE-TAILMARKER-9f2c' "${mig_dir}migration-report.md"
chk "report: unconvertible rule count stated"    grep -qE '[0-9]+ of [0-9]+ (permission )?rules' "${mig_dir}migration-report.md"
