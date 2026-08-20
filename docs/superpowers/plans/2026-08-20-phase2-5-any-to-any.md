# Phase 2–5: any→any 완성 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Claude·Codex·Cursor·Grok 4개 도구 사이 12방향 마이그레이션을 완성하고, Claude 플러그인으로 패키징한다.

**Architecture:** Phase 1이 만든 구조(지식 문서 + AI 변환)를 유지한다. 검증은 방향별로 만들지 않는다 — **도구별 소스 픽스처 1개 + 도구별 타겟 검증기 1개**를 두고, 4개 픽스처가 논리적으로 동일한 설정을 각 도구 네이티브 포맷으로 표현한다. 그러면 임의의 (소스 픽스처, 타겟 검증기) 조합이 곧 방향 테스트가 되어 8개 산출물로 12방향을 커버한다.

**Tech Stack:** Markdown(지식 문서), Bash(검증기·설치), Python(파서), jq/tomllib(검증), git.

**참조:** Phase 1 계획서 `2026-08-20-phase1-core-codex-to-claude.md`, 스펙 `docs/superpowers/specs/2026-08-19-...md`, 리서치 `docs/research/*.json` (Cursor·Grok 표면이 검증된 상태로 들어 있음 — 문서 작성 시 반드시 대조).

---

## 정규 설정 세트 (canonical set)

4개 픽스처가 공통으로 표현하는 논리적 설정. 도구가 해당 표면을 갖지 않으면 그 항목은 생략하고, 그 도구의 타겟 검증기도 해당 체크를 두지 않는다(손실 경로를 명시적으로 문서화하는 효과).

| # | 항목 | 값 |
|---|---|---|
| 1 | 전역 규칙 2줄 | `Answer in Korean.` / `Never commit secrets.` |
| 2 | 규칙 import 줄 | `@~/.agent-rules-fixture.md` |
| 3 | 규칙 디코이 | `OVERRIDDEN-DECOY` (프리시던스 낮은 파일에만, 이관되면 실패) |
| 4 | MCP stdio | 이름 `everything`, `npx -y @modelcontextprotocol/server-everything`, env `LOG_LEVEL=info` |
| 5 | MCP http | 이름 `secretsvc`, url `https://example.com/mcp`, 헤더 `X-API-Key` = 가짜 시크릿 |
| 6 | MCP 비활성 | 이름 `disabled_one` (이관되면 실패) |
| 7 | 스킬 | `hello/SKILL.md` + `hello/reference/tone.md` |
| 8 | 서브에이전트 | `reviewer` — description `Reviews diffs for style violations`, 본문에 `strict code reviewer` |
| 9 | 훅 | 편집 도구 매처 + `echo pre-edit-check` (timeout 10), 알림 이벤트 + `echo notify` |
| 10 | 권한 | allow: `git status`, `npm run build`, `npm run test` / ask: `git push` / deny: `rm` |
| 11 | env 주입 | `FIXTURE_FLAG=1` |
| 12 | 승인 정책 | 최대 허용 상태 (Codex `never`+`danger-full-access` 등) — 자동 적용 금지 |
| 13 | 비이관 값 | 모델명 (도구별 상이, 리포트 인용 대상) |
| 14 | 접근 금지 | 인증 파일 + `AUTH-FAKE-SECRET` 마커 |

기존 `test/fixtures/codex-home/` 이 이 세트의 Codex 표현이다. 나머지 3개를 같은 세트로 만든다.

## 도구별 표면 부재 (검증 생략 대상)

| 도구 | 없는 표면 | 근거 |
|---|---|---|
| Cursor | 전역 env 주입(11) | 전역 env 표면 없음 — mcp.json per-server env 만 존재 |
| Cursor | 커스텀 커맨드 | deprecated, 스킬로 대체 |
| Grok | 커스텀 프롬프트 | `prompts/` 표면 없음 |
| Claude | — | 전 표면 보유 |

---

## File Structure

