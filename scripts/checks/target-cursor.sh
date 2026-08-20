# target-cursor.sh — Cursor 타겟 전용 체크.
# _common.sh 가 내보낸 TARGET, mig_dir, is_noop_rerun, find_run_artifact,
# script_dir, chk/chk_not 을 그대로 사용한다.
#
# Cursor 는 모든 설정이 순수 JSON(mcp.json, hooks.json, cli-config.json)이라
# Codex 처럼 TOML 변환이 필요 없다 — jq 로 파일 경로를 직접 검증한다.

cursor_glob_exists() {
  compgen -G "$1" > /dev/null 2>&1
}

# 전역 규칙 (Rules) — Cursor 에는 쓸 곳이 없다(core/tools/cursor.md "쓰기 규칙" 표의
# 전역 규칙 행). 홈 스코프 마이그레이션(프로젝트 루트 미지정)이므로 (b) 케이스가
# 적용된다: 어디에도 쓰지 않고 규칙 원문을 리포트의 수동 조치 목록에 싣는다.
# .cursor/rules/*.md 로 절대 쓰지 않는다 — Cursor 가 순수 .md 규칙 파일을 무시하기
# 때문이다(문서 원문: "어느 경우든 .cursor/rules/*.md 로는 쓰지 않는다").
chk_not "no invented .cursor/rules/*.md"     cursor_glob_exists "$TARGET/.cursor/rules/*.md"
chk_not "no invented rules/*.md at home root" cursor_glob_exists "$TARGET/rules/*.md"
chk "report carries rule text for manual entry (rule 1)" grep -qF "Answer in Korean." "${mig_dir}migration-report.md"
chk "report carries rule text for manual entry (rule 2)" grep -qF "Never commit secrets." "${mig_dir}migration-report.md"

# MCP — mcp.json (파싱 가능성 + 기존 서버 보존 + 신규 서버 값 + 시크릿 redaction)
chk "mcp.json valid JSON"              jq -e . "$TARGET/mcp.json"
chk "existing MCP server preserved"    jq -e '.mcpServers.otherserver.command == "otherbin"' "$TARGET/mcp.json"
chk "mcp everything command"           jq -e '.mcpServers.everything.command == "npx"' "$TARGET/mcp.json"
chk "mcp everything arg: -y"           jq -e '.mcpServers.everything.args | index("-y") != null' "$TARGET/mcp.json"
chk "mcp everything arg: package"      jq -e '.mcpServers.everything.args | index("@modelcontextprotocol/server-everything") != null' "$TARGET/mcp.json"
chk "mcp everything env"               jq -e '.mcpServers.everything.env.LOG_LEVEL == "info"' "$TARGET/mcp.json"
chk "mcp secretsvc url"                jq -e '.mcpServers.secretsvc.url == "https://example.com/mcp"' "$TARGET/mcp.json"
chk "mcp secretsvc header redacted"    jq -e '.mcpServers.secretsvc.headers."X-API-Key" == "<REDACTED-REENTER>"' "$TARGET/mcp.json"

# 스킬 (Claude·Codex와 동일 agent-skills 표준 — 그대로 복사)
chk "skill copied"                     test -f "$TARGET/skills/hello/SKILL.md"
chk "skill content identical"          grep -qF "Say hello and summarize" "$TARGET/skills/hello/SKILL.md"
chk "skill supporting file copied"     test -f "$TARGET/skills/hello/reference/tone.md"
chk "skill supporting file content"    grep -qF "Keep the greeting under two sentences." "$TARGET/skills/hello/reference/tone.md"

# 앱 관리 영역 — skills-cursor/ 는 Cursor 내장 콘텐츠, 양방향 이관 대상이 아니다.
# 기존 콘텐츠가 그대로 남아있고(untouched), 이관된 스킬이 여기로 새어들지 않아야 한다.
chk "skills-cursor pre-existing content untouched" grep -qF "APP-MANAGED-DECOY-UNTOUCHED" "$TARGET/skills-cursor/canvas/SKILL.md"
chk_not "no migrated content leaked into skills-cursor" test -e "$TARGET/skills-cursor/hello"

# 서브에이전트 — name/description만 쓴다. Claude 전용 필드(tools/color)는 대응 필드가
# 없어 드롭해야 한다(문서: "소스가 Claude면 tools/color는 Cursor에 대응 필드가 없어
# 드롭 후 리포트").
chk "agent copied"                     test -f "$TARGET/agents/reviewer.md"
chk "agent frontmatter name"           grep -q "^name: reviewer" "$TARGET/agents/reviewer.md"
chk "agent frontmatter description"    grep -qF "description: Reviews diffs for style violations" "$TARGET/agents/reviewer.md"
chk "agent body carried over"          grep -qF "strict code reviewer" "$TARGET/agents/reviewer.md"
chk_not "no Claude-only tools field"   grep -q "^tools:" "$TARGET/agents/reviewer.md"
chk_not "no Claude-only color field"   grep -q "^color:" "$TARGET/agents/reviewer.md"

