# target-grok.sh — Grok Build 타겟 전용 체크.
# _common.sh 가 내보낸 TARGET, mig_dir, is_noop_rerun, find_run_artifact,
# script_dir, chk/chk_not, 그리고 소스 표면 플래그(src_has_*)를 그대로 사용한다.
#
# TOML은 jq로 못 읽으므로 python3 tomllib로 JSON 변환 후 jq에 넘긴다.
# EXIT trap은 clobber 대신 체이닝한다(target-codex.sh와 같은 이유).
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
# 훅은 hooks/ 아래 파일명이 자유롭다 — 전부 합쳐 하나의 JSON 배열로 만든 뒤 조회한다.
jq -s '.' "$TARGET"/hooks/*.json > "$grok_hooks_all" 2>/dev/null || printf '[]' > "$grok_hooks_all"

# 전역 규칙 (기존 보존 + 이관 + import 유지)
chk "AGENTS.md exists"                 test -f "$TARGET/AGENTS.md"
chk "AGENTS.md keeps existing content" grep -qF "Keep me." "$TARGET/AGENTS.md"
chk "AGENTS.md migrated rule 1"        grep -qF "Answer in Korean." "$TARGET/AGENTS.md"
chk "AGENTS.md migrated rule 2"        grep -qF "Never commit secrets." "$TARGET/AGENTS.md"
chk "AGENTS.md preserves import line"  grep -qF "@~/.agent-rules-fixture.md" "$TARGET/AGENTS.md"
# rules/ 에는 쓰지 않는다(core/tools/grok.md 쓰기 규칙) — 규칙은 AGENTS.md 한 곳으로 모은다.
chk_not "rules dir not written"        sh -c 'ls "$0"/rules/*.md >/dev/null 2>&1' "$TARGET"

# config.toml — 파싱 가능성 + 기존 최상위 값 보존
chk "config.toml parses as TOML"       python3 "$script_dir/toml-to-json.py" "$TARGET/config.toml"
chk "existing model preserved"         jq -e '.model == "grok-5-code"' "$grok_toml_json"
chk "existing env key preserved"       jq -e '.shell_environment_policy.set.EXISTING_KEY == "keep"' "$grok_toml_json"
chk "existing permission preserved"    jq -e '.permission.allow | index("Bash(ls:*)") != null' "$grok_toml_json"

# config.toml — env 주입
if [ "$src_has_global_env" = 1 ]; then
chk "env injected"                     jq -e '.shell_environment_policy.set.FIXTURE_FLAG == "1"' "$grok_toml_json"
fi

# config.toml — MCP stdio (Codex와 같은 테이블 모양)
chk "mcp everything command"           jq -e '.mcp_servers.everything.command == "npx"' "$grok_toml_json"
chk "mcp everything arg: -y"           jq -e '.mcp_servers.everything.args | index("-y") != null' "$grok_toml_json"
chk "mcp everything arg: package"      jq -e '.mcp_servers.everything.args | index("@modelcontextprotocol/server-everything") != null' "$grok_toml_json"
chk "mcp everything env"               jq -e '.mcp_servers.everything.env.LOG_LEVEL == "info"' "$grok_toml_json"

# config.toml — MCP remote (시크릿은 원문으로 남지 않고 placeholder로 치환)
chk "mcp secretsvc url"                jq -e '.mcp_servers.secretsvc.url == "https://example.com/mcp"' "$grok_toml_json"
chk "mcp secretsvc header redacted"    jq -e '.mcp_servers.secretsvc.http_headers."X-API-Key" == "<REDACTED-REENTER>"' "$grok_toml_json"

# 권한 — Grok 규칙 문자열은 Claude 와 같은 문법이므로 무변환으로 들어와야 한다.
chk "allow: git status"                jq -e '.permission.allow | index("Bash(git status:*)") != null' "$grok_toml_json"
chk "allow: npm run build"             jq -e '.permission.allow | index("Bash(npm run build:*)") != null' "$grok_toml_json"
chk "allow: npm run test"              jq -e '.permission.allow | index("Bash(npm run test:*)") != null' "$grok_toml_json"
if [ "$src_has_ask_tier" = 1 ]; then
chk "ask: git push"                    jq -e '.permission.ask | index("Bash(git push:*)") != null' "$grok_toml_json"
fi
chk "deny: rm"                         jq -e '.permission.deny | index("Bash(rm:*)") != null' "$grok_toml_json"
chk_not "git status not also denied"   jq -e '.permission.deny | index("Bash(git status:*)") != null' "$grok_toml_json"
chk_not "git push not also allowed"    jq -e '.permission.allow | index("Bash(git push:*)") != null' "$grok_toml_json"

# 승인 정책 — 근사 매핑은 제안일 뿐이므로 config.toml 에 자동 반영 금지
chk_not "permission_mode not auto-applied" jq -e '.ui.permission_mode' "$grok_toml_json"
chk_not "sandbox profile not auto-applied" jq -e '.sandbox.profile' "$grok_toml_json"

# 훅 — 최상위 구조 + 이벤트/매처/페이로드. Claude 와 같은 모양이라 무변환이어야 한다.
chk "hooks file exists"                sh -c 'ls "$0"/hooks/*.json >/dev/null 2>&1' "$TARGET"
chk "hooks file valid JSON"            jq -e 'length > 0' "$grok_hooks_all"
chk "hooks top-level shape"            jq -e 'map(select(keys == ["hooks"])) | length > 0' "$grok_hooks_all"
chk "hook matcher preserved"           jq -e '[.[].hooks.PreToolUse[]? | select(.matcher == "Edit|Write")] | length >= 1' "$grok_hooks_all"
chk "hook body paired with matcher"    jq -e '[.[].hooks.PreToolUse[]? | select(.matcher == "Edit|Write") | .hooks[] | select(.command == "echo pre-edit-check" and .timeout == 10)] | length >= 1' "$grok_hooks_all"
if [ "$src_has_notification_hook" = 1 ]; then
# Grok 은 Notification 이벤트를 지원한다(15종에 포함) — Codex 와 달리 드롭하면 안 된다.
chk "notification hook migrated"       jq -e '[.[].hooks.Notification[]?.hooks[]? | select(.command == "echo notify")] | length >= 1' "$grok_hooks_all"
fi
# Grok 15종 밖의 이벤트는 드롭돼야 한다.
chk_not "ConfigChange dropped"         grep -rqF "ConfigChange" "$TARGET/hooks"

# 스킬 (agent-skills 표준 — 그대로 복사)
chk "skill copied"                     test -f "$TARGET/skills/hello/SKILL.md"
chk "skill content identical"          grep -qF "Say hello and summarize" "$TARGET/skills/hello/SKILL.md"
chk "skill supporting file copied"     test -f "$TARGET/skills/hello/reference/tone.md"
chk "skill supporting file content"    grep -qF "Keep the greeting under two sentences." "$TARGET/skills/hello/reference/tone.md"

# 커맨드 — Grok 에는 커맨드 표면이 없다. 소스 커맨드는 스킬로 변환돼야 한다.
if [ "$src_has_commands" = 1 ]; then
chk "command converted to skill"       test -f "$TARGET/skills/greet/SKILL.md"
chk "converted skill keeps ARGUMENTS"  grep -qF '$ARGUMENTS' "$TARGET/skills/greet/SKILL.md"
chk "converted skill body carried"     grep -qF "warmly and mention today" "$TARGET/skills/greet/SKILL.md"
chk_not "no commands dir created"      test -d "$TARGET/commands"
chk_not "no prompts dir created"       test -d "$TARGET/prompts"
fi

# 서브에이전트 (md + camelCase frontmatter)
chk "agent written as md"              test -f "$TARGET/agents/reviewer.md"
chk "agent frontmatter name"           grep -q "^name: reviewer" "$TARGET/agents/reviewer.md"
chk "agent description carried"        grep -qF "Reviews diffs for style violations" "$TARGET/agents/reviewer.md"
chk "agent body carried"               grep -qF "strict code reviewer" "$TARGET/agents/reviewer.md"

# 백업 (존재 + 원본 내용) — security.md "쓰기 안전 규칙", 파일명은 Grok 전용
grok_backup_agents="$(find_run_artifact backup/AGENTS.md)"
grok_backup_config="$(find_run_artifact backup/config.toml)"
: "${grok_backup_agents:=$TARGET/.migrate/__missing__/backup/AGENTS.md}"
: "${grok_backup_config:=$TARGET/.migrate/__missing__/backup/config.toml}"
grok_toml_to_json "$grok_backup_config" > "$grok_backup_config_json" || printf '{}' > "$grok_backup_config_json"

chk "backup of pre-existing AGENTS.md"   test -f "$grok_backup_agents"
chk "backup AGENTS.md is the original"   grep -qF "Keep me." "$grok_backup_agents"
chk "backup of pre-existing config.toml" test -f "$grok_backup_config"
chk "backup config.toml is the original" jq -e '.model == "grok-5-code"' "$grok_backup_config_json"
