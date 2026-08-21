# target-grok.sh — checks specific to a Grok Build target.
# Uses TARGET, mig_dir, is_noop_rerun, find_run_artifact, script_dir, chk/chk_not, and the
# source surface flags (src_has_*) exactly as _common.sh exports them.
#
# jq cannot read TOML, so convert to JSON with python3 tomllib and pipe that to jq.
# Chain the EXIT trap instead of clobbering it (same reason as target-codex.sh).
grok_add_exit_trap() {
  local new="$1" existing
  existing="$(trap -p EXIT 2>/dev/null | sed -e "s/^trap -- '//" -e "s/' EXIT\$//")"
  if [ -n "$existing" ]; then
    trap "${existing}; ${new}" EXIT
  else
    trap "${new}" EXIT
  fi
}

grok_toml_to_json() {
  python3 "$script_dir/toml-to-json.py" "$1" 2>/dev/null || printf '{}'
}

grok_toml_json="$(mktemp)"
grok_backup_config_json="$(mktemp)"
grok_hooks_all="$(mktemp)"
grok_add_exit_trap "rm -f '$grok_toml_json' '$grok_backup_config_json' '$grok_hooks_all'"

grok_toml_to_json "$TARGET/config.toml" > "$grok_toml_json" || printf '{}' > "$grok_toml_json"
# Hook filenames under hooks/ are arbitrary — combine them all into one JSON array, then query.
jq -s '.' "$TARGET"/hooks/*.json > "$grok_hooks_all" 2>/dev/null || printf '[]' > "$grok_hooks_all"

# Global rules (existing content preserved + migrated + imports kept)
chk "AGENTS.md exists"                 test -f "$TARGET/AGENTS.md"
chk "AGENTS.md keeps existing content" grep -qF "Keep me." "$TARGET/AGENTS.md"
chk "AGENTS.md migrated rule 1"        grep -qF "Answer in Korean." "$TARGET/AGENTS.md"
chk "AGENTS.md migrated rule 2"        grep -qF "Never commit secrets." "$TARGET/AGENTS.md"
chk "AGENTS.md preserves import line"  grep -qF "@~/.agent-rules-fixture.md" "$TARGET/AGENTS.md"
# Nothing is written to rules/ (core/tools/grok.md write rules) — rules collect in AGENTS.md alone.
chk_not "rules dir not written"        sh -c 'ls "$0"/rules/*.md >/dev/null 2>&1' "$TARGET"

# config.toml — parses as TOML + existing top-level values preserved
chk "config.toml parses as TOML"       python3 "$script_dir/toml-to-json.py" "$TARGET/config.toml"
chk "existing model preserved"         jq -e '.model == "grok-5-code"' "$grok_toml_json"
chk "existing env key preserved"       jq -e '.shell_environment_policy.set.EXISTING_KEY == "keep"' "$grok_toml_json"
chk "existing permission preserved"    jq -e '.permission.allow | index("Bash(ls:*)") != null' "$grok_toml_json"

# config.toml — env injection
if [ "$src_has_global_env" = 1 ]; then
chk "env injected"                     jq -e '.shell_environment_policy.set.FIXTURE_FLAG == "1"' "$grok_toml_json"
fi

# config.toml — MCP stdio (same table shape as Codex)
chk "mcp everything command"           jq -e '.mcp_servers.everything.command == "npx"' "$grok_toml_json"
chk "mcp everything arg: -y"           jq -e '.mcp_servers.everything.args | index("-y") != null' "$grok_toml_json"
chk "mcp everything arg: package"      jq -e '.mcp_servers.everything.args | index("@modelcontextprotocol/server-everything") != null' "$grok_toml_json"
chk "mcp everything env"               jq -e '.mcp_servers.everything.env.LOG_LEVEL == "info"' "$grok_toml_json"

# config.toml — MCP remote (the secret must be replaced by the placeholder, never left verbatim)
chk "mcp secretsvc url"                jq -e '.mcp_servers.secretsvc.url == "https://example.com/mcp"' "$grok_toml_json"
chk "mcp secretsvc header redacted"    jq -e '.mcp_servers.secretsvc.http_headers."X-API-Key" == "<REDACTED-REENTER>"' "$grok_toml_json"

# Permissions — Grok's rule strings use Claude's syntax, so they must arrive unconverted.
chk "allow: git status"                jq -e '.permission.allow | index("Bash(git status:*)") != null' "$grok_toml_json"
chk "allow: npm run build"             jq -e '.permission.allow | index("Bash(npm run build:*)") != null' "$grok_toml_json"
chk "allow: npm run test"              jq -e '.permission.allow | index("Bash(npm run test:*)") != null' "$grok_toml_json"
if [ "$src_has_ask_tier" = 1 ]; then
chk "ask: git push"                    jq -e '.permission.ask | index("Bash(git push:*)") != null' "$grok_toml_json"
fi
chk "deny: rm"                         jq -e '.permission.deny | index("Bash(rm:*)") != null' "$grok_toml_json"
chk_not "git status not also denied"   jq -e '.permission.deny | index("Bash(git status:*)") != null' "$grok_toml_json"
chk_not "git push not also allowed"    jq -e '.permission.allow | index("Bash(git push:*)") != null' "$grok_toml_json"

# Approval policy — the approximation is a suggestion only and must never be auto-applied to config.toml
chk_not "permission_mode not auto-applied" jq -e '.ui.permission_mode' "$grok_toml_json"
chk_not "sandbox profile not auto-applied" jq -e '.sandbox.profile' "$grok_toml_json"

# Hooks — top-level structure + events/matchers/payload. The shape matches Claude, so nothing should be converted.
chk "hooks file exists"                sh -c 'ls "$0"/hooks/*.json >/dev/null 2>&1' "$TARGET"
chk "hooks file valid JSON"            jq -e 'length > 0' "$grok_hooks_all"
chk "hooks top-level shape"            jq -e 'map(select(keys == ["hooks"])) | length > 0' "$grok_hooks_all"
chk "hook matcher preserved"           jq -e '[.[].hooks.PreToolUse[]? | select(.matcher == "Edit|Write")] | length >= 1' "$grok_hooks_all"
chk "hook body paired with matcher"    jq -e '[.[].hooks.PreToolUse[]? | select(.matcher == "Edit|Write") | .hooks[] | select(.command == "echo pre-edit-check" and .timeout == 10)] | length >= 1' "$grok_hooks_all"
if [ "$src_has_notification_hook" = 1 ]; then
# Grok supports the Notification event (it is among the 15) — unlike Codex, it must not be dropped.
chk "notification hook migrated"       jq -e '[.[].hooks.Notification[]?.hooks[]? | select(.command == "echo notify")] | length >= 1' "$grok_hooks_all"
fi
# Events outside Grok's 15 must be dropped.
chk_not "ConfigChange dropped"         grep -rqF "ConfigChange" "$TARGET/hooks"

# Skills (agent-skills standard — copied unchanged)
chk "skill copied"                     test -f "$TARGET/skills/hello/SKILL.md"
chk "skill content identical"          grep -qF "Say hello and summarize" "$TARGET/skills/hello/SKILL.md"
chk "skill supporting file copied"     test -f "$TARGET/skills/hello/reference/tone.md"
chk "skill supporting file content"    grep -qF "Keep the greeting under two sentences." "$TARGET/skills/hello/reference/tone.md"

# Commands — Grok has no command surface. Source commands must be converted into skills.
if [ "$src_has_commands" = 1 ]; then
chk "command converted to skill"       test -f "$TARGET/skills/greet/SKILL.md"
chk "converted skill keeps ARGUMENTS"  grep -qF '$ARGUMENTS' "$TARGET/skills/greet/SKILL.md"
chk "converted skill body carried"     grep -qF "warmly and mention today" "$TARGET/skills/greet/SKILL.md"
chk_not "no commands dir created"      test -d "$TARGET/commands"
chk_not "no prompts dir created"       test -d "$TARGET/prompts"
fi

# Subagents (md + camelCase frontmatter)
chk "agent written as md"              test -f "$TARGET/agents/reviewer.md"
chk "agent frontmatter name"           grep -q "^name: reviewer" "$TARGET/agents/reviewer.md"
chk "agent description carried"        grep -qF "Reviews diffs for style violations" "$TARGET/agents/reviewer.md"
chk "agent body carried"               grep -qF "strict code reviewer" "$TARGET/agents/reviewer.md"

# Backups (existence + original contents) — security.md's write-safety rules; the filenames are Grok-specific
grok_backup_agents="$(find_run_artifact backup/AGENTS.md)"
grok_backup_config="$(find_run_artifact backup/config.toml)"
: "${grok_backup_agents:=$TARGET/.migrate/__missing__/backup/AGENTS.md}"
: "${grok_backup_config:=$TARGET/.migrate/__missing__/backup/config.toml}"
grok_toml_to_json "$grok_backup_config" > "$grok_backup_config_json" || printf '{}' > "$grok_backup_config_json"

chk "backup of pre-existing AGENTS.md"   test -f "$grok_backup_agents"
chk "backup AGENTS.md is the original"   grep -qF "Keep me." "$grok_backup_agents"
chk "backup of pre-existing config.toml" test -f "$grok_backup_config"
chk "backup config.toml is the original" jq -e '.model == "grok-5-code"' "$grok_backup_config_json"
