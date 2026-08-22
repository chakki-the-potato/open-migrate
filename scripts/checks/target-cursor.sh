# target-cursor.sh — checks specific to a Cursor target.
# Uses TARGET, mig_dir, is_noop_rerun, find_run_artifact, script_dir, and chk/chk_not
# exactly as _common.sh exports them.
#
# Every Cursor config file is plain JSON (hooks.json, cli-config.json), so no TOML
# conversion is needed as it is for Codex — jq validates the file paths directly.

cursor_glob_exists() {
  compgen -G "$1" > /dev/null 2>&1
}

# Global rules — Cursor has nowhere to write them (core/tools/cursor.md, global rules row of
# the write-rules table). This is a home-scope migration with no project root given, so case
# (b) applies: write nothing and put the rule text in the report's manual-action list.
# Never write to .cursor/rules/*.md — Cursor ignores plain .md rule files (per the doc:
# "In neither case write to .cursor/rules/*.md").
chk_not "no invented .cursor/rules/*.md"     cursor_glob_exists "$TARGET/.cursor/rules/*.md"
chk_not "no invented rules/*.md at home root" cursor_glob_exists "$TARGET/rules/*.md"
chk "report carries rule text for manual entry (rule 1)" grep -qF "Answer in Korean." "${mig_dir}migration-report.md"
chk "report carries rule text for manual entry (rule 2)" grep -qF "Never commit secrets." "${mig_dir}migration-report.md"


# Skills (same agent-skills standard as Claude and Codex — copied unchanged)
chk "skill copied"                     test -f "$TARGET/skills/hello/SKILL.md"
chk "skill content identical"          grep -qF "Say hello and summarize" "$TARGET/skills/hello/SKILL.md"
chk "skill supporting file copied"     test -f "$TARGET/skills/hello/reference/tone.md"
chk "skill supporting file content"    grep -qF "Keep the greeting under two sentences." "$TARGET/skills/hello/reference/tone.md"

# App-managed area — skills-cursor/ is Cursor's built-in content and is not migratable in
# either direction. Existing content must stay untouched, and migrated skills must not leak in.
chk "skills-cursor pre-existing content untouched" grep -qF "APP-MANAGED-DECOY-UNTOUCHED" "$TARGET/skills-cursor/canvas/SKILL.md"
chk_not "no migrated content leaked into skills-cursor" test -e "$TARGET/skills-cursor/hello"

# Subagents — write only name/description. The Claude-only fields (tools/color) have no
# corresponding field here and must be dropped (per the doc: "When the source is Claude,
# tools and color have no corresponding Cursor field — drop and record").
chk "agent copied"                     test -f "$TARGET/agents/reviewer.md"
chk "agent frontmatter name"           grep -q "^name: reviewer" "$TARGET/agents/reviewer.md"
chk "agent frontmatter description"    grep -qF "description: Reviews diffs for style violations" "$TARGET/agents/reviewer.md"
chk "agent body carried over"          grep -qF "strict code reviewer" "$TARGET/agents/reviewer.md"
chk_not "no Claude-only tools field"   grep -q "^tools:" "$TARGET/agents/reviewer.md"
chk_not "no Claude-only color field"   grep -q "^color:" "$TARGET/agents/reviewer.md"

# Hooks — hooks.json. version:1, camelCase event names, flat arrays (not the nested
# matcher/hooks shape). matcher, command, and timeout must sit together on the *same array
# element* — each merely existing somewhere in the file is not enough.
chk "hooks.json valid JSON"            jq -e . "$TARGET/hooks.json"
chk "hooks.json version 1"             jq -e '.version == 1' "$TARGET/hooks.json"
chk "preToolUse under camelCase event" jq -e '.hooks.preToolUse | type == "array" and length >= 1' "$TARGET/hooks.json"
chk "edit hook: matcher+command+timeout on same object" jq -e '.hooks.preToolUse | map(select(.matcher == "Write" and .command == "echo pre-edit-check" and .timeout == 10)) | length >= 1' "$TARGET/hooks.json"
chk_not "preToolUse entries are flat, not Claude/Codex nested shape" jq -e '.hooks.preToolUse | map(select(has("hooks"))) | length > 0' "$TARGET/hooks.json"
chk "existing sessionStart hook preserved" jq -e '.hooks.sessionStart | length >= 1' "$TARGET/hooks.json"
chk_not "Notification not carried (Cursor unsupported event)" jq -e '.hooks | has("Notification") or has("notification")' "$TARGET/hooks.json"

# Permissions — cli-config.json. The Shell(cmd) token's colon argument matching has the same
# shape as Claude's Bash(cmd:*), so the argument syntax carries over unchanged — Bash(git
# status:*) becomes Shell(git status:*). approvalMode is never set automatically.
chk "cli-config.json valid JSON"       jq -e . "$TARGET/cli-config.json"
chk "existing allow token preserved"   jq -e '.permissions.allow | index("Shell(ls)") != null' "$TARGET/cli-config.json"
chk "allow: git status"                jq -e '.permissions.allow | index("Shell(git status:*)") != null' "$TARGET/cli-config.json"
chk "allow: npm run build"             jq -e '.permissions.allow | index("Shell(npm run build:*)") != null' "$TARGET/cli-config.json"
chk "allow: npm run test"              jq -e '.permissions.allow | index("Shell(npm run test:*)") != null' "$TARGET/cli-config.json"
chk "deny: rm"                         jq -e '.permissions.deny | index("Shell(rm:*)") != null' "$TARGET/cli-config.json"
chk_not "git status not also denied"   jq -e '.permissions.deny | index("Shell(git status:*)") != null' "$TARGET/cli-config.json"
chk_not "rm not also allowed"          jq -e '.permissions.allow | index("Shell(rm:*)") != null' "$TARGET/cli-config.json"
# approvalMode may already have a value on the target — the correct assertion is "unchanged", not "absent".
chk "approvalMode unchanged"           sh -c 'cur=$(jq -r ".approvalMode // \"__none__\"" "$1" 2>/dev/null || echo __none__); bak=$(jq -r ".approvalMode // \"__none__\"" "$2" 2>/dev/null || echo __none__); [ "$cur" = "$bak" ]' _ "$TARGET/cli-config.json" "$(find_run_artifact backup/cli-config.json)"

# Backups — the JSON config merge rule ("copy the original to backup/<filename> before
# modifying") covers both files (hooks.json, cli-config.json); each original
# must be preserved.
cursor_backup_hooks="$(find_run_artifact backup/hooks.json)"
cursor_backup_cli="$(find_run_artifact backup/cli-config.json)"
: "${cursor_backup_hooks:=$TARGET/.migrate/__missing__/backup/hooks.json}"
: "${cursor_backup_cli:=$TARGET/.migrate/__missing__/backup/cli-config.json}"

chk "backup of pre-existing hooks.json"      test -f "$cursor_backup_hooks"
chk "backup hooks.json is the original"      jq -e '(.hooks.preToolUse == null) and (.hooks.sessionStart | length) == 1' "$cursor_backup_hooks"
chk "backup of pre-existing cli-config.json" test -f "$cursor_backup_cli"
chk "backup cli-config.json is the original" jq -e '.permissions.allow == ["Shell(ls)"]' "$cursor_backup_cli"
