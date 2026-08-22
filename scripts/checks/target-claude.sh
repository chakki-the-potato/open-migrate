# target-claude.sh — checks specific to a Claude Code target.
# Uses TARGET, mig_dir, is_noop_rerun, find_run_artifact, script_dir, and chk/chk_not
# exactly as _common.sh exports them.

# Global rules (existing content preserved + migrated + imports kept)
chk "CLAUDE.md exists"                 test -f "$TARGET/CLAUDE.md"
chk "CLAUDE.md keeps existing content" grep -qF "Keep me." "$TARGET/CLAUDE.md"
chk "CLAUDE.md migrated rule 1"        grep -qF "Answer in Korean." "$TARGET/CLAUDE.md"
chk "CLAUDE.md migrated rule 2"        grep -qF "Never commit secrets." "$TARGET/CLAUDE.md"
chk "CLAUDE.md preserves import line"  grep -qF "@~/.agent-rules-fixture.md" "$TARGET/CLAUDE.md"

# settings.json — existing content preserved (deep merge)
chk "settings.json valid JSON"         jq -e . "$TARGET/settings.json"
chk "existing model preserved"         jq -e '.model == "claude-fable-5"' "$TARGET/settings.json"
chk "existing env key preserved"       jq -e '.env.EXISTING_KEY == "keep"' "$TARGET/settings.json"
chk "existing allow rule preserved"    jq -e '.permissions.allow | index("Bash(ls:*)") != null' "$TARGET/settings.json"
chk "existing hook preserved"          jq -e '[.hooks.PreToolUse[].matcher] | index("Read") != null' "$TARGET/settings.json"

# settings.json — hooks migrated (matcher + command body + timeout)
chk "hook matcher converted"           jq -e '[.hooks.PreToolUse[].matcher] | index("Edit|Write") != null' "$TARGET/settings.json"
chk "hook body paired with matcher"    jq -e '.hooks.PreToolUse | map(select(.matcher == "Edit|Write")) | .[0].hooks | map(select(.command == "echo pre-edit-check" and .timeout == 10)) | length >= 1' "$TARGET/settings.json"
chk "existing hook body preserved"     jq -e '.hooks.PreToolUse | map(select(.matcher == "Read")) | .[0].hooks | map(select(.command == "echo existing-pre")) | length >= 1' "$TARGET/settings.json"
if [ "$src_has_notification_hook" = 1 ]; then
chk "notification hook migrated"       jq -e '[.hooks.Notification[].hooks[].command] | index("echo notify") != null' "$TARGET/settings.json"
fi

# settings.json — env injection
if [ "$src_has_global_env" = 1 ]; then
chk "env injected"                     jq -e '.env.FIXTURE_FLAG == "1"' "$TARGET/settings.json"
fi

# settings.json — permissions (present in the right list, absent from the wrong one)
chk "allow: git status"                jq -e '.permissions.allow | index("Bash(git status:*)") != null' "$TARGET/settings.json"
chk "allow: npm run build"             jq -e '.permissions.allow | index("Bash(npm run build:*)") != null' "$TARGET/settings.json"
chk "allow: npm run test"              jq -e '.permissions.allow | index("Bash(npm run test:*)") != null' "$TARGET/settings.json"
if [ "$src_has_ask_tier" = 1 ]; then
chk "ask: git push"                    jq -e '.permissions.ask | index("Bash(git push:*)") != null' "$TARGET/settings.json"
fi
chk "deny: rm"                         jq -e '.permissions.deny | index("Bash(rm:*)") != null' "$TARGET/settings.json"
chk_not "git status not also denied"   jq -e '.permissions.deny | index("Bash(git status:*)") != null' "$TARGET/settings.json"
chk_not "git push not also allowed"    jq -e '.permissions.allow | index("Bash(git push:*)") != null' "$TARGET/settings.json"
chk_not "rm not also allowed"          jq -e '.permissions.allow | index("Bash(rm:*)") != null' "$TARGET/settings.json"
chk "permissions: each rule in exactly one list" jq -e '[.permissions.allow[]?, .permissions.ask[]?, .permissions.deny[]?] as $a | ($a|length) == ($a|unique|length)' "$TARGET/settings.json"
chk_not "defaultMode not auto-applied" jq -e '.permissions.defaultMode' "$TARGET/settings.json"

# Skills, commands, subagents (existence + contents)
chk "skill copied"                     test -f "$TARGET/skills/hello/SKILL.md"
chk "skill content identical"          grep -qF "Say hello and summarize" "$TARGET/skills/hello/SKILL.md"
chk "skill supporting file copied"     test -f "$TARGET/skills/hello/reference/tone.md"
chk "skill supporting file content"    grep -qF "Keep the greeting under two sentences." "$TARGET/skills/hello/reference/tone.md"
if [ "$src_has_commands" = 1 ]; then
chk "prompt converted to command"      test -f "$TARGET/commands/greet.md"
chk "command keeps ARGUMENTS token"    grep -qF '$ARGUMENTS' "$TARGET/commands/greet.md"
chk "command body carried over"        grep -qF "warmly and mention today" "$TARGET/commands/greet.md"
fi
chk "agent converted to md"            test -f "$TARGET/agents/reviewer.md"
chk "agent frontmatter name"           grep -q "^name: reviewer" "$TARGET/agents/reviewer.md"
chk "agent description carried"        grep -qF "Reviews diffs for style violations" "$TARGET/agents/reviewer.md"
chk "agent body carried over"          grep -qF "strict code reviewer" "$TARGET/agents/reviewer.md"

# Source-dependent report strings (a Codex model name, for example) live in source-<tool>.sh.

# Backups (existence + original contents) — filenames are Claude-specific; lookup uses _common.sh's find_run_artifact
backup_claude="$(find_run_artifact backup/CLAUDE.md)"
backup_settings="$(find_run_artifact backup/settings.json)"
: "${backup_claude:=$TARGET/.migrate/__missing__/backup/CLAUDE.md}"
: "${backup_settings:=$TARGET/.migrate/__missing__/backup/settings.json}"

chk "backup of pre-existing CLAUDE.md" test -f "$backup_claude"
chk "backup CLAUDE.md is the original" grep -qF "Keep me." "$backup_claude"
chk "backup of pre-existing settings"  test -f "$backup_settings"
chk "backup settings is the original"  jq -e '.model == "claude-fable-5"' "$backup_settings"
