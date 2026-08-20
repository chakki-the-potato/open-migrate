# target-claude.sh — Claude Code 타겟 전용 체크.
# _common.sh 가 내보낸 TARGET, mig_dir, is_noop_rerun, find_run_artifact,
# script_dir, chk/chk_not 을 그대로 사용한다.

# 전역 규칙 (기존 보존 + 이관 + import 유지)
chk "CLAUDE.md exists"                 test -f "$TARGET/CLAUDE.md"
chk "CLAUDE.md keeps existing content" grep -qF "Keep me." "$TARGET/CLAUDE.md"
chk "CLAUDE.md migrated rule 1"        grep -qF "Answer in Korean." "$TARGET/CLAUDE.md"
chk "CLAUDE.md migrated rule 2"        grep -qF "Never commit secrets." "$TARGET/CLAUDE.md"
chk "CLAUDE.md preserves import line"  grep -qF "@~/.agent-rules-fixture.md" "$TARGET/CLAUDE.md"

# settings.json — 기존 보존(deep merge) 검증
chk "settings.json valid JSON"         jq -e . "$TARGET/settings.json"
chk "existing model preserved"         jq -e '.model == "claude-fable-5"' "$TARGET/settings.json"
chk "existing env key preserved"       jq -e '.env.EXISTING_KEY == "keep"' "$TARGET/settings.json"
chk "existing allow rule preserved"    jq -e '.permissions.allow | index("Bash(ls:*)") != null' "$TARGET/settings.json"
chk "existing hook preserved"          jq -e '[.hooks.PreToolUse[].matcher] | index("Read") != null' "$TARGET/settings.json"

# settings.json — 훅 이관 (matcher + command 본문 + timeout)
chk "hook matcher converted"           jq -e '[.hooks.PreToolUse[].matcher] | index("Edit|Write") != null' "$TARGET/settings.json"
chk "hook body paired with matcher"    jq -e '.hooks.PreToolUse | map(select(.matcher == "Edit|Write")) | .[0].hooks | map(select(.command == "echo pre-edit-check" and .timeout == 10)) | length >= 1' "$TARGET/settings.json"
chk "existing hook body preserved"     jq -e '.hooks.PreToolUse | map(select(.matcher == "Read")) | .[0].hooks | map(select(.command == "echo existing-pre")) | length >= 1' "$TARGET/settings.json"
chk "notification hook migrated"       jq -e '[.hooks.Notification[].hooks[].command] | index("echo notify") != null' "$TARGET/settings.json"

# settings.json — env 주입
chk "env injected"                     jq -e '.env.FIXTURE_FLAG == "1"' "$TARGET/settings.json"

# settings.json — 권한 (정답 리스트 존재 + 오답 리스트 부재)
chk "allow: git status"                jq -e '.permissions.allow | index("Bash(git status:*)") != null' "$TARGET/settings.json"
chk "allow: npm run build"             jq -e '.permissions.allow | index("Bash(npm run build:*)") != null' "$TARGET/settings.json"
chk "allow: npm run test"              jq -e '.permissions.allow | index("Bash(npm run test:*)") != null' "$TARGET/settings.json"
chk "ask: git push"                    jq -e '.permissions.ask | index("Bash(git push:*)") != null' "$TARGET/settings.json"
chk "deny: rm"                         jq -e '.permissions.deny | index("Bash(rm:*)") != null' "$TARGET/settings.json"
chk_not "git status not also denied"   jq -e '.permissions.deny | index("Bash(git status:*)") != null' "$TARGET/settings.json"
chk_not "git push not also allowed"    jq -e '.permissions.allow | index("Bash(git push:*)") != null' "$TARGET/settings.json"
chk_not "rm not also allowed"          jq -e '.permissions.allow | index("Bash(rm:*)") != null' "$TARGET/settings.json"
chk "permissions: each rule in exactly one list" jq -e '[.permissions.allow[]?, .permissions.ask[]?, .permissions.deny[]?] as $a | ($a|length) == ($a|unique|length)' "$TARGET/settings.json"
chk_not "defaultMode not auto-applied" jq -e '.permissions.defaultMode' "$TARGET/settings.json"

# 스킬·커맨드·서브에이전트 (존재 + 내용)
chk "skill copied"                     test -f "$TARGET/skills/hello/SKILL.md"
chk "skill content identical"          grep -qF "Say hello and summarize" "$TARGET/skills/hello/SKILL.md"
chk "skill supporting file copied"     test -f "$TARGET/skills/hello/reference/tone.md"
chk "skill supporting file content"    grep -qF "Keep the greeting under two sentences." "$TARGET/skills/hello/reference/tone.md"
chk "prompt converted to command"      test -f "$TARGET/commands/greet.md"
chk "command keeps ARGUMENTS token"    grep -qF '$ARGUMENTS' "$TARGET/commands/greet.md"
chk "command body carried over"        grep -qF "warmly and mention today" "$TARGET/commands/greet.md"
chk "agent converted to md"            test -f "$TARGET/agents/reviewer.md"
chk "agent frontmatter name"           grep -q "^name: reviewer" "$TARGET/agents/reviewer.md"
chk "agent description carried"        grep -qF "Reviews diffs for style violations" "$TARGET/agents/reviewer.md"
chk "agent body carried over"          grep -qF "strict code reviewer" "$TARGET/agents/reviewer.md"