```
scripts/
  verify-migration.sh        디스패처. <target-root> <target-tool> 인자. [Task A]
  checks/
    _common.sh               run-dir·백업·원장·시크릿 — 도구 무관. [Task A]
    target-claude.sh         Claude 타겟 검증. [Task A]
    target-codex.sh          Codex 타겟 검증. [Task C]
    target-cursor.sh         Cursor 타겟 검증. [Task G]
    target-grok.sh           Grok 타겟 검증. [Task I]
  parse-mcp-commands.py      (기존)
core/tools/
  cursor.md                  [Task F]
  grok.md                    [Task I]
adapters/
  codex/SKILL.md             [Task D]
  cursor/SKILL.md            [Task G]
  grok/SKILL.md              [Task I]
test/fixtures/
  claude-home/               [Task B]
  cursor-home/               [Task G]
  grok-home/                 [Task I]
.claude-plugin/
  plugin.json                [Task L]
  marketplace.json           [Task L]
README.md                    [Task L]
```

---

### Task A: 검증기 분해 (도구별 확장 가능하게)

**Files:**
- Modify: `scripts/verify-migration.sh`
- Create: `scripts/checks/_common.sh`, `scripts/checks/target-claude.sh`

- [ ] **Step 1: 공통/타겟 경계 확정**

현재 64개 체크를 둘로 나눈다.
- `_common.sh` — run-dir 해석, 백업 존재·원본성, 원장 유효성·sha256, 시크릿 비유출(`FAKE-SECRET-123`, `AUTH-FAKE-SECRET`), 디코이 비유출(`OVERRIDDEN-DECOY`), 리포트 존재.
- `target-claude.sh` — `CLAUDE.md`, `settings.json`(훅·권한·env·병합 보존), `skills/`, `commands/`, `agents/`, `mcp-commands.sh` 파싱 검증, 리포트의 Claude 특화 문자열.

`chk`/`chk_not` 함수 정의와 `fail` 변수는 디스패처가 소유하고, 분해된 파일은 `source` 되어 그 함수를 쓴다.

- [ ] **Step 2: 디스패처 작성**

`scripts/verify-migration.sh` 를 아래 구조로 바꾼다.

```bash
#!/usr/bin/env bash
# set -e 는 의도적으로 쓰지 않는다 — 개별 체크가 실패해도 전부 끝까지 돌려 한 번에 진단한다.
set -uo pipefail
TARGET="${1:?usage: verify-migration.sh <target-root> <target-tool>}"
TOOL="${2:?usage: verify-migration.sh <target-root> <target-tool>}"
fail=0

chk() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then echo "PASS: $d"; else echo "FAIL: $d"; fail=1; fi; }
chk_not() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then echo "FAIL: $d"; fail=1; else echo "PASS: $d"; fi; }

script_dir="$(cd "$(dirname "$0")" && pwd)"
tool_checks="$script_dir/checks/target-$TOOL.sh"
if [ ! -f "$tool_checks" ]; then
  echo "ERROR: no checks for target tool '$TOOL' ($tool_checks)"
  exit 1
fi

if [ ! -d "$TARGET" ]; then
  echo "ERROR: target root not found: $TARGET"
  exit 1
fi

. "$script_dir/checks/_common.sh"
. "$tool_checks"

exit $fail
```

`_common.sh` 는 `mig_dir`·`backup_claude`·`backup_settings` 대신 도구 무관 이름(`mig_dir`, `backup_dir`)을 계산해 export 하고, 타겟별 백업 파일명은 각 `target-*.sh` 가 정한다.

- [ ] **Step 3: 회귀 확인**

```bash
./scripts/verify-migration.sh "$(pwd)/test/tmp/fake-pass-target" claude
./scripts/verify-migration.sh "$(pwd)/test/tmp/claude-target" claude
```

Expected: 둘 다 전 항목 PASS·exit 0. 체크 총 개수가 분해 전(64)과 동일해야 한다 — 분해 과정에서 체크가 누락되지 않았다는 증거다.

부정 테스트도 재확인한다. `test/tmp/fake-pass-target` 복사본에서 `mcp-commands.sh` 의 secretsvc 명령을 두 줄로 쪼개면 여전히 exit 1 이어야 한다.

- [ ] **Step 4: Commit**

```bash
git add scripts/ && git commit -m "refactor: split verifier into common and per-target checks"
```

---

### Task B: Claude 소스 픽스처

