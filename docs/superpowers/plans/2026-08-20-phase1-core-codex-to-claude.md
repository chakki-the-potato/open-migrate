# Phase 1: 코어 + Codex→Claude 마이그레이션 스킬 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `/migrate codex` 한 번으로 Codex CLI 설정을 Claude Code로 이관하는 AI-driven 스킬의 코어(공유 지식 문서 + 절차)와 Claude 진입점을 완성하고, 픽스처 기반 E2E 검증을 통과시킨다.

**Architecture:** 파서 코드 없음. 도구별 지식 문서(`core/tools/*.md`)와 공통 절차(`core/procedure.md`)를 진입점 스킬(`adapters/claude/SKILL.md`)이 로드하고, 실행 중인 AI가 변환 엔진이 된다. 검증은 합성 픽스처(`test/fixtures/codex-home/`)를 격리 타겟에 이관한 뒤 결정적 셸 스크립트(`scripts/verify-migration.sh`)로 산출물을 검사한다.

**Tech Stack:** Markdown(스킬·지식 문서), Bash(설치·검증 스크립트), jq(검증), git.

**참조 문서:** 스펙 `docs/superpowers/specs/2026-08-19-ai-settings-migration-skill-design.md`, 리서치 전문 `docs/research/*.json` (매핑 근거가 전부 들어 있음 — 지식 문서 작성 시 반드시 대조).

---

## File Structure

```
core/
  procedure.md          5단계 절차(Scan→Plan→Confirm→Apply→Report). 방향 무관 공통. [Task 6]
  security.md           시크릿 탐지·마스킹·접근금지 정책. 모든 단계에 우선 적용. [Task 3]
  tools/
    codex.md            Codex 표면: 읽기(소스) + 쓰기(타겟) 양면 + 변환 규칙. [Task 4]
    claude.md           Claude 표면: 쓰기 규칙(직접 쓰기 vs CLI) + 읽기. [Task 5]
    _template.md        새 도구 문서 템플릿. [Task 7]
adapters/
  claude/SKILL.md       Claude Code 진입점. 인자 파싱·자동 감지·지식 로드·절차 위임만. [Task 8]
install.sh              adapters/<dest>/SKILL.md + core/ → 대상 스킬 디렉토리 조립 복사. [Task 8]
scripts/
  verify-migration.sh   E2E 검증기. 타겟 디렉토리를 결정적으로 검사. [Task 2]
test/
  fixtures/codex-home/  합성 Codex 홈(가짜 시크릿 포함). [Task 1]
  tmp/                  E2E 실행 산출물(gitignore). [Task 1]
```

