# target-codex.sh — Codex CLI 타겟 전용 체크.
# _common.sh 가 내보낸 TARGET, mig_dir, is_noop_rerun, find_run_artifact,
# script_dir, chk/chk_not 을 그대로 사용한다.
#
# TOML은 jq로 못 읽으므로 python3 tomllib로 JSON 변환 후 jq에 넘긴다.
# _common.sh는 EXIT trap을 쓰지 않는 것을 확인했지만, 나중에 바뀌거나 이
# 파일이 다른 곳에서 재사용될 경우를 대비해 clobber 대신 체이닝한다.
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
  python3 -c "
import sys, tomllib, json, pathlib
try:
    print(json.dumps(tomllib.loads(pathlib.Path(sys.argv[1]).read_text())))
except Exception:
    print('{}')
" "$1" 2>/dev/null
}

codex_toml_json="$(mktemp)"
codex_reviewer_toml_json="$(mktemp)"
codex_backup_config_json="$(mktemp)"
codex_rules_all="$(mktemp)"
codex_add_exit_trap "rm -f '$codex_toml_json' '$codex_reviewer_toml_json' '$codex_backup_config_json' '$codex_rules_all'"

codex_toml_to_json "$TARGET/config.toml" > "$codex_toml_json" || printf '{}' > "$codex_toml_json"
codex_toml_to_json "$TARGET/agents/reviewer.toml" > "$codex_reviewer_toml_json" || printf '{}' > "$codex_reviewer_toml_json"
cat "$TARGET"/rules/*.rules > "$codex_rules_all" 2>/dev/null || true

# 전역 규칙 (기존 보존 + 이관 + import 유지) — Claude CLAUDE.md와 동일 계약
chk "AGENTS.md exists"                 test -f "$TARGET/AGENTS.md"
chk "AGENTS.md keeps existing content" grep -qF "Keep me." "$TARGET/AGENTS.md"
chk "AGENTS.md migrated rule 1"        grep -qF "Answer in Korean." "$TARGET/AGENTS.md"
chk "AGENTS.md migrated rule 2"        grep -qF "Never commit secrets." "$TARGET/AGENTS.md"
chk "AGENTS.md preserves import line"  grep -qF "@~/.agent-rules-fixture.md" "$TARGET/AGENTS.md"

# config.toml — 파싱 가능성 + 기존 최상위 값 보존
chk "config.toml parses as TOML"       python3 -c "import tomllib, pathlib, sys; tomllib.loads(pathlib.Path(sys.argv[1]).read_text())" "$TARGET/config.toml"
chk "existing model preserved"         jq -e '.model == "gpt-5.6-sol"' "$codex_toml_json"
chk "existing env key preserved"       jq -e '.shell_environment_policy.set.EXISTING_KEY == "keep"' "$codex_toml_json"

# config.toml — env 주입 ([shell_environment_policy.set] <- Claude env 블록)
chk "env injected"                     jq -e '.shell_environment_policy.set.FIXTURE_FLAG == "1"' "$codex_toml_json"

# config.toml — MCP stdio
chk "mcp everything command"           jq -e '.mcp_servers.everything.command == "npx"' "$codex_toml_json"
chk "mcp everything arg: -y"           jq -e '.mcp_servers.everything.args | index("-y") != null' "$codex_toml_json"
chk "mcp everything arg: package"      jq -e '.mcp_servers.everything.args | index("@modelcontextprotocol/server-everything") != null' "$codex_toml_json"
chk "mcp everything env"               jq -e '.mcp_servers.everything.env.LOG_LEVEL == "info"' "$codex_toml_json"

# config.toml — MCP http (시크릿은 원문으로 남지 않고 placeholder로 치환)
chk "mcp secretsvc url"                jq -e '.mcp_servers.secretsvc.url == "https://example.com/mcp"' "$codex_toml_json"
chk "mcp secretsvc header redacted"    jq -e '.mcp_servers.secretsvc.http_headers."X-API-Key" == "<REDACTED-REENTER>"' "$codex_toml_json"

# hooks.json — 최상위 구조 + 매처 변환 + 이벤트별 페이로드
chk "hooks.json valid JSON"            jq -e . "$TARGET/hooks.json"
chk "hooks.json top-level shape"       jq -e 'keys == ["hooks"]' "$TARGET/hooks.json"
chk "hook matcher converted to apply_patch" jq -e '.hooks.PreToolUse | map(select(.matcher == "apply_patch")) | length >= 1' "$TARGET/hooks.json"
chk "hook body paired with matcher"    jq -e '.hooks.PreToolUse | map(select(.matcher == "apply_patch")) | .[0].hooks | map(select(.command == "echo pre-edit-check" and .timeout == 10)) | length >= 1' "$TARGET/hooks.json"
chk "notification hook migrated"       jq -e '[.hooks.Notification[].hooks[].command] | index("echo notify") != null' "$TARGET/hooks.json"

# hooks.json — Claude 전용 이벤트(ConfigChange)는 조용히 드롭, 어디에도 남으면 안 됨
chk_not "ConfigChange dropped from hooks.json" grep -qF "ConfigChange" "$TARGET/hooks.json"

# 권한 -> rules/*.rules (prefix_rule DSL, decision 매핑: allow/prompt/forbidden)
chk "rules: git status allow"    grep -Eq 'prefix_rule\([[:space:]]*pattern[[:space:]]*=[[:space:]]*\[[[:space:]]*"git"[[:space:]]*,[[:space:]]*"status"[[:space:]]*\][[:space:]]*,[[:space:]]*decision[[:space:]]*=[[:space:]]*"allow"[[:space:]]*\)' "$codex_rules_all"
chk "rules: git push prompt"     grep -Eq 'prefix_rule\([[:space:]]*pattern[[:space:]]*=[[:space:]]*\[[[:space:]]*"git"[[:space:]]*,[[:space:]]*"push"[[:space:]]*\][[:space:]]*,[[:space:]]*decision[[:space:]]*=[[:space:]]*"prompt"[[:space:]]*\)' "$codex_rules_all"
chk "rules: rm forbidden"        grep -Eq 'prefix_rule\([[:space:]]*pattern[[:space:]]*=[[:space:]]*\[[[:space:]]*"rm"[[:space:]]*\][[:space:]]*,[[:space:]]*decision[[:space:]]*=[[:space:]]*"forbidden"[[:space:]]*\)' "$codex_rules_all"
chk "rules: npm run build allow" grep -Eq 'prefix_rule\([[:space:]]*pattern[[:space:]]*=[[:space:]]*\[[[:space:]]*"npm"[[:space:]]*,[[:space:]]*"run"[[:space:]]*,[[:space:]]*"build"[[:space:]]*\][[:space:]]*,[[:space:]]*decision[[:space:]]*=[[:space:]]*"allow"[[:space:]]*\)' "$codex_rules_all"
chk "rules: npm run test allow"  grep -Eq 'prefix_rule\([[:space:]]*pattern[[:space:]]*=[[:space:]]*\[[[:space:]]*"npm"[[:space:]]*,[[:space:]]*"run"[[:space:]]*,[[:space:]]*"test"[[:space:]]*\][[:space:]]*,[[:space:]]*decision[[:space:]]*=[[:space:]]*"allow"[[:space:]]*\)' "$codex_rules_all"

# 승인 정책 — 문서상 근사 매핑은 "제안"일 뿐이므로 config.toml에 자동 반영 금지
chk_not "approval_policy not auto-applied" jq -e '.approval_policy' "$codex_toml_json"
chk_not "sandbox_mode not auto-applied"    jq -e '.sandbox_mode' "$codex_toml_json"

# 스킬 (Claude와 동일 agent-skills 표준 — 그대로 복사)
chk "skill copied"                     test -f "$TARGET/skills/hello/SKILL.md"
chk "skill content identical"          grep -qF "Say hello and summarize" "$TARGET/skills/hello/SKILL.md"
chk "skill supporting file copied"     test -f "$TARGET/skills/hello/reference/tone.md"
chk "skill supporting file content"    grep -qF "Keep the greeting under two sentences." "$TARGET/skills/hello/reference/tone.md"

# 서브에이전트 (md -> TOML)
chk "agent converted to toml"          test -f "$TARGET/agents/reviewer.toml"
chk "agent toml parses"                python3 -c "import tomllib, pathlib, sys; tomllib.loads(pathlib.Path(sys.argv[1]).read_text())" "$TARGET/agents/reviewer.toml"
chk "agent description carried"        jq -e '(.description // "") | contains("Reviews diffs for style violations")' "$codex_reviewer_toml_json"
chk "agent developer_instructions carried" jq -e '(.developer_instructions // "") | contains("strict code reviewer")' "$codex_reviewer_toml_json"

# 커맨드 (md -> prompts/*.md)
# 문서 갭: core/tools/codex.md의 "쓰기 규칙 (Codex가 타겟일 때)" 절은 이 방향(커맨드 ->
# prompts)을 명시하지 않는다 — 스킬·서브에이전트 방향도 마찬가지로 이 절에서 빠져 있다.
# "읽기 인벤토리"/"변환 규칙 (Codex -> 다른 도구)" 절이 prompts/*.md 를 Codex의 커맨드
# 표면으로, TOML<->md 서브에이전트 변환을 대칭 규칙으로 명시하므로 그 형식을 그대로
# 역방향 적용한다고 가정하고 체크를 작성한다. 문서 자체는 건드리지 않는다 — REPORT 참고.
chk "prompt converted from command"    test -f "$TARGET/prompts/greet.md"
chk "prompt keeps ARGUMENTS token"     grep -qF '$ARGUMENTS' "$TARGET/prompts/greet.md"
chk "prompt body carried over"         grep -qF "warmly and mention today" "$TARGET/prompts/greet.md"

# 백업 (존재 + 원본 내용) — security.md "쓰기 안전 규칙"(모든 타겟 공통) 적용, 파일명은 Codex 전용
codex_backup_agents="$(find_run_artifact backup/AGENTS.md)"
codex_backup_config="$(find_run_artifact backup/config.toml)"
: "${codex_backup_agents:=$TARGET/.migrate/__missing__/backup/AGENTS.md}"
: "${codex_backup_config:=$TARGET/.migrate/__missing__/backup/config.toml}"
codex_toml_to_json "$codex_backup_config" > "$codex_backup_config_json" || printf '{}' > "$codex_backup_config_json"

chk "backup of pre-existing AGENTS.md"   test -f "$codex_backup_agents"
chk "backup AGENTS.md is the original"   grep -qF "Keep me." "$codex_backup_agents"
chk "backup of pre-existing config.toml" test -f "$codex_backup_config"
chk "backup config.toml is the original" jq -e '.model == "gpt-5.6-sol"' "$codex_backup_config_json"