**Files:**
- Create: `test/fixtures/claude-home/CLAUDE.md`
- Create: `test/fixtures/claude-home/settings.json`
- Create: `test/fixtures/claude-home/skills/hello/SKILL.md`
- Create: `test/fixtures/claude-home/skills/hello/reference/tone.md`
- Create: `test/fixtures/claude-home/commands/greet.md`
- Create: `test/fixtures/claude-home/agents/reviewer.md`
- Create: `test/fixtures/claude-home/mcp.json`
- Create: `test/fixtures/claude-home/.credentials.json`

정규 설정 세트의 Claude 표현. 파일 생성은 반드시 파일 쓰기 도구(Write)로 한다 — 이 머신의 `env-file-guard` 훅이 시크릿 문자열이 든 셸 heredoc 을 차단한다.

- [ ] **Step 1: CLAUDE.md**

```markdown
# Global Rules

@~/.agent-rules-fixture.md

- Answer in Korean.
- Never commit secrets.
```

- [ ] **Step 2: settings.json**

```json
{
  "model": "claude-fable-5",
  "env": { "FIXTURE_FLAG": "1" },
  "permissions": {
    "allow": ["Bash(git status:*)", "Bash(npm run build:*)", "Bash(npm run test:*)"],
    "ask": ["Bash(git push:*)"],
    "deny": ["Bash(rm:*)"],
    "defaultMode": "bypassPermissions"
  },
  "hooks": {
    "PreToolUse": [
      { "matcher": "Edit|Write", "hooks": [ { "type": "command", "command": "echo pre-edit-check", "timeout": 10 } ] }
    ],
    "Notification": [
      { "matcher": "", "hooks": [ { "type": "command", "command": "echo notify" } ] }
    ],
    "ConfigChange": [
      { "matcher": "", "hooks": [ { "type": "command", "command": "echo claude-only-event" } ] }
    ]
  }
}
```

`ConfigChange` 는 Claude 전용 이벤트다 — Codex·Cursor·Grok 로 갈 때 드롭되고 리포트에 기록되어야 한다(등가물 없는 이벤트의 처리 검증).

- [ ] **Step 3: mcp.json**

```json
{
  "mcpServers": {
    "everything": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-everything"],
      "env": { "LOG_LEVEL": "info" }
    },
    "secretsvc": {
      "type": "http",
      "url": "https://example.com/mcp",
      "headers": { "X-API-Key": "sk-test-FAKE-SECRET-123" }
    }
  }
}
```

- [ ] **Step 4: 스킬·커맨드·에이전트**

`skills/hello/SKILL.md`:

```markdown
---
name: hello
description: Say hello with project context
---

Say hello and summarize the current project in one sentence.
```

`skills/hello/reference/tone.md`:

```markdown
Keep the greeting under two sentences.
```

`commands/greet.md`:

```markdown
Greet $ARGUMENTS warmly and mention today's weekday.
```

`agents/reviewer.md`:

```markdown
---
name: reviewer
description: Reviews diffs for style violations
---

You are a strict code reviewer. Report style violations only.
```

- [ ] **Step 5: 접근 금지 파일**

`.credentials.json`:

```json
{ "note": "AUTH-FAKE-SECRET — this file must never be read or copied by the migration" }
```

- [ ] **Step 6: 검증 및 Commit**

각 JSON 파일에 `jq -e .` 을 돌려 유효성을 확인하고, 심은 문자열 2개(`sk-test-FAKE-SECRET-123`, `AUTH-FAKE-SECRET`)를 grep 으로 확인한다.

```bash
git add test/fixtures/claude-home && git commit -m "test: add Claude source fixture with canonical settings set"
```

---

### Task C: Codex 타겟 검증기

**Files:**
- Create: `scripts/checks/target-codex.sh`

Codex 타겟의 기대 산출물을 검증한다. `_common.sh` 가 이미 검증하는 항목(백업·원장·시크릿·리포트 존재)은 중복하지 않는다.

- [ ] **Step 1: 검증 항목 정의**

TOML 파싱은 Python `tomllib` 로 한다(jq 는 TOML 을 못 읽는다). 헬퍼를 파일 상단에 둔다.

```bash
codex_toml() { python3 -c "
import sys, tomllib, json, pathlib
try:
    data = tomllib.loads(pathlib.Path(sys.argv[1]).read_text())
except Exception:
    print('{}'); raise SystemExit
print(json.dumps(data))
" "$1"; }
```

체크 목록.

