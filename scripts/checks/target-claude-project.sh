# target-claude-project.sh — checks for a Claude Code target in a project-scope
# migration. TARGET is the project root, not a home directory. Uses TARGET,
# mig_dir, find_run_artifact, and chk/chk_not from _common.sh.

# Project rules land in the project's CLAUDE.md.
chk "project CLAUDE.md exists"        test -f "$TARGET/CLAUDE.md"
chk "project rule 1 migrated"         grep -qF "Use tabs, not spaces" "$TARGET/CLAUDE.md"
chk "project rule 2 migrated"         grep -qF "Never touch the generated/ directory" "$TARGET/CLAUDE.md"
chk "merge heading present"           grep -q "^## Migrated from codex" "$TARGET/CLAUDE.md"
chk "per-file subheading present"     grep -q "^### AGENTS.md" "$TARGET/CLAUDE.md"


# Project hooks go into .claude/settings.json, converted from the Codex matcher.
chk "project settings valid JSON"     jq -e . "$TARGET/.claude/settings.json"
chk "project hook matcher converted"  jq -e '[.hooks.PreToolUse[].matcher] | index("Edit|Write") != null' "$TARGET/.claude/settings.json"
chk "project hook body carried"       jq -e '[.hooks.PreToolUse[].hooks[].command] | index("echo project-pre-edit") != null' "$TARGET/.claude/settings.json"

# Project skills are copied into the project's own skill directory.
chk "project skill copied"            test -f "$TARGET/.claude/skills/proj-hello/SKILL.md"
chk "project skill content"           grep -qF "Greet using the project conventions" "$TARGET/.claude/skills/proj-hello/SKILL.md"

# Claude does NOT read .agents/skills/, so the vendor-neutral skill must be migrated.
chk "vendor-neutral skill migrated"   test -f "$TARGET/.claude/skills/shared-skill/SKILL.md"

# Home-scope-only settings must not leak into the project layer.
chk_not "no model at project scope"   jq -e '.model' "$TARGET/.claude/settings.json"
chk_not "no defaultMode at project"   jq -e '.permissions.defaultMode' "$TARGET/.claude/settings.json"

# Backup of anything pre-existing that got modified.
claude_proj_backup="$(find_original_artifact backup/CLAUDE.md)"
: "${claude_proj_backup:=$TARGET/.migrate/__missing__/backup/CLAUDE.md}"
chk "backup of pre-existing CLAUDE.md" test -f "$claude_proj_backup"
chk "backup is the original"           grep -qF "Keep this project note." "$claude_proj_backup"

# The report has to state git tracking status for files it touched.
chk "report notes git tracking"        grep -qiE "git|tracked" "${mig_dir}migration-report.md"
