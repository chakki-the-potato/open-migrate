#!/usr/bin/env bash
set -uo pipefail
TARGET="${1:?usage: verify-migration.sh <target-root>}"
fail=0

chk() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then echo "PASS: $d"; else echo "FAIL: $d"; fail=1; fi; }
chk_not() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then echo "FAIL: $d"; fail=1; else echo "PASS: $d"; fi; }

# 규칙 병합 (기존 보존 + 이관 + import 유지)
chk "CLAUDE.md exists"                 test -f "$TARGET/CLAUDE.md"
chk "CLAUDE.md keeps existing content" grep -q "Keep me." "$TARGET/CLAUDE.md"
chk "CLAUDE.md has migrated rule"      grep -q "Answer in Korean." "$TARGET/CLAUDE.md"
chk "CLAUDE.md preserves import line"  grep -q "@~/.agent-rules-fixture.md" "$TARGET/CLAUDE.md"
chk_not "AGENTS.override precedence"   grep -rq "OVERRIDDEN-DECOY" "$TARGET"

# settings.json 병합
chk "settings.json valid JSON"         jq -e . "$TARGET/settings.json"
chk "existing model preserved"         jq -e '.model == "claude-fable-5"' "$TARGET/settings.json"
chk "hook matcher converted"           jq -e '.hooks.PreToolUse[0].matcher == "Edit|Write"' "$TARGET/settings.json"
chk "notification hook migrated"       jq -e '.hooks.Notification | length >= 1' "$TARGET/settings.json"
chk "env injected"                     jq -e '.env.FIXTURE_FLAG == "1"' "$TARGET/settings.json"
chk "allow: git status"                jq -e '.permissions.allow | index("Bash(git status:*)") != null' "$TARGET/settings.json"
chk "allow: npm run build"             jq -e '.permissions.allow | index("Bash(npm run build:*)") != null' "$TARGET/settings.json"
chk "allow: npm run test"              jq -e '.permissions.allow | index("Bash(npm run test:*)") != null' "$TARGET/settings.json"
chk "ask: git push"                    jq -e '.permissions.ask | index("Bash(git push:*)") != null' "$TARGET/settings.json"
chk "deny: rm"                         jq -e '.permissions.deny | index("Bash(rm:*)") != null' "$TARGET/settings.json"
chk_not "defaultMode not auto-applied" jq -e '.permissions.defaultMode' "$TARGET/settings.json"

# 스킬·커맨드·에이전트
chk "skill copied"                     test -f "$TARGET/skills/hello/SKILL.md"
chk "skill content identical"          grep -q "Say hello and summarize" "$TARGET/skills/hello/SKILL.md"
chk "skill supporting file copied"     test -f "$TARGET/skills/hello/reference/tone.md"
chk "prompt converted to command"      test -f "$TARGET/commands/greet.md"
chk "command keeps ARGUMENTS token"    grep -q '\$ARGUMENTS' "$TARGET/commands/greet.md"
chk "agent converted to md"            test -f "$TARGET/agents/reviewer.md"
chk "agent frontmatter name"           grep -q "^name: reviewer" "$TARGET/agents/reviewer.md"
chk "agent body carried over"          grep -q "strict code reviewer" "$TARGET/agents/reviewer.md"

# .migrate 산출물 (백업·리포트·MCP 명령·원장)
mig_dir="$(ls -d "$TARGET/.migrate/"*/ 2>/dev/null | head -1)"
chk "migrate run dir exists"           test -n "$mig_dir"
chk "report exists"                    test -f "${mig_dir}REPORT.md"
chk "report: keybindings non-migratable" grep -qi "keybinding" "${mig_dir}REPORT.md"
chk "report: disabled server noted"    grep -q "disabled_one" "${mig_dir}REPORT.md"
chk "report: secret re-entry listed"   grep -q "X-API-Key" "${mig_dir}REPORT.md"
chk "mcp commands generated"           test -f "${mig_dir}mcp-commands.sh"
chk "mcp add: everything by name"      grep -qE '(^|[[:space:]])everything([[:space:]]|$)' "${mig_dir}mcp-commands.sh"
chk "mcp add: env carried"             grep -q -- '--env LOG_LEVEL=info' "${mig_dir}mcp-commands.sh"
chk "mcp add: args separator used"     grep -q -- ' -- npx' "${mig_dir}mcp-commands.sh"
chk "mcp add: secretsvc present"       grep -q 'secretsvc' "${mig_dir}mcp-commands.sh"
chk_not "disabled server not added"    grep -q 'disabled_one' "${mig_dir}mcp-commands.sh"
chk "backup of pre-existing CLAUDE.md" test -f "${mig_dir}backup/CLAUDE.md"
chk "backup of pre-existing settings"  test -f "${mig_dir}backup/settings.json"
chk "ledger exists"                    test -f "$TARGET/.migrate/ledger.json"

# 시크릿 불가침
chk_not "no MCP secret leaked"         grep -rq "FAKE-SECRET-123" "$TARGET"
chk_not "auth.json never copied"       grep -rq "AUTH-FAKE-SECRET" "$TARGET"

exit $fail