| 체크 | 대상 |
|---|---|
| AGENTS.md 존재 + 기존 내용 보존 + 이관 규칙 2줄 + import 줄 | `$TARGET/AGENTS.md` |
| config.toml 유효 TOML | `$TARGET/config.toml` |
| 기존 최상위 키 보존 (`model`) | |
| MCP stdio: `mcp_servers.everything` command/args/env | |
| MCP http: `mcp_servers.secretsvc` url 존재, 시크릿은 `<REDACTED-REENTER>` | |
| MCP 비활성 서버 미등록 | `disabled_one` 부재 |
| env 주입: `shell_environment_policy.set.FIXTURE_FLAG` | |
| 기존 env 키 보존 | |
| 훅: `hooks.json` 최상위 구조 `{"hooks": {...}}`, 편집 매처가 `apply_patch` 로 변환, command 본문·timeout 짝 유지 | `$TARGET/hooks.json` |
| Claude 전용 이벤트 `ConfigChange` 가 이관되지 않음 | `hooks.json` 에 부재 |
| 알림 이벤트 command 유지 | |
| 권한: `rules/*.rules` 에 `prefix_rule` 로 변환, decision 매핑(allow/prompt/forbidden) | |
| 권한: 경로·도메인·MCP 규칙은 변환 불가 → 리포트 수동 목록 | |
| 스킬 디렉토리째 복사 + 지원 파일 | `$TARGET/skills/hello/` |
| 서브에이전트 md→toml 변환: description·developer_instructions | `$TARGET/agents/reviewer.toml` |
| `defaultMode` 자동 적용 금지 → `approval_policy` 미설정 | |
| 리포트에 소스 모델값·드롭된 이벤트·시크릿 키 이름 명시 | |

- [ ] **Step 2: 실패 확인 (빈 타겟)**

```bash
mkdir -p test/tmp/codex-target
./scripts/verify-migration.sh "$(pwd)/test/tmp/codex-target" codex
```

Expected: 다수 FAIL, exit 1.

- [ ] **Step 3: 긍정 경로 증명 (필수)**

`test/tmp/fake-codex-target/` 에 이상적인 Codex 타겟 산출물을 손으로 만들어 **전 항목 PASS·exit 0** 을 실증한다. Phase 1과 같은 이유다 — 항상 실패하는 망가진 체크를 가려내기 위해서. 원장 sha256 은 `shasum -a 256` 실측값, `hooks.json` 은 실제 Codex 스키마여야 한다.

- [ ] **Step 4: Commit**

```bash
git add scripts/checks/target-codex.sh && git commit -m "test: add Codex target verifier"
```

---

### Task D: Codex 진입점 + 설치 확장

**Files:**
- Create: `adapters/codex/SKILL.md`
- Modify: `install.sh`

- [ ] **Step 1: SKILL.md 작성**

`adapters/claude/SKILL.md` 와 같은 구조이되 목적지가 Codex 다. 목적지 자신은 소스 후보에서 제외한다.

```markdown
---
name: migrate
description: Migrate settings from another AI coding tool (Claude Code, Cursor, Grok) into Codex CLI — rules, MCP servers, skills, subagents, hooks, permissions. Use when the user asks to import or migrate settings from another AI tool, or runs /migrate [source].
---

# migrate — AI 설정 마이그레이션 (목적지: Codex CLI)

너는 목적지 도구(Codex CLI) 안에서 실행 중이다. 소스 도구의 설정을 이 도구로 이관한다.

## 0. 입력 해석

- 스킬 디렉토리 = 이 `SKILL.md` 파일이 있는 디렉토리(통상 `~/.codex/skills/migrate/`). 아래의 모든 `core/...` 경로는 이 디렉토리 기준 상대 경로다.
- 소스 = `$ARGUMENTS` 에서 찾은 도구 이름 (`claude` | `cursor` | `grok`). 인자가 토큰 하나면 그 단어를, 자연어 문장이면 문장 안에 언급된 도구 이름을 쓴다.
- 해당 소스의 문서가 `core/tools/` 에 없으면 지원 예정이라고 알리고 중단한다.
- 소스 루트 = 소스 도구 문서의 기본 홈. 사용자가 소스 루트 경로를 명시하면 그 경로를 대신 쓴다.
- 타겟 루트 = 실제 Codex 환경 (`$CODEX_HOME`, 기본 `~/.codex`, `core/tools/codex.md` 기준). 사용자가 타겟 루트를 명시하면 그 경로를 쓰고 **테스트 모드**로 전환한다.
- 소스도 소스 루트도 특정되지 않았을 때만 자동 감지한다. `~/.claude`, `~/.cursor`, `~/.grok` 존재 여부를 확인해 발견된 도구를 사용자에게 제시하고 고르게 한다(목적지 자신은 제외). 사용자에게 물을 수 없으면 추측하지 말고 중단한다.

## 1. 지식 로드 (스킬 디렉토리 기준, 전부 필수)

1. `core/security.md` — 최우선 정책
2. `core/procedure.md` — 실행 절차
3. `core/tools/<source>.md` — 소스 읽기·변환 규칙
4. `core/tools/codex.md` — 타겟 쓰기 규칙

## 2. 실행

`core/procedure.md` 의 Scan → Plan → Confirm → Apply → Report 를 순서대로 수행한다.
```