# 리포트 — Codex -> Claude 특화 내용 (파일 자체 존재는 _common.sh 가 이미 검증)
chk "report: keybindings non-migratable" grep -qi "keybinding" "${mig_dir}REPORT.md"
chk "report: source model noted"       grep -qF "gpt-5.6-sol" "${mig_dir}REPORT.md"
chk "report: disabled server noted"    grep -qF "disabled_one" "${mig_dir}REPORT.md"
chk "report: secret re-entry listed"   grep -qF "X-API-Key" "${mig_dir}REPORT.md"
chk "report: approval policy suggested" grep -qE "approval_policy|sandbox_mode|defaultMode" "${mig_dir}REPORT.md"

# MCP 등록 명령 (셸 토큰 파싱 기반 — 주석·부분문자열·줄바꿈·제어연산자에 영향받지 않음)
# mcp-commands.sh 는 run 마다 누적/재생성될 수 있어(예: no-op run 도 감사 목적으로
# 빈 파일을 다시 만든다) "가장 최신 파일 하나"가 아니라 관련 run 전체를 합친다.
mcp_all="$(mktemp)"
mcp_json="$(mktemp)"
trap 'rm -f "$mcp_all" "$mcp_json"' EXIT
if [ "$is_noop_rerun" = "1" ]; then
  cat "$TARGET/.migrate/"*/mcp-commands.sh > "$mcp_all" 2>/dev/null || true
else
  cat "${mig_dir}mcp-commands.sh" > "$mcp_all" 2>/dev/null || true
fi
python3 "$script_dir/parse-mcp-commands.py" "$mcp_all" > "$mcp_json" 2>/dev/null || printf '[]' > "$mcp_json"

chk "mcp commands generated"           test -s "$mcp_all"
chk "mcp add: two servers registered"  jq -e 'length >= 2' "$mcp_json"
chk "mcp add: everything registered"   jq -e 'any(.[]; .name=="everything")' "$mcp_json"
chk "mcp add: everything env"          jq -e 'any(.[]; .name=="everything" and any(.flags[]; .[0]=="--env" and .[1]=="LOG_LEVEL=info"))' "$mcp_json"
chk "mcp add: everything command"      jq -e 'any(.[]; .name=="everything" and .cmd[0]=="npx")' "$mcp_json"
chk "mcp add: everything package arg"  jq -e 'any(.[]; .name=="everything" and any(.cmd[]; .=="@modelcontextprotocol/server-everything"))' "$mcp_json"
chk "mcp add: everything complete"     jq -e 'any(.[]; .name=="everything" and any(.flags[]; .[0]=="--env" and .[1]=="LOG_LEVEL=info") and .cmd[0]=="npx" and any(.cmd[]; .=="@modelcontextprotocol/server-everything"))' "$mcp_json"
chk "mcp add: secretsvc registered"    jq -e 'any(.[]; .name=="secretsvc")' "$mcp_json"
chk "mcp add: secretsvc http"          jq -e 'any(.[]; .name=="secretsvc" and any(.flags[]; .[0]=="--transport" and .[1]=="http"))' "$mcp_json"
chk "mcp add: secretsvc url"           jq -e 'any(.[]; .name=="secretsvc" and any(.args[]; .=="https://example.com/mcp"))' "$mcp_json"
chk "mcp add: secretsvc complete"      jq -e 'any(.[]; .name=="secretsvc" and any(.flags[]; .[0]=="--transport" and .[1]=="http") and any(.args[]; .=="https://example.com/mcp"))' "$mcp_json"
chk_not "disabled server not added"    jq -e 'any(.[]; .name=="disabled_one")' "$mcp_json"

# 백업 (존재 + 원본 내용) — 파일명은 Claude 전용, 조회 메커니즘은 _common.sh 의 find_run_artifact
backup_claude="$(find_run_artifact backup/CLAUDE.md)"
backup_settings="$(find_run_artifact backup/settings.json)"
: "${backup_claude:=$TARGET/.migrate/__missing__/backup/CLAUDE.md}"
: "${backup_settings:=$TARGET/.migrate/__missing__/backup/settings.json}"

chk "backup of pre-existing CLAUDE.md" test -f "$backup_claude"
chk "backup CLAUDE.md is the original" grep -qF "Keep me." "$backup_claude"
chk "backup of pre-existing settings"  test -f "$backup_settings"
chk "backup settings is the original"  jq -e '.model == "claude-fable-5"' "$backup_settings"