# 훅 — hooks.json. version:1, camelCase 이벤트명, flat 배열(중첩 matcher/hooks 아님).
# matcher/command/timeout 이 "같은 배열 원소" 위에 함께 있어야 한다 — 파일 어딘가에
# 각각 따로 존재하는 것만으로는 부족하다.
chk "hooks.json valid JSON"            jq -e . "$TARGET/hooks.json"
chk "hooks.json version 1"             jq -e '.version == 1' "$TARGET/hooks.json"
chk "preToolUse under camelCase event" jq -e '.hooks.preToolUse | type == "array" and length >= 1' "$TARGET/hooks.json"
chk "edit hook: matcher+command+timeout on same object" jq -e '.hooks.preToolUse | map(select(.matcher == "Write" and .command == "echo pre-edit-check" and .timeout == 10)) | length >= 1' "$TARGET/hooks.json"
chk_not "preToolUse entries are flat, not Claude/Codex nested shape" jq -e '.hooks.preToolUse | map(select(has("hooks"))) | length > 0' "$TARGET/hooks.json"
chk "existing sessionStart hook preserved" jq -e '.hooks.sessionStart | length >= 1' "$TARGET/hooks.json"
chk_not "Notification not carried (Cursor unsupported event)" jq -e '.hooks | has("Notification") or has("notification")' "$TARGET/hooks.json"

# 권한 — cli-config.json. Shell(cmd) 토큰은 콜론 인자 매칭이 Claude Bash(cmd:*)와
# 형태가 같다(문서: "값을 그대로 옮긴다") — Bash(git status:*) 는 Shell(git status:*)
# 가 된다. approvalMode 는 절대 자동 설정하지 않는다.
chk "cli-config.json valid JSON"       jq -e . "$TARGET/cli-config.json"
chk "existing allow token preserved"   jq -e '.permissions.allow | index("Shell(ls)") != null' "$TARGET/cli-config.json"
chk "allow: git status"                jq -e '.permissions.allow | index("Shell(git status:*)") != null' "$TARGET/cli-config.json"
chk "allow: npm run build"             jq -e '.permissions.allow | index("Shell(npm run build:*)") != null' "$TARGET/cli-config.json"
chk "allow: npm run test"              jq -e '.permissions.allow | index("Shell(npm run test:*)") != null' "$TARGET/cli-config.json"
chk "deny: rm"                         jq -e '.permissions.deny | index("Shell(rm:*)") != null' "$TARGET/cli-config.json"
chk_not "git status not also denied"   jq -e '.permissions.deny | index("Shell(git status:*)") != null' "$TARGET/cli-config.json"
chk_not "rm not also allowed"          jq -e '.permissions.allow | index("Shell(rm:*)") != null' "$TARGET/cli-config.json"
# approvalMode 는 타겟에 원래 값이 있을 수 있다 — "없어야 한다"가 아니라 "바뀌지 않았어야 한다"가 옳다.
chk "approvalMode unchanged"           sh -c 'cur=$(jq -r ".approvalMode // \"__none__\"" "$1" 2>/dev/null || echo __none__); bak=$(jq -r ".approvalMode // \"__none__\"" "$2" 2>/dev/null || echo __none__); [ "$cur" = "$bak" ]' _ "$TARGET/cli-config.json" "$(find_run_artifact backup/cli-config.json)"

# 백업 — JSON 설정 파일 병합 규칙("수정 전 원본을 backup/<파일명>으로 복사")이 적용되는
# 3개 파일(mcp.json, hooks.json, cli-config.json) 모두 원본이 보존돼야 한다.
cursor_backup_mcp="$(find_run_artifact backup/mcp.json)"
cursor_backup_hooks="$(find_run_artifact backup/hooks.json)"
cursor_backup_cli="$(find_run_artifact backup/cli-config.json)"
: "${cursor_backup_mcp:=$TARGET/.migrate/__missing__/backup/mcp.json}"
: "${cursor_backup_hooks:=$TARGET/.migrate/__missing__/backup/hooks.json}"
: "${cursor_backup_cli:=$TARGET/.migrate/__missing__/backup/cli-config.json}"

chk "backup of pre-existing mcp.json"        test -f "$cursor_backup_mcp"
chk "backup mcp.json is the original"        jq -e '.mcpServers | has("otherserver") and (has("everything") | not)' "$cursor_backup_mcp"
chk "backup of pre-existing hooks.json"      test -f "$cursor_backup_hooks"
chk "backup hooks.json is the original"      jq -e '(.hooks.preToolUse == null) and (.hooks.sessionStart | length) == 1' "$cursor_backup_hooks"
chk "backup of pre-existing cli-config.json" test -f "$cursor_backup_cli"
chk "backup cli-config.json is the original" jq -e '.permissions.allow == ["Shell(ls)"]' "$cursor_backup_cli"