- [ ] **Step 2: install.sh 확장**

`case` 문에 codex 를 추가한다. 나머지 로직은 그대로다.

```bash
case "$dest" in
  claude) target="$HOME/.claude/skills/migrate" ;;
  codex)  target="${CODEX_HOME:-$HOME/.codex}/skills/migrate" ;;
  *) echo "unsupported destination: $dest (supported: claude, codex)" >&2; exit 1 ;;
esac
```

- [ ] **Step 3: 설치 확인**

```bash
./install.sh codex
ls ~/.codex/skills/migrate/ ~/.codex/skills/migrate/core/tools/
```

Expected: `SKILL.md` 와 `core/` 가 보이고, `core/tools/` 에 claude.md·codex.md 존재(`_template.md` 는 제외).

`~/.codex/skills/` 는 실제 Codex 스킬 디렉토리다. 이 설치는 `migrate` 라는 새 스킬 하나만 추가하며 기존 스킬·설정을 건드리지 않는다.

- [ ] **Step 4: Commit**

```bash
git add adapters/codex install.sh && git commit -m "feat: add Codex entry point and installer support"
```

---

### Task E: E2E Claude → Codex (구조 증명)

**Files:** 수정은 실패 원인에 따라 `core/*.md`

이 태스크가 이 계획서의 핵심 증명이다 — **새 지식 문서 없이** 기존 문서만으로 역방향이 동작하는지 본다.

- [ ] **Step 1: 타겟 준비 (기존 설정 있는 상태)**

```bash
rm -rf test/tmp/codex-target && mkdir -p test/tmp/codex-target
printf '# Existing\n\nKeep me.\n' > test/tmp/codex-target/AGENTS.md
cat > test/tmp/codex-target/config.toml <<'TOML'
model = "gpt-5.6-sol"

[shell_environment_policy.set]
EXISTING_KEY = "keep"
TOML
```

- [ ] **Step 2: 신규 에이전트로 이관 실행**

에이전트는 설치된 스킬 트리(`~/.codex/skills/migrate/`)와 소스 루트만 읽는다. 계획서·스펙·검증기 열람 금지. 경로는 절대 경로로 전달한다.

- 소스 = claude, 소스 루트 = `<repo>/test/fixtures/claude-home`
- 타겟 루트 = `<repo>/test/tmp/codex-target` (테스트 모드)
- Confirm 은 전체 승인

훅 정책을 지시문에 포함한다 — 훅에 차단되면 표현식을 바꿔 우회하지 말고 멈춰 보고하고, 우회가 아닌 다른 경로를 쓴다.

- [ ] **Step 3: 검증**

```bash
./scripts/verify-migration.sh "$(pwd)/test/tmp/codex-target" codex
```

Expected: 전 항목 PASS, exit 0.

- [ ] **Step 4: FAIL 수정 루프**

원인을 분류한다 — (a) 지식 문서 미비 → 해당 `core/*.md` 수정 후 **반드시 `./install.sh codex` 재설치** 뒤 Step 1부터 재실행, (b) 검증기 기대값 오류 → `scripts/checks/target-codex.sh` 수정(근거는 `docs/research/*.json`).

**이 태스크에서 `core/tools/claude.md` 나 `core/tools/codex.md` 에 실질적인 새 지식을 추가해야 했다면 그 사실을 기록한다** — "문서 재사용만으로 역방향이 된다"는 주장의 반례이므로 계획서 Self-Review 에 남긴다.

