# target-codex.sh — checks specific to a Codex CLI target.
# Uses TARGET, mig_dir, is_noop_rerun, find_run_artifact, script_dir, and chk/chk_not
# exactly as _common.sh exports them.
#
# jq cannot read TOML, so convert to JSON with python3 tomllib and pipe that to jq.
# _common.sh was verified not to use an EXIT trap, but chain instead of clobbering in case
# that changes later or this file gets reused elsewhere.
codex_add_exit_trap() {
  local new="$1" existing
  existing="$(trap -p EXIT 2>/dev/null | sed -e "s/^trap -- '//" -e "s/' EXIT\$//")"
  if [ -n "$existing" ]; then
    trap "${existing}; ${new}" EXIT
  else
    trap "${new}" EXIT
  fi
}

codex_toml_to_json() {
  python3 "$script_dir/toml-to-json.py" "$1" 2>/dev/null || printf '{}'
}

codex_toml_json="$(mktemp)"
codex_reviewer_toml_json="$(mktemp)"
codex_backup_config_json="$(mktemp)"
codex_rules_all="$(mktemp)"
codex_add_exit_trap "rm -f '$codex_toml_json' '$codex_reviewer_toml_json' '$codex_backup_config_json' '$codex_rules_all'"

codex_toml_to_json "$TARGET/config.toml" > "$codex_toml_json" || printf '{}' > "$codex_toml_json"
codex_toml_to_json "$TARGET/agents/reviewer.toml" > "$codex_reviewer_toml_json" || printf '{}' > "$codex_reviewer_toml_json"
cat "$TARGET"/rules/*.rules > "$codex_rules_all" 2>/dev/null || true

# Global rules (existing content preserved + migrated + imports kept) — same contract as Claude's CLAUDE.md
chk "AGENTS.md exists"                 test -f "$TARGET/AGENTS.md"
chk "AGENTS.md keeps existing content" grep -qF "Keep me." "$TARGET/AGENTS.md"
chk "AGENTS.md migrated rule 1"        grep -qF "Answer in Korean." "$TARGET/AGENTS.md"
chk "AGENTS.md migrated rule 2"        grep -qF "Never commit secrets." "$TARGET/AGENTS.md"
chk "AGENTS.md preserves import line"  grep -qF "@~/.agent-rules-fixture.md" "$TARGET/AGENTS.md"

# config.toml — parses as TOML + existing top-level values preserved
chk "config.toml parses as TOML"       python3 "$script_dir/toml-to-json.py" "$TARGET/config.toml"
chk "existing model preserved"         jq -e '.model == "gpt-5.6-sol"' "$codex_toml_json"
chk "existing env key preserved"       jq -e '.shell_environment_policy.set.EXISTING_KEY == "keep"' "$codex_toml_json"

# config.toml — env injection ([shell_environment_policy.set] <- the source's global env block)
if [ "$src_has_global_env" = 1 ]; then
chk "env injected"                     jq -e '.shell_environment_policy.set.FIXTURE_FLAG == "1"' "$codex_toml_json"
fi



# hooks.json — top-level structure + matcher conversion + per-event payload
chk "hooks.json valid JSON"            jq -e . "$TARGET/hooks.json"
chk "hooks.json top-level shape"       jq -e 'keys == ["hooks"]' "$TARGET/hooks.json"
chk "hook matcher converted to apply_patch" jq -e '.hooks.PreToolUse | map(select(.matcher == "apply_patch")) | length >= 1' "$TARGET/hooks.json"
chk "hook body paired with matcher"    jq -e '.hooks.PreToolUse | map(select(.matcher == "apply_patch")) | .[0].hooks | map(select(.command == "echo pre-edit-check" and .timeout == 10)) | length >= 1' "$TARGET/hooks.json"
# Notification is not among Codex's 11 official events — it would become dead config that
# Codex silently ignores, so it must be dropped and recorded in the report rather than
# migrated (core/tools/codex.md write rules).
chk_not "notification event dropped"   jq -e '.hooks.Notification' "$TARGET/hooks.json"

# hooks.json — the Claude-only event (ConfigChange) is silently dropped and must appear nowhere
chk_not "ConfigChange dropped from hooks.json" grep -qF "ConfigChange" "$TARGET/hooks.json"

# Permissions -> rules/*.rules (prefix_rule DSL, decision mapping: allow/prompt/forbidden)
chk "rules: git status allow"    grep -Eq 'prefix_rule\([[:space:]]*pattern[[:space:]]*=[[:space:]]*\[[[:space:]]*"git"[[:space:]]*,[[:space:]]*"status"[[:space:]]*\][[:space:]]*,[[:space:]]*decision[[:space:]]*=[[:space:]]*"allow"[[:space:]]*\)' "$codex_rules_all"
if [ "$src_has_ask_tier" = 1 ]; then
chk "rules: git push prompt"     grep -Eq 'prefix_rule\([[:space:]]*pattern[[:space:]]*=[[:space:]]*\[[[:space:]]*"git"[[:space:]]*,[[:space:]]*"push"[[:space:]]*\][[:space:]]*,[[:space:]]*decision[[:space:]]*=[[:space:]]*"prompt"[[:space:]]*\)' "$codex_rules_all"
chk "rules: rm forbidden"        grep -Eq 'prefix_rule\([[:space:]]*pattern[[:space:]]*=[[:space:]]*\[[[:space:]]*"rm"[[:space:]]*\][[:space:]]*,[[:space:]]*decision[[:space:]]*=[[:space:]]*"forbidden"[[:space:]]*\)' "$codex_rules_all"
fi
chk "rules: npm run build allow" grep -Eq 'prefix_rule\([[:space:]]*pattern[[:space:]]*=[[:space:]]*\[[[:space:]]*"npm"[[:space:]]*,[[:space:]]*"run"[[:space:]]*,[[:space:]]*"build"[[:space:]]*\][[:space:]]*,[[:space:]]*decision[[:space:]]*=[[:space:]]*"allow"[[:space:]]*\)' "$codex_rules_all"
chk "rules: npm run test allow"  grep -Eq 'prefix_rule\([[:space:]]*pattern[[:space:]]*=[[:space:]]*\[[[:space:]]*"npm"[[:space:]]*,[[:space:]]*"run"[[:space:]]*,[[:space:]]*"test"[[:space:]]*\][[:space:]]*,[[:space:]]*decision[[:space:]]*=[[:space:]]*"allow"[[:space:]]*\)' "$codex_rules_all"

# Approval policy — the docs make the approximation a suggestion only, so it must never be auto-applied to config.toml
chk_not "approval_policy not auto-applied" jq -e '.approval_policy' "$codex_toml_json"
chk_not "sandbox_mode not auto-applied"    jq -e '.sandbox_mode' "$codex_toml_json"

# Skills (same agent-skills standard as Claude — copied unchanged)
chk "skill copied"                     test -f "$TARGET/skills/hello/SKILL.md"
chk "skill content identical"          grep -qF "Say hello and summarize" "$TARGET/skills/hello/SKILL.md"
chk "skill supporting file copied"     test -f "$TARGET/skills/hello/reference/tone.md"
chk "skill supporting file content"    grep -qF "Keep the greeting under two sentences." "$TARGET/skills/hello/reference/tone.md"

# Subagents (md -> TOML)
chk "agent converted to toml"          test -f "$TARGET/agents/reviewer.toml"
chk "agent toml parses"                python3 "$script_dir/toml-to-json.py" "$TARGET/agents/reviewer.toml"
chk "agent description carried"        jq -e '(.description // "") | contains("Reviews diffs for style violations")' "$codex_reviewer_toml_json"
chk "agent developer_instructions carried" jq -e '(.developer_instructions // "") | contains("strict code reviewer")' "$codex_reviewer_toml_json"

# Commands (md -> prompts/*.md)
# Doc gap: the "Write rules (when Codex is the target)" section of core/tools/codex.md does not
# spell out this direction (commands -> prompts) — the skills and subagents directions are
# missing from that section too. Since "Config inventory" and "Conversion rules (Codex -> other
# tools)" establish prompts/*.md as Codex's command surface and the TOML<->md subagent
# conversion as a symmetric rule, these checks assume the same format applies in reverse.
# The doc itself is left untouched — see the report.
if [ "$src_has_commands" = 1 ]; then
chk "prompt converted from command"    test -f "$TARGET/prompts/greet.md"
chk "prompt keeps ARGUMENTS token"     grep -qF '$ARGUMENTS' "$TARGET/prompts/greet.md"
chk "prompt body carried over"         grep -qF "warmly and mention today" "$TARGET/prompts/greet.md"
fi

# Backups (existence + original contents) — security.md's write-safety rules apply to every target; the filenames are Codex-specific
codex_backup_agents="$(find_original_artifact backup/AGENTS.md)"
codex_backup_config="$(find_original_artifact backup/config.toml)"
: "${codex_backup_agents:=$TARGET/.migrate/__missing__/backup/AGENTS.md}"
: "${codex_backup_config:=$TARGET/.migrate/__missing__/backup/config.toml}"
codex_toml_to_json "$codex_backup_config" > "$codex_backup_config_json" || printf '{}' > "$codex_backup_config_json"

chk "backup of pre-existing AGENTS.md"   test -f "$codex_backup_agents"
chk "backup AGENTS.md is the original"   grep -qF "Keep me." "$codex_backup_agents"
chk "backup of pre-existing config.toml" test -f "$codex_backup_config"
chk "backup config.toml is the original" jq -e '.model == "gpt-5.6-sol"' "$codex_backup_config_json"
