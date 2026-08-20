#!/usr/bin/env bash
# set -e 는 의도적으로 쓰지 않는다 — 개별 체크가 실패해도 전부 끝까지 돌려 한 번에 진단한다.
set -uo pipefail
TARGET="${1:?usage: verify-migration.sh <target-root>}"
fail=0

chk() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then echo "PASS: $d"; else echo "FAIL: $d"; fail=1; fi; }
chk_not() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then echo "FAIL: $d"; fail=1; else echo "PASS: $d"; fi; }

if [ ! -d "$TARGET" ]; then
  echo "ERROR: target root not found: $TARGET"
  exit 1
fi

mig_dir="$(ls -d "$TARGET/.migrate/"*/ 2>/dev/null | sort | tail -1)"
if [ -z "$mig_dir" ]; then
  echo "ERROR: no .migrate/<run-id>/ directory under $TARGET — every run-output check below fails for this one reason"
  mig_dir="$TARGET/.migrate/__missing__/"
fi

mcp_json="$(mktemp)"
trap 'rm -f "$mcp_json"' EXIT
python3 -c "
import json, shlex, sys, pathlib
try:
    text = pathlib.Path(sys.argv[1]).read_text()
except OSError:
    print(\"[]\")
    raise SystemExit
text = text.replace(\"\\\\\\n\", \" \")
out = []
for raw in text.splitlines():
    lex = shlex.shlex(raw, posix=True)
    lex.whitespace_split = True
    lex.commenters = \"#\"
    try:
        toks = list(lex)
    except ValueError:
        toks = []
    if toks:
        out.append(toks)
print(json.dumps(out))
" "${mig_dir}mcp-commands.sh" > "$mcp_json" 2>/dev/null || printf '[]' > "$mcp_json"

# 전역 규칙 (기존 보존 + 이관 + import 유지 + override 프리시던스)
chk "CLAUDE.md exists"                 test -f "$TARGET/CLAUDE.md"
chk "CLAUDE.md keeps existing content" grep -qF "Keep me." "$TARGET/CLAUDE.md"
chk "CLAUDE.md migrated rule 1"        grep -qF "Answer in Korean." "$TARGET/CLAUDE.md"
chk "CLAUDE.md migrated rule 2"        grep -qF "Never commit secrets." "$TARGET/CLAUDE.md"
chk "CLAUDE.md preserves import line"  grep -qF "@~/.agent-rules-fixture.md" "$TARGET/CLAUDE.md"
chk_not "AGENTS.override precedence"   grep -rqF "OVERRIDDEN-DECOY" "$TARGET"

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

# 리포트
chk "report exists"                    test -f "${mig_dir}REPORT.md"
chk "report: keybindings non-migratable" grep -qi "keybinding" "${mig_dir}REPORT.md"
chk "report: source model noted"       grep -qF "gpt-5.6-sol" "${mig_dir}REPORT.md"
chk "report: disabled server noted"    grep -qF "disabled_one" "${mig_dir}REPORT.md"
chk "report: secret re-entry listed"   grep -qF "X-API-Key" "${mig_dir}REPORT.md"
chk "report: approval policy suggested" grep -qE "approval_policy|sandbox_mode|defaultMode" "${mig_dir}REPORT.md"

# MCP 등록 명령 (셸 토큰 파싱 기반 — 주석·부분문자열·줄바꿈에 영향받지 않음)
chk "mcp commands generated"           test -f "${mig_dir}mcp-commands.sh"
chk "mcp commands parse as shell"      jq -e 'length >= 2' "$mcp_json"
chk "mcp add: everything registered"   jq -e 'any(.[]; .[0]=="claude" and .[1]=="mcp" and .[2]=="add" and any(.[]; .=="everything"))' "$mcp_json"
chk "mcp add: everything env"          jq -e 'any(.[]; any(.[]; .=="everything") and (index("--env") as $i | $i != null and .[$i+1]=="LOG_LEVEL=info"))' "$mcp_json"
chk "mcp add: everything separator"    jq -e 'any(.[]; any(.[]; .=="everything") and (index("--") as $i | $i != null and .[$i+1]=="npx"))' "$mcp_json"
chk "mcp add: everything package arg"  jq -e 'any(.[]; any(.[]; .=="everything") and any(.[]; .=="@modelcontextprotocol/server-everything"))' "$mcp_json"
chk "mcp add: secretsvc registered"    jq -e 'any(.[]; .[0]=="claude" and .[1]=="mcp" and .[2]=="add" and any(.[]; .=="secretsvc"))' "$mcp_json"
chk "mcp add: secretsvc http"          jq -e 'any(.[]; any(.[]; .=="secretsvc") and (index("--transport") as $i | $i != null and .[$i+1]=="http"))' "$mcp_json"
chk "mcp add: secretsvc url"           jq -e 'any(.[]; any(.[]; .=="secretsvc") and any(.[]; .=="https://example.com/mcp"))' "$mcp_json"
chk_not "disabled server not added"    jq -e 'any(.[]; any(.[]; .=="disabled_one"))' "$mcp_json"

# 백업 (존재 + 원본 내용)
chk "backup of pre-existing CLAUDE.md" test -f "${mig_dir}backup/CLAUDE.md"
chk "backup CLAUDE.md is the original" grep -qF "Keep me." "${mig_dir}backup/CLAUDE.md"
chk "backup of pre-existing settings"  test -f "${mig_dir}backup/settings.json"
chk "backup settings is the original"  jq -e '.model == "claude-fable-5"' "${mig_dir}backup/settings.json"

# 원장 (존재 + 유효 + sha256 기록)
chk "ledger exists"                    test -f "$TARGET/.migrate/ledger.json"
chk "ledger is valid JSON"             jq -e . "$TARGET/.migrate/ledger.json"
chk "ledger records source hashes"     jq -e '[..|strings] | map(select(test("^[0-9a-f]{64}$"))) | unique | length >= 5' "$TARGET/.migrate/ledger.json"

# 시크릿 불가침
chk_not "no MCP secret leaked"         grep -rqF "FAKE-SECRET-123" "$TARGET"
chk_not "auth.json never copied"       grep -rqF "AUTH-FAKE-SECRET" "$TARGET"

exit $fail