- [ ] **Step 5: 양방향 회귀 확인**

Codex→Claude 방향이 여전히 통과하는지 확인한다.

```bash
./scripts/verify-migration.sh "$(pwd)/test/tmp/claude-target" claude
```

Expected: 전 항목 PASS. 문서 수정이 반대 방향을 깨뜨리지 않았다는 증거다.

- [ ] **Step 6: Commit**

```bash
./install.sh claude && ./install.sh codex
git add core/ scripts/ && git commit -m "fix: harden docs until Claude-to-Codex E2E passes"
```

---

### Task F: Cursor 지식 문서

**Files:**
- Create: `core/tools/cursor.md`

`core/tools/_template.md` 구조를 따르고, 사실 근거는 `docs/research/2026-08-20-cursor-grok-gapfills.json` 과 `2026-08-20-gap-resolution.json` 이다. 작성 시 반드시 대조한다.

- [ ] **Step 1: 인벤토리·변환·쓰기 규칙 작성**

리서치로 확정된 사실만 싣는다. 최소한 다음을 포함한다.

- 홈 `~/.cursor`, 감지 기준 `~/.cursor/mcp.json` 또는 `~/.cursor/cli-config.json`
- 규칙: `.cursor/rules/*.mdc`(frontmatter description·globs·alwaysApply, **평문 `.md` 는 무시됨**), AGENTS.md·CLAUDE.md 네이티브 읽기 → 이관 타겟은 AGENTS.md 권장
- User Rules 는 계정 동기화라 파일 이관 불가 → 수동 안내
- MCP: `~/.cursor/mcp.json` `mcpServers` (stdio: command/args/env/envFile, remote: url/headers). 서버 이름에 공백 허용. `${env:NAME}` 보간
- 스킬: `~/.cursor/skills/` SKILL.md 표준. **`skills-cursor/` 는 앱 관리 내장분 — 이관 금지**. `$ARGUMENTS` 치환 없음
- 서브에이전트: `~/.cursor/agents/*.md` — frontmatter name·description·model·readonly·is_background. Claude 전용 필드(tools·color)는 드롭
- 훅: `hooks.json` version:1, **camelCase 이벤트, 평면 배열** — Claude 스키마와 다름. 이벤트 매핑표(PreToolUse↔preToolUse 등 8종), Notification·PermissionRequest 미지원
- 권한: `cli-config.json` `permissions.allow/deny` — 토큰 5종 `Shell()`·`Read()`·`Write()`·`WebFetch()`·`Mcp()`, 인자는 콜론 문법(`curl:*`). approvalMode 3종
- env 주입 표면 없음 → Claude `env` 는 이관 불가, 수동 안내
- 커스텀 커맨드는 deprecated — 스킬로 이관
- 읽지 말 것: 인증·`state.vscdb`·`projects/`·`extensions/`

- [ ] **Step 2: Commit**

```bash
git add core/tools/cursor.md && git commit -m "feat: add Cursor tool knowledge doc"
```

---

### Task G: Cursor 픽스처·검증기·진입점

**Files:**
- Create: `test/fixtures/cursor-home/` (정규 세트의 Cursor 표현)
- Create: `scripts/checks/target-cursor.sh`
- Create: `adapters/cursor/SKILL.md`
- Modify: `install.sh`

- [ ] **Step 1: 픽스처**

정규 설정 세트를 Cursor 포맷으로. env 주입(11)은 표면이 없으므로 생략한다.

- `AGENTS.md` — 규칙 2줄 + import 줄
- `mcp.json` — everything(stdio+env), secretsvc(url+headers 시크릿), disabled_one 은 Cursor 에 비활성 개념이 없으므로 생략하고 대신 두 서버만 둔다
- `skills/hello/SKILL.md` + `reference/tone.md`
- `skills-cursor/builtin-noop/SKILL.md` — 이관되면 실패하는 디코이(앱 관리 내장분)
- `agents/reviewer.md`
- `hooks.json` — camelCase `preToolUse` + `notification` 없음(미지원) → `preToolUse` 만
- `cli-config.json` — permissions.allow/deny 토큰 5종 중 Shell·Read 사용, approvalMode

- [ ] **Step 2: 타겟 검증기**