책임 경계: SKILL.md는 오케스트레이션만(50줄 내외), 변환 지식은 tools/*.md, 절차·리포트 형식은 procedure.md, 보안 정책은 security.md. 문서 간 중복 금지 — 매핑표는 tools/에만, 단계 정의는 procedure.md에만 존재한다.

---

### Task 1: 저장소 스캐폴딩 + Codex 픽스처

**Files:**
- Create: `.gitignore`
- Create: `test/fixtures/codex-home/config.toml`
- Create: `test/fixtures/codex-home/AGENTS.md` (디코이 — 이관되면 안 됨)
- Create: `test/fixtures/codex-home/AGENTS.override.md` (실제 이관 대상)
- Create: `test/fixtures/codex-home/hooks.json`
- Create: `test/fixtures/codex-home/rules/default.rules`
- Create: `test/fixtures/codex-home/skills/hello/SKILL.md`
- Create: `test/fixtures/codex-home/skills/hello/reference/tone.md`
- Create: `test/fixtures/codex-home/prompts/greet.md`
- Create: `test/fixtures/codex-home/agents/reviewer.toml`
- Create: `test/fixtures/codex-home/keybindings.json`
- Create: `test/fixtures/codex-home/auth.json`

픽스처는 실제 Codex 포맷(docs/research 검증분)을 따르되 전부 합성 값이다. 가짜 시크릿 2개(`sk-test-FAKE-SECRET-123`, `AUTH-FAKE-SECRET`)를 심어 마스킹·불가침을 검증한다.

**실행 노트:** 이 저장소의 파일 생성은 반드시 파일 쓰기 도구(Write)로 한다. Bash heredoc으로 시크릿류 문자열이 포함된 내용을 쓰면 이 머신의 env-file-guard 훅이 명령을 차단한다(실측 확인됨).

- [ ] **Step 1: .gitignore 작성**

```gitignore
test/tmp/
.playwright-mcp/
```

- [ ] **Step 2: config.toml 작성**

`test/fixtures/codex-home/config.toml`:

```toml
model = "gpt-5.6-sol"
approval_policy = "never"
sandbox_mode = "danger-full-access"

[shell_environment_policy]
inherit = "core"

[shell_environment_policy.set]
FIXTURE_FLAG = "1"

[mcp_servers.everything]
command = "npx"
args = ["-y", "@modelcontextprotocol/server-everything"]

[mcp_servers.everything.env]
LOG_LEVEL = "info"

[mcp_servers.secretsvc]
url = "https://example.com/mcp"

[mcp_servers.secretsvc.http_headers]
X-API-Key = "sk-test-FAKE-SECRET-123"

[mcp_servers.disabled_one]
command = "npx"
args = ["disabled-server"]
enabled = false

[projects."/tmp/some-project"]
trust_level = "trusted"
```

- [ ] **Step 3: AGENTS.md (디코이) + AGENTS.override.md (실제 대상) 작성**

Codex는 `AGENTS.override.md` 가 있으면 그것을 읽고 `AGENTS.md` 는 무시한다. 프리시던스를 무시하는 마이그레이션을 잡기 위해 디코이를 둔다.

`test/fixtures/codex-home/AGENTS.md`:

```markdown
# Global Rules (overridden)

- OVERRIDDEN-DECOY must never reach the target.
```

`test/fixtures/codex-home/AGENTS.override.md`:

```markdown
# Global Rules

@~/.agent-rules-fixture.md

- Answer in Korean.
- Never commit secrets.
```

- [ ] **Step 4: hooks.json 작성**

`test/fixtures/codex-home/hooks.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "apply_patch",
        "hooks": [
          { "type": "command", "command": "echo pre-edit-check", "timeout": 10 }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "",
        "hooks": [{ "type": "command", "command": "echo notify" }]
      }
    ]
  }
}
```

(Notification은 Codex 비공식 이벤트지만 Claude에는 존재 — Codex→Claude 방향에서는 유효 이벤트로 이관되어야 한다.)

- [ ] **Step 5: rules/default.rules 작성**

`test/fixtures/codex-home/rules/default.rules`:

```python
prefix_rule(pattern=["git", "status"], decision="allow")
prefix_rule(pattern=["git", "push"], decision="prompt")
prefix_rule(pattern=["npm", "run", ["build", "test"]], decision="allow")
prefix_rule(pattern=["rm"], decision="forbidden")
```

- [ ] **Step 6: skills/hello/SKILL.md + prompts/greet.md 작성**

`test/fixtures/codex-home/skills/hello/SKILL.md`:

```markdown
---
name: hello
description: Say hello with project context
---

Say hello and summarize the current project in one sentence.
```

`test/fixtures/codex-home/skills/hello/reference/tone.md` (지원 파일 — 디렉토리 전체 복사 검증용):

```markdown
Keep the greeting under two sentences.
```

`test/fixtures/codex-home/prompts/greet.md` (deprecated 커스텀 프롬프트 — 커맨드 변환 검증용):

```markdown
Greet $ARGUMENTS warmly and mention today's weekday.
```

- [ ] **Step 7: agents/reviewer.toml 작성**

`test/fixtures/codex-home/agents/reviewer.toml`:

```toml
description = "Reviews diffs for style violations"
developer_instructions = '''
You are a strict code reviewer. Report style violations only.
'''
```

- [ ] **Step 8: keybindings.json / auth.json 작성**

`test/fixtures/codex-home/keybindings.json`:

```json
[{ "command": "realtimeVoice", "key": "Alt+V" }]
```

`test/fixtures/codex-home/auth.json`:

```json
{ "note": "AUTH-FAKE-SECRET — this file must never be read or copied by the migration" }
```

- [ ] **Step 9: Commit**

```bash
git add .gitignore test/
git commit -m "test: add synthetic codex-home fixture with planted fake secrets"
```

---

### Task 2: 검증 스크립트 (실패하는 테스트 먼저)

**Files:**
- Create: `scripts/verify-migration.sh`

- [ ] **Step 1: verify-migration.sh 작성**

```bash
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
```

- [ ] **Step 2: 실행 권한 부여 후 실패 확인**

```bash
chmod +x scripts/verify-migration.sh
mkdir -p test/tmp/claude-target
./scripts/verify-migration.sh test/tmp/claude-target
```

Expected: 다수 FAIL 출력, exit code 1 (아직 이관 산출물이 없으므로).

- [ ] **Step 3: Commit**

```bash
git add scripts/verify-migration.sh
git commit -m "test: add deterministic E2E verifier for migration output"
```

---

### Task 3: core/security.md

**Files:**
- Create: `core/security.md`

- [ ] **Step 1: security.md 작성**

전체 내용:

```markdown
# Security Policy (모든 단계에 우선 적용)

## 접근 금지 파일 (읽기·복사 절대 금지)

- 인증: `auth.json`, `credentials*`, `*.pem`, `*.key`, `*.p12`, `*.pfx`, `~/.aws/credentials`
- env: `.env`, `.env.*` (`.env.example`/`.env.sample`/`.env.template` 제외)
- SSH: `id_rsa*`, `id_ed25519*`, `id_ecdsa*`, `~/.ssh/*`
- 존재 여부 확인(파일명·크기)만 허용. 내용을 읽었다면 그 시점에 작업을 중단하고 사용자에게 보고한다.

## 설정 안의 시크릿 값 탐지

다음에 해당하는 값은 시크릿으로 간주한다.
- 키 이름이 `*key*`, `*token*`, `*secret*`, `*password*`, `Authorization`, `X-API-Key` 등 인증 계열인 값
- `sk-`, `ghp_`, `xoxb-`, `AKIA` 등 알려진 키 접두사로 시작하는 값
- MCP 서버 정의의 `env`/`headers`/`http_headers` 안의 20자 이상 고엔트로피 문자열

## 시크릿 처리 규칙

1. 산출 파일·명령·리포트·채팅 어디에도 시크릿 원문을 쓰지 않는다.
2. 산출물에는 플레이스홀더 `<REDACTED-REENTER>` 를 쓴다.
3. 리포트의 "수동 조치" 섹션에 키 이름과 위치(파일·서버명)만 기록해 사용자가 직접 재입력하게 한다.
4. 화면 표시가 꼭 필요하면 앞 4자 + `…` 형태로만 마스킹 표시한다.

## 쓰기 안전 규칙

1. 기존 타겟 파일을 수정하기 전 반드시 `.migrate/<run-id>/backup/` 에 원본을 복사한다.
2. 덮어쓰기 금지 — 항상 병합. 충돌(같은 키에 다른 값)은 자동 결정하지 않고 사용자에게 묻는다.
3. Confirm 단계에서 사용자 승인을 받기 전에는 어떤 파일도 쓰지 않는다.
```

- [ ] **Step 2: Commit**

```bash
git add core/security.md
git commit -m "feat: add security policy for secret handling and write safety"
```

---

### Task 4: core/tools/codex.md

**Files:**
- Create: `core/tools/codex.md`

내용의 사실 근거는 `docs/research/2026-08-19-codex-claude-priorart.json`, `docs/research/2026-08-20-gap-resolution.json`. 작성 시 대조할 것.

- [ ] **Step 1: codex.md 작성**

전체 내용:

````markdown
# Codex CLI (OpenAI)

홈: `$CODEX_HOME` (기본 `~/.codex`). 이 문서는 소스로 읽을 때와 타겟으로 쓸 때 모두 사용한다.

## 감지

`~/.codex/config.toml` 또는 `~/.codex/AGENTS.md` 존재 시 설치된 것으로 판단.

## 설정 인벤토리 (읽기)

| 카테고리 | 위치 | 포맷 |
|---|---|---|
| 전역 규칙 | `AGENTS.md` (`AGENTS.override.md` 우선) | markdown, `@경로` import 지원 |
| MCP | `config.toml` `[mcp_servers.<name>]` | TOML. stdio: command/args/env. HTTP는 `url` 키 존재로 판별 (+선택: http_headers/bearer_token_env_var). `enabled=false`는 비활성 |
| 스킬 | `skills/<name>/SKILL.md` | agent-skills 표준. 그대로 복사 가능 |
| 커스텀 프롬프트 | `prompts/*.md` (deprecated) | 평문 markdown, `$1`-`$9`/`$ARGUMENTS` 치환 |
| 훅 | `hooks.json` 또는 `config.toml` `[[hooks.Event]]` | Claude와 동일 JSON 구조 |
| 권한 규칙 | `rules/*.rules` | Starlark `prefix_rule(pattern=[...], decision=...)` |
| 서브에이전트 | `agents/*.toml` | TOML: `description`, `developer_instructions` |
| env 주입 | `config.toml` `[shell_environment_policy]` (`set` 테이블) | TOML |
| 승인 정책 | `config.toml` `approval_policy`, `sandbox_mode` | 근사 매핑만 |
| 모델/개성 | `config.toml` `model`, `personality` 등 최상위 키 | 이관 안 함 — 리포트 안내만 |
| 프로젝트 신뢰 | `config.toml` `[projects."<path>"]` | 이관 불가 — 안내만 |
| 키바인딩 | `keybindings.json` | 명령 체계 상이 — 이관 불가, 안내만 |
| 읽지 말 것 | `auth.json`, `sessions/`, `history.jsonl`, `*.sqlite`, `.codex-global-state.json` | security.md 적용 |

## 변환 규칙 (Codex → 다른 도구)

### 훅
- 공식 이벤트 11개: SessionStart, SessionEnd, SubagentStart, SubagentStop, PreToolUse, PermissionRequest, PostToolUse, PreCompact, PostCompact, UserPromptSubmit, Stop. Claude와 전부 동명 — 이벤트명 무변환.
- **공식 11개 밖의 이벤트명이 hooks.json에 있으면** (Codex는 조용히 무시하는 죽은 설정): 타겟 도구 문서의 유효 이벤트 목록을 확인해 동명 이벤트가 존재하면 무변환 이관하고, 없으면 드롭 후 리포트에 기록한다. 예: `Notification`은 Codex 비공식이지만 Claude에 존재 — 이관.
- 도구명 매처: `apply_patch` → Claude `Edit|Write`. `shell`/`local_shell`/`exec_command` 변형 → `Bash`. `mcp__server__tool`은 동일.
- timeout 단위는 초로 동일.

### 커스텀 프롬프트 (prompts/*.md → 타겟 커맨드)
- deprecated 표면이지만 존재하면 이관: 파일 내용을 그대로 타겟의 커맨드 파일로 옮긴다 (Claude: `commands/<name>.md`).
- `$1`-`$9`/`$ARGUMENTS` 치환 토큰은 Claude 커맨드와 호환 — 원문 그대로 유지.

### 권한 규칙 (rules DSL)
- decision 매핑: `allow`→allow, `prompt`→ask, `forbidden`→deny.
- `pattern=["git","status"]` → `Bash(git status:*)`.
- 원소가 리스트면 각 조합으로 전개: `["npm","run",["build","test"]]` → `Bash(npm run build:*)` + `Bash(npm run test:*)`.

### 서브에이전트 (TOML → md)
`agents/<name>.toml` → `<name>.md`:

```markdown
---
name: <파일명>
description: <description 값>
---

<developer_instructions 값>
```

### MCP (TOML → 타겟 형식)
- stdio: command/args/env 그대로. HTTP: url + headers.
- `http_headers` 값은 security.md 시크릿 탐지 적용.
- `enabled=false` 서버는 이관하지 않고 리포트에 기록.

## 쓰기 규칙 (Codex가 타겟일 때 — Phase 2에서 사용)

- 규칙 → `AGENTS.md`에 병합. MCP → `config.toml` `[mcp_servers.*]` TOML 추가.
- 훅 → `hooks.json`. 최상위 구조는 반드시 `{"hooks": {...}}` — 최상위 키가 틀리면 파일 전체가 무시된다. hooks 객체 안의 미지 이벤트명은 조용히 무시되므로 Claude 전용 이벤트는 경고 후 제거.
- Claude 권한 중 Bash prefix 규칙만 `rules/*.rules`로 변환 가능. 경로·도메인·MCP 규칙은 표현 불가 — 수동 목록으로.
- PostToolUse는 실패 시에도 발화 — Claude `PostToolUseFailure` 훅은 PostToolUse로 병합.
- `[shell_environment_policy.set]` ← Claude `env` 블록.
````

- [ ] **Step 2: Commit**

```bash
git add core/tools/codex.md
git commit -m "feat: add Codex tool knowledge doc (read/write/conversion rules)"
```

---

### Task 5: core/tools/claude.md

**Files:**
- Create: `core/tools/claude.md`

- [ ] **Step 1: claude.md 작성**

전체 내용:

````markdown
# Claude Code (Anthropic)

홈: `~/.claude` (+ `~/.claude.json`). 테스트 모드에서는 사용자가 지정한 타겟 루트를 `~/.claude` 대신 사용한다.

## 감지

`~/.claude/settings.json` 또는 `~/.claude/CLAUDE.md` 존재 시 설치된 것으로 판단.

## 쓰기 규칙 (Claude가 타겟일 때)

| 카테고리 | 쓰기 위치 | 방법 |
|---|---|---|
| 전역 규칙 | `CLAUDE.md` | 파일 끝에 `## Migrated from <source> (<date>)` 섹션으로 병합. `@import` 줄은 원문 유지. 기존 내용 삭제 금지 |
| MCP | `claude mcp add` CLI | **`~/.claude.json` 직접 수정 금지** (공식 권고). stdio: `claude mcp add --scope user [--env KEY=VALUE ...] <name> -- <command> [args...]` — 서버 인자 앞 `--` 구분자 필수(인자가 `-y`처럼 대시로 시작하면 없을 때 오파싱). 예: `claude mcp add --scope user --env LOG_LEVEL=info everything -- npx -y @modelcontextprotocol/server-everything`. HTTP: `claude mcp add --scope user --transport http <name> <url> [--header "K: V"]`. env 값·헤더 값 모두 security.md 시크릿 탐지 대상 — 시크릿은 `<REDACTED-REENTER>` 로 두고 수동 조치 목록에 기재 |
| 스킬 | `skills/<name>/SKILL.md` | 디렉토리째 복사. 동명 스킬 존재 시 건너뛰고 리포트에 기록 |
| 커맨드 | `commands/<name>.md` | 평문 markdown. `$1`-`$9`/`$ARGUMENTS` 치환 지원 — 소스의 치환 토큰 원문 유지 |
| 훅 | `settings.json`의 `hooks` 키 | 구조: `{Event: [{matcher, hooks: [{type:"command", command, timeout}]}]}`. 기존 훅 배열에 append — 동일 command 중복이면 스킵. 유효 이벤트: 소스 도구의 11개 공통 이벤트 전부 + Notification, PermissionDenied, PostToolUseFailure, ConfigChange, WorktreeCreate 등 Claude 확장 이벤트 (동명이면 그대로 수용) |
| 권한 | `settings.json`의 `permissions.allow` / `deny` / `ask` | 배열에 append, 중복 제거. 공식 문서는 세션 내 `/permissions` 사용을 권하지만, 일괄 마이그레이션에서는 백업+jq 검증+실패 시 복원을 전제로 직접 병합한다(의도된 이탈). `defaultMode`는 절대 자동 설정하지 않음 — 근사 매핑표는 제안으로만 리포트에 기재 |
| env | `settings.json`의 `env` 객체 | 키 단위 병합. 기존 키와 값이 다르면 충돌 — 사용자에게 질문 |
| 서브에이전트 | `agents/<name>.md` | frontmatter: name, description. 본문 = 시스템 프롬프트 |

## settings.json 병합 규칙

1. 수정 전 원본을 `.migrate/<run-id>/backup/settings.json` 으로 복사.
2. 깊은 병합(deep merge): 객체는 키 단위 병합, 배열은 append 후 중복 제거, 기존 스칼라 값은 보존.
3. 쓰기 후 `jq -e . settings.json` 으로 JSON 유효성 확인. 실패 시 백업 복원 후 중단·보고.

## MCP 명령 실행 규칙

- 실제 환경(타겟 = 실제 `~/.claude`): `claude mcp add` 를 직접 실행하고 `claude mcp list` 로 확인.
- 테스트 모드(타겟 루트가 실제 홈이 아님): 실행하지 않고 명령 목록을 `.migrate/<run-id>/mcp-commands.sh` 로만 산출.
- 두 경우 모두 감사 기록용으로 `mcp-commands.sh` 는 항상 생성한다.

## 읽기 인벤토리 (Claude가 소스일 때 — Phase 2에서 사용)

| 카테고리 | 위치 |
|---|---|
| 전역 규칙 | `~/.claude/CLAUDE.md` (`@경로` import 체인 포함) |
| MCP | `~/.claude.json` 최상위 `mcpServers` (user scope), `projects["<path>"].mcpServers` (local scope), 프로젝트 `.mcp.json` |
| 스킬 | `~/.claude/skills/<name>/SKILL.md` |
| 훅 | `settings.json` `hooks` (command 타입만 이관 대상 — http/mcp_tool/prompt/agent 타입은 타 도구 미지원, 스킵 후 기록) |
| 권한 | `settings.json`, `settings.local.json` `permissions` |
| 서브에이전트 | `~/.claude/agents/*.md` |
| 읽지 말 것 | `~/.claude.json` 의 나머지 키(앱 상태), `projects/` 세션 데이터, `.credentials.json` |
````

- [ ] **Step 2: Commit**

```bash
git add core/tools/claude.md
git commit -m "feat: add Claude tool knowledge doc (write/merge/read rules)"
```

---

### Task 6: core/procedure.md

**Files:**
- Create: `core/procedure.md`

- [ ] **Step 1: procedure.md 작성**

전체 내용:

````markdown
# Migration Procedure (5단계 — 순서 엄수)

실행 전 제자리 확인: 소스 도구 문서(`core/tools/<source>.md`), 타겟 도구 문서(`core/tools/<target>.md`), `core/security.md` 를 모두 읽었는가. 하나라도 안 읽었으면 지금 읽는다.

run-id는 `YYYYMMDD-HHMMSS` 형식으로 지금 생성한다. 산출 루트는 `<타겟 루트>/.migrate/<run-id>/`.

## 카테고리 체크리스트 (매 실행마다 전부 순회)

1. 전역 규칙  2. MCP 서버  3. 스킬  4. 서브에이전트  5. 훅
6. 권한 규칙  7. env 주입  8. 승인/샌드박스 정책  9. 이관 불가 항목(키바인딩·세션·auth·모델 등)

## Step 1: Scan

- 소스 문서의 인벤토리 표를 따라 각 카테고리의 파일 존재·내용을 조사한다.
- security.md의 접근 금지 파일은 존재만 기록한다.
- 카테고리별로 발견 항목 수를 센다(없으면 0으로 기록 — 침묵 금지).

## Step 2: Plan

카테고리별로 다음 3분류로 나눈 계획표를 만든다.
- **자동**: 무손실 변환 가능 (변환 결과 미리보기 포함)
- **근사**: 의미 손실 있는 변환 (무엇이 손실되는지 명시)
- **불가**: 이관 불가 (사유 + 수동 조치 방법)

시크릿이 탐지된 항목은 계획표에 `<REDACTED-REENTER>` 로 표시한다.

## Step 3: Confirm

- 계획표를 사용자에게 제시하고 승인을 받는다. 카테고리 단위 제외를 허용한다.
- 타겟에 이미 존재해 충돌하는 항목(동명 스킬, 값이 다른 env 키 등)은 여기서 개별 확인한다.
- **승인 전에는 어떤 파일도 쓰지 않는다.** 사용자가 중단하면 계획표만 남기고 종료한다.

## Step 4: Apply

승인된 카테고리만, 다음 순서로 처리한다.

1. `.migrate/<run-id>/backup/` 생성, 수정 대상 기존 파일 전부 백업.
2. 원장 확인: `<타겟 루트>/.migrate/ledger.json` 에서 소스 파일의 sha256이 이미 기록돼 있으면 해당 항목은 건너뛰고 리포트에 "이미 이관됨"으로 기록 (재실행 안전).
3. 타겟 문서의 쓰기 규칙대로 카테고리별 변환·병합 실행.
4. 원장 갱신: `{ "<소스 절대경로>": { "sha256": "...", "run": "<run-id>" } }` 형식으로 항목 추가.

쓰기 실패(JSON 파싱 오류 등) 시: 해당 파일을 백업에서 복원하고, 남은 카테고리를 중단하고, 리포트에 실패 지점을 기록한다.

## Step 5: Report

`.migrate/<run-id>/REPORT.md` 를 작성하고 같은 내용을 사용자에게 요약 출력한다. 형식:

```markdown
# Migration Report: <source> → <target> (<run-id>)

## 이관 완료 (자동)
- <카테고리>: <항목> → <타겟 위치>

## 근사 매핑 (확인 권장)
- <항목>: <무엇이 어떻게 근사되었는지>

## 수동 조치 필요
- <항목> (<소스 파일 경로>): <사용자가 해야 할 일> (시크릿 재입력 항목은 키 이름·위치만)

## 이관하지 않음
- <항목> (<소스 파일 경로>): <사유> (비활성 서버·키바인딩·세션·auth 등)

각 항목에는 소스 파일 경로(예: `keybindings.json`, `config.toml`의 서버명)를 반드시 포함한다.

## 검증
- <실행한 확인 명령과 결과>
```

리포트에는 시크릿 원문을 절대 쓰지 않는다(security.md).

## 승인/샌드박스 정책 근사 매핑표 (참고용 — 자동 적용 금지, 항상 제안만)

| Codex approval_policy + sandbox | Claude defaultMode | Cursor approvalMode | Grok permission_mode |
|---|---|---|---|
| untrusted / read-only | default | allowlist | default(ask) |
| on-request / workspace-write | acceptEdits | allowlist | acceptEdits |
| never / danger-full-access | bypassPermissions | unrestricted | bypassPermissions |
````

- [ ] **Step 2: Commit**

```bash
git add core/procedure.md
git commit -m "feat: add 5-step migration procedure with ledger and report format"
```

---

### Task 7: core/tools/_template.md

**Files:**
- Create: `core/tools/_template.md`

- [ ] **Step 1: _template.md 작성**

```markdown
# <도구 이름> (<제조사>)

홈: `<설정 루트 경로>`. 이 문서는 소스로 읽을 때와 타겟으로 쓸 때 모두 사용한다.

## 감지

<설치 판단 기준 파일/디렉토리>

## 설정 인벤토리 (읽기)

| 카테고리 | 위치 | 포맷 |
|---|---|---|
| 전역 규칙 | | |
| MCP | | |
| 스킬 | | |
| 훅 | | |
| 권한 규칙 | | |
| 서브에이전트 | | |
| env 주입 | | |
| 승인 정책 | | |
| 읽지 말 것 | | security.md 적용 |

## 변환 규칙 (이 도구 → 다른 도구)

<카테고리별: 이벤트명·매처·문법 변환 규칙. 등가물 없는 항목은 "불가 — 수동 안내" 명시>

## 쓰기 규칙 (이 도구가 타겟일 때)

<카테고리별: 파일 직접 쓰기 vs CLI 명령, 병합 규칙, 검증 명령>
```

- [ ] **Step 2: Commit**

```bash
git add core/tools/_template.md
git commit -m "feat: add tool knowledge doc template"
```

---

### Task 8: Claude 진입점 스킬 + install.sh

**Files:**
- Create: `adapters/claude/SKILL.md`
- Create: `install.sh`

- [ ] **Step 1: SKILL.md 작성**

`adapters/claude/SKILL.md`:

```markdown
---
name: migrate
description: Migrate settings from another AI coding tool (Codex, Cursor, Grok) into Claude Code — rules, MCP servers, skills, subagents, hooks, permissions. Use when the user asks to import or migrate settings from another AI tool, or runs /migrate [source].
---

# migrate — AI 설정 마이그레이션 (목적지: Claude Code)

너는 목적지 도구(Claude Code) 안에서 실행 중이다. 소스 도구의 설정을 이 도구로 이관한다.

## 0. 입력 해석

- 소스 = "$ARGUMENTS" 의 첫 단어 (`codex` | `cursor` | `grok`).
- 인자가 없으면 자동 감지: `~/.codex`, `~/.cursor`, `~/.grok` 존재 여부를 확인해 발견된 도구를 제시하고 사용자에게 하나를 고르게 한다 (목적지 자신은 제외).
- 해당 소스의 문서가 `core/tools/` 에 없으면 지원 예정이라고 알리고 중단한다.
- 소스 루트 = 소스 도구 문서의 기본 홈. 사용자가 메시지에서 소스 루트 경로를 명시하면 그 경로를 대신 사용한다.
- 타겟 루트 = 실제 Claude 환경 (`~/.claude` 등, core/tools/claude.md 기준). 사용자가 메시지에서 테스트용 타겟 루트를 명시한 경우에만 그 경로를 사용하고, MCP 등록을 명령 목록 산출 모드로 전환한다.

## 1. 지식 로드 (이 스킬 디렉토리 기준, 전부 필수)

1. `core/security.md` — 최우선 정책
2. `core/procedure.md` — 실행 절차
3. `core/tools/<source>.md` — 소스 읽기·변환 규칙
4. `core/tools/claude.md` — 타겟 쓰기 규칙

## 2. 실행

core/procedure.md 의 Scan → Plan → Confirm → Apply → Report 를 순서대로 수행한다.
Confirm 에서 사용자 승인 전에는 어떤 파일도 쓰지 않는다.
```

- [ ] **Step 2: install.sh 작성**

```bash
#!/usr/bin/env bash
set -euo pipefail

dest="${1:-claude}"
case "$dest" in
  claude) target="$HOME/.claude/skills/migrate" ;;
  *) echo "unsupported destination: $dest (phase 1 supports: claude)" >&2; exit 1 ;;
esac

src_dir="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$target"
cp "$src_dir/adapters/$dest/SKILL.md" "$target/SKILL.md"
rm -rf "$target/core"
cp -R "$src_dir/core" "$target/core"
echo "installed: $target"
```

- [ ] **Step 3: 설치 실행 및 확인**

```bash
chmod +x install.sh
./install.sh claude
ls ~/.claude/skills/migrate/ ~/.claude/skills/migrate/core/tools/
```

Expected: `SKILL.md`, `core/` 가 보이고 `core/tools/` 에 codex.md, claude.md, _template.md 존재.

- [ ] **Step 4: Commit**

```bash
git add adapters/ install.sh
git commit -m "feat: add Claude entry-point skill and installer"
```

---

### Task 9: E2E 픽스처 검증 (통과할 때까지)

**Files:**
- Modify: (실패 원인에 따라 core/*.md 문서 수정)
- 산출: `test/tmp/claude-target/` (gitignored)

- [ ] **Step 1: 격리 타겟 준비 (기존 설정이 있는 상황 시뮬레이션)**

```bash
rm -rf test/tmp/claude-target
mkdir -p test/tmp/claude-target
printf '# Existing\n\nKeep me.\n' > test/tmp/claude-target/CLAUDE.md
printf '{ "model": "claude-fable-5" }\n' > test/tmp/claude-target/settings.json
```

- [ ] **Step 2: 스킬 절차대로 이관 실행**

실행자는 설치된 스킬 문서(`~/.claude/skills/migrate/`)만 보고 수행한다 (문서 품질 자체가 테스트 대상이므로 이 계획서나 스펙을 다시 열지 말 것). 경로는 절대 경로로 전달한다:

- 소스 = codex, 소스 루트 = `<repo 절대경로>/test/fixtures/codex-home`.
- 타겟 루트 = `<repo 절대경로>/test/tmp/claude-target` (테스트 모드 → MCP는 mcp-commands.sh 산출).
- Confirm 단계는 "전체 승인"으로 진행.

- [ ] **Step 3: 검증기 실행**

```bash
./scripts/verify-migration.sh "$(pwd)/test/tmp/claude-target"
```

Expected: 전 항목 PASS, exit code 0.

- [ ] **Step 4: FAIL 항목 수정 루프**

FAIL이 나오면 원인을 분류한다 — (a) 지식 문서가 모호/누락 → 해당 core/*.md 수정, (b) 검증기 기대값 오류 → verify-migration.sh 수정 (기대값 변경은 스펙 근거 필요). **core/*.md 를 수정했으면 반드시 `./install.sh claude` 로 재설치한 뒤** Step 1부터 재실행 (실행자는 설치본만 읽으므로 재설치 없이는 수정이 반영되지 않음). 매핑 사실관계 변경은 `docs/research/*.json` 근거를 확인한다.

- [ ] **Step 5: 재실행 안전성(원장) 검증**

전 항목 PASS 후, 타겟을 지우지 말고 같은 조건으로 이관을 한 번 더 실행한다. 그 다음:

```bash
test "$(grep -c 'Answer in Korean.' test/tmp/claude-target/CLAUDE.md)" = "1" && echo "PASS: no duplicate merge"
ls test/tmp/claude-target/.migrate/ | wc -l   # run 디렉토리 2개 + ledger.json
grep -q "이미 이관됨" test/tmp/claude-target/.migrate/*/REPORT.md && echo "PASS: ledger skip noted"
```

Expected: 중복 병합 없음, 2회차 리포트에 "이미 이관됨" 표기.

- [ ] **Step 6: 문서 수정분 재설치 및 Commit**

```bash
./install.sh claude
git add core/ scripts/ && git status --short
git commit -m "fix: harden knowledge docs until fixture E2E passes"
```

(수정이 없었다면 커밋 생략.)

---

### Task 10: 실기기 dry-run (쓰기 없음)

**Files:** 없음 (읽기 전용 데모)

- [ ] **Step 1: 실제 Codex 설정으로 Plan까지만 실행**

설치된 스킬로 `/migrate codex` 흐름을 실제 `~/.codex` 에 대해 Scan → Plan 까지 수행하고 **Confirm에서 중단**한다. 계획표(자동/근사/불가 분류, 시크릿 마스킹 포함)를 사용자에게 제시한다.

주의: 실제 `~/.codex/auth.json` 등 금지 파일은 존재 확인만. 어떤 파일도 쓰지 않는다.

- [ ] **Step 2: 사용자 확인 대기**

계획표를 보고 사용자가 실제 Apply를 원하면 그때 Confirm→Apply→Report를 이어서 실행한다 (사용자 결정 사항 — 계획 범위 밖).

---

## Self-Review 체크 결과

- 스펙 커버리지: Phase 1 범위(코어 4문서 + 템플릿 + Claude 진입점 + 설치 + 검증) 전부 태스크에 매핑됨. Cursor/Grok 문서와 Codex 진입점은 스펙상 Phase 2~4 — 이 계획에서 의도적으로 제외.
- `_template.md`는 스펙 아키텍처 필수 파일이라 Phase 1에 선반영 (구현 순서 목록에는 없지만 아키텍처 절이 요구).
- 백업 방식: 스펙의 `.bak-<timestamp>` 인접 파일 방식을 `.migrate/<run-id>/backup/` 디렉토리 방식으로 대체(supersede) — 백업·리포트·원장·MCP 명령을 run 단위로 한곳에 모으기 위함. 스펙도 동일하게 갱신됨.
- 자동 감지 모드: SKILL.md에 포함(Task 8). 플러그인 패키징은 Phase 5 — 제외.
- 타입/이름 일관성: run-id 형식, `.migrate/<run-id>/` 경로, `ledger.json` 위치(`<타겟>/.migrate/ledger.json`), `<REDACTED-REENTER>` 문자열, 리포트 섹션명이 Task 2(검증기)·3·5·6 간 일치함을 확인.
- 교차 리뷰(3-way 워크플로) 지적 16건 반영 완료: 비공식 훅 이벤트 규칙, prompts 카테고리, `claude mcp add`의 `--`·`--env`, 픽스처 `type="http"` 제거, ask 케이스, defaultMode 부정 검증, 재설치 루프, 소스 루트 오버라이드, 절대 경로, Write 도구 노트, 원장 재실행 검증 등.
- Task 1 코드 품질 리뷰 반영: `AGENTS.override.md` 프리시던스 디코이, 스킬 지원 파일(`reference/tone.md`), `everything` 서버명 정밀 매칭(패키지명 부분 일치로 오통과 방지), 비활성 서버 부정 검증 추가.
- `mcp add: everything by name` 패턴 확정 경위: 1차 앵커안 `claude mcp add .*[[:space:]]everything[[:space:]]+--[[:space:]]` 은 "이름 바로 뒤에 `--`" 를 요구해 토큰 순서에 결합되는 문제가 있었다. `claude mcp add` 는 플래그를 이름 앞(`--env ... everything --`)에도 뒤(`everything --env ... --`)에도 둘 수 있어 이 앵커는 후자에서 거짓 실패한다. 최종안 `(^|[[:space:]])everything([[:space:]]|$)` 은 서버명을 공백 구분 독립 토큰으로만 매칭하므로 순서에 무관하고, 패키지명 `server-everything`(앞이 `-`)은 여전히 배제한다.

## 백로그 (Phase 1 범위 밖 — 이후 픽스처 강화 후보)

- `prompts/*.md` 의 `description`/`argument-hint` frontmatter 이관 경로 미검증.
- `config.toml` 인라인 `[[hooks.Event]]` 훅 소스(두 번째 훅 위치) 미검증.
- 공백·점 포함 MCP 서버명(`[mcp_servers."my server"]`) TOML quoting 경로 미검증.
