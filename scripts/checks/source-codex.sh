# source-codex.sh — checks for the source-dependent strings that must appear in
# migration-report.md when Codex was the source. Uses only what _common.sh exports
# (mig_dir, chk/chk_not), so it combines safely with any target — it never depends on
# variables that a target-*.sh creates. _common.sh already verified that
# migration-report.md itself exists.

chk "report: keybindings non-migratable" grep -qi "keybinding" "${mig_dir}migration-report.md"
chk "report: source model noted"       grep -qF "gpt-5.6-sol" "${mig_dir}migration-report.md"
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

# ── Guards that only a real Codex config exercises ─────────────────────
# Each of these covers a rule added after a dry run against an actual ~/.codex.
# All four assertions are target-agnostic: they read $TARGET and the report, never a
# variable a target-<tool>.sh created.

# A hook object can carry fields outside the shared structure (Codex's statusMessage).
# Carrying one into the target risks a config the tool rejects; dropping it silently
# loses something the user wrote. Drop it, and name it.
chk_not "codex-only hook field not carried" \
  grep -rqF --exclude-dir=.migrate "statusMessage" "$TARGET"
chk "report: dropped hook field named"      grep -qF "statusMessage" "${mig_dir}migration-report.md"

# A native Codex tool name maps by function where the target has an equivalent and
# nowhere where it does not. Either way the raw name must not survive as a matcher —
# a matcher the target does not know scopes the hook to nothing, silently.
chk_not "raw codex tool name not used as matcher" \
  grep -rqF --exclude-dir=.migrate "read_file" "$TARGET"
chk "report: codex tool name accounted for"  grep -qF "read_file" "${mig_dir}migration-report.md"

# A hook command naming a script inside the source tool's home makes the target depend
# on a directory the user may be about to delete. Do not rewrite the path — report it.
chk "report: hook path into source home flagged" \
  grep -qF ".codex/hooks/notify.sh" "${mig_dir}migration-report.md"

# A digest is high-entropy by construction and trips the secret rule, but redacting one
# breaks a working setting for no gain. It must survive verbatim somewhere in the run.
chk "digest carried over, not redacted" \
  grep -rqF "02aa45f33f6384022cfc3e1045ad58ac1af9db9b095d259367f3a3fb6aaf33a7" "$TARGET"

# A secret inside a migrated config value is replaced, and its key name is handed back so
# the user can re-enter it. The key name is the target-agnostic half: a target with no env
# surface carries it as a manual action instead of a redacted value.
chk "report: secret env key listed for re-entry" \
  grep -qF "SERVICE_API_KEY" "${mig_dir}migration-report.md"