Task C 와 같은 방식. Cursor 타겟일 때 기대 산출물을 검증하고, 표면이 없는 카테고리(env 주입)는 대신 **리포트에 이관 불가로 기록됐는지** 검증한다.

- [ ] **Step 3: 진입점 + install.sh 확장**

`adapters/cursor/SKILL.md` 는 Task D 구조를 따르되 목적지가 Cursor 이고 설치 경로는 `~/.cursor/skills/migrate`. Cursor 스킬은 `$ARGUMENTS` 치환이 없으므로 **인자를 메시지 본문에서 읽도록** 0단계 문구를 조정한다.

- [ ] **Step 4: 긍정 경로 증명 + Commit**

빈 타겟 FAIL, 손으로 만든 이상적 타겟 전 항목 PASS 를 실증한 뒤 커밋한다.

---

### Task H: E2E Cursor↔Claude

- [ ] **Step 1: cursor → claude**

소스 루트 `test/fixtures/cursor-home`, 타겟 `test/tmp/claude-target-from-cursor`(기존 설정 심은 상태), 검증 `verify-migration.sh <target> claude`.

- [ ] **Step 2: claude → cursor**

소스 루트 `test/fixtures/claude-home`, 타겟 `test/tmp/cursor-target`, 검증 `verify-migration.sh <target> cursor`.

- [ ] **Step 3: 수정 루프 + 회귀**

FAIL 을 문서 미비/검증기 오류로 분류해 수정하고, 수정 후 기존 두 방향(codex→claude, claude→codex)이 여전히 통과하는지 확인한다.

- [ ] **Step 4: Commit**

---

### Task I: Grok 지식 문서·픽스처·검증기·진입점

**Files:**
- Create: `core/tools/grok.md`, `test/fixtures/grok-home/`, `scripts/checks/target-grok.sh`, `adapters/grok/SKILL.md`
- Modify: `install.sh`

대상은 xAI 공식 **Grok Build**(`grok`)다. 근거는 `docs/research/2026-08-20-gap-resolution.json`.

- [ ] **Step 1: 지식 문서**

리서치로 확정된 사실만 싣는다.

- 홈 `~/.grok`(`GROK_HOME` 으로 재지정 가능), 감지 기준 `~/.grok/config.toml`
- 규칙: `~/.grok/rules/*.md`(임의 조각·단일 파일 모두 허용), `~/.grok/AGENTS.md` 도 지원. GROK.md 는 읽지 않음
- MCP: `config.toml` `[mcp_servers.*]` TOML — Codex 와 같은 모양
- 스킬: `~/.grok/skills/` SKILL.md 표준, user-invocable 이면 슬래시 명령
- 서브에이전트: `~/.grok/agents/*.md` — YAML frontmatter **camelCase**(name·description·promptMode·tools·model·effort·maxTurns 등)
- 훅: `~/.grok/hooks/*.json`, PascalCase 이벤트 15종 — Claude 와 동일 JSON 구조
- 권한: `[permission]` — **Claude 와 같은 문자열 문법**(`Bash(git *)`, `Read(src/**)`) allow/ask/deny
- env 주입: `[shell_environment_policy]` — Codex 와 동일한 테이블명·구조
- 모델·인증·샌드박스는 이관 안 함
- 커스텀 프롬프트 표면 없음
- 읽지 말 것: `auth.json`, `sessions/`, `memory/`(선택 이관 가능하나 기본 제외)

- [ ] **Step 2: 픽스처·검증기·진입점**

Task G 와 같은 방식. Grok 진입점 설치 경로는 `~/.grok/skills/migrate`.

**주의: 이 머신에 Grok Build 가 설치되어 있지 않다.** 설치 경로 생성은 가능하지만 실제 도구로 스킬이 로드되는지는 확인할 수 없다. 그 사실을 리포트와 README 에 명시한다.

- [ ] **Step 3: 긍정 경로 증명 + Commit**

---

### Task J: E2E Grok↔Claude

Task H 와 같은 구조로 `grok → claude`, `claude → grok` 두 방향을 실행·검증·수정한다. 수정 후 기존 네 방향 회귀를 확인한다.

---

### Task K: 조합 검증 (Codex → Cursor)

**Files:** 없음 (기존 산출물 조합)

새 픽스처도 새 검증기도 만들지 않는다. 기존 Codex 소스 픽스처와 Cursor 타겟 검증기를 조합해 실행한다.

- [ ] **Step 1: 실행**

소스 루트 `test/fixtures/codex-home`, 타겟 `test/tmp/cursor-target-from-codex`, 검증 `verify-migration.sh <target> cursor`.

- [ ] **Step 2: 판정**

통과하면 "픽스처 N개 + 검증기 N개로 N² 방향이 커버된다"는 설계 주장이 실증된 것이다. 실패하면 원인이 (a) 특정 도구쌍에만 필요한 지식인지 (b) 일반 규칙의 누락인지 분류해 기록한다 — (a) 가 다수면 any→any 주장을 스펙에서 완화해야 한다.

- [ ] **Step 3: 결과를 스펙에 반영 + Commit**

---

### Task L: 패키징·문서화

**Files:**
- Create: `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `README.md`
- Modify: `install.sh` (필요 시)

- [ ] **Step 1: plugin.json**

```json
{
  "name": "migrate",
  "description": "Migrate settings between AI coding tools (Claude Code, Codex CLI, Cursor, Grok Build)",
  "version": "0.1.0",
  "license": "MIT"
}
```

플러그인 루트에 `skills/migrate/SKILL.md` + `skills/migrate/core/` 를 두는 배치가 필요하다. 저장소 구조(`adapters/`, `core/`)와 플러그인 배치가 다르므로, 빌드 스텝을 `install.sh` 에 `--plugin` 모드로 추가하거나 별도 `scripts/build-plugin.sh` 를 둔다. 어느 쪽이든 **`core/tools/_template.md` 는 제외**한다.

- [ ] **Step 2: marketplace.json**

```json
{
  "name": "migrate-marketplace",
  "owner": { "name": "chakki-the-potato" },
  "plugins": [
    { "name": "migrate", "source": "./", "description": "Migrate settings between AI coding tools" }
  ]
}
```

리서치에서 확인된 사실 — **Codex 가 Claude 마켓플레이스를 무변환으로 설치한다.** 즉 이 패키지 하나로 Claude·Codex 배포가 동시에 커버된다. README 에 명시한다.

- [ ] **Step 3: 검증**

```bash
claude plugin validate . --strict
```

Expected: 통과. 실패하면 스키마 오류를 수정한다.

- [ ] **Step 4: README**

포함할 내용.
- 한 줄 설명과 지원 방향 표(4개 도구, 12방향, 실측 검증된 방향 표시)
- 설치 방법 두 가지: 플러그인(`/plugin marketplace add` → Claude·Codex), 저장소 스크립트(`./install.sh <dest>` → Cursor·Grok)
- 사용법 `/migrate <source>`, 자동 감지 모드
- **이관되지 않는 것** 명시: API 키·인증 파일(재입력 목록으로 안내), 모델 설정, 단축키, 세션 기록
- 손실 변환 경고: 권한 모델은 도구마다 표현력이 달라 근사 매핑이며 자동 적용하지 않음
- 안전 보장: Confirm 승인 전 무쓰기, 백업 후 병합, 재실행 안전(원장)
- 검증 방법: `./scripts/verify-migration.sh <target> <tool>`
- Grok Build 는 이 저장소 개발 환경에 설치되어 있지 않아 실기기 검증이 안 된 상태임을 명시

- [ ] **Step 5: Commit**

```bash
git add .claude-plugin README.md scripts/ && git commit -m "feat: package as Claude plugin and document usage"
```

---

## Self-Review 체크 결과

- 스펙 커버리지: 스펙 구현 순서 2~5단계를 Task A~L 로 전개했다. Task A(검증기 분해)와 정규 설정 세트는 스펙에 없던 추가 설계이지만, "방향별 검증기 N²" 를 "도구별 N" 으로 줄이기 위한 것으로 스펙의 허브-스포크 원칙과 같은 방향이다.
- 검증 가능성: 각 E2E 태스크는 결정적 검증기로 판정된다. Task K 는 설계 주장 자체의 반증 가능한 실험으로 구성했다.
- 미검증 잔여: Grok Build 미설치로 실기기 확인 불가 — Task I·J·L 에 명시했다.
- 위험: Task E 에서 문서에 새 지식을 추가해야 한다면 any→any 주장이 약해진다. 그 경우를 기록하도록 Step 4 에 명시했다.
