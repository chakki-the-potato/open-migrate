# Claude Code (Anthropic)

홈: `~/.claude` (+ `~/.claude.json`). 테스트 모드에서는 사용자가 지정한 타겟 루트를 `~/.claude` 대신 사용한다.

## 감지

`~/.claude/settings.json` 또는 `~/.claude/CLAUDE.md` 존재 시 설치된 것으로 판단.

## 쓰기 규칙 (Claude가 타겟일 때)

| 카테고리 | 쓰기 위치 | 방법 |
|---|---|---|
| 전역 규칙 | `CLAUDE.md` | 파일 끝에 `## Migrated from <source> (<date>)` 섹션으로 **원문 그대로** 병합(요약·재작성 금지). 소스의 `@import` 줄과 기존 파일의 `@import` 줄 모두 원문 유지. 기존 내용 삭제 금지. 수정 전 원본을 `.migrate/<run-id>/backup/CLAUDE.md` 로 복사 |
| MCP | `claude mcp add` CLI | **동명 서버가 타겟에 이미 있으면 등록하지 말고 건너뛴 뒤 리포트에 기록**한다(정의가 달라도 자동 판단 금지 — Confirm 에서 사용자에게 묻는다). 실사용 환경에서는 활성 서버 대부분이 이미 동명으로 존재한다. 기존 서버 목록은 `~/.claude.json` 의 `mcpServers`·`projects[<path>].mcpServers`, 프로젝트 `.mcp.json`, 그리고 `~/.claude/mcp.json` 을 모두 확인한다. **`~/.claude.json` 직접 수정 금지** (공식 권고). stdio: `claude mcp add --scope user [--env KEY=VALUE ...] <name> -- <command> [args...]` — 서버 인자 앞 `--` 구분자 필수(인자가 `-y`처럼 대시로 시작하면 없을 때 오파싱). 예: `claude mcp add --scope user --env LOG_LEVEL=info everything -- npx -y @modelcontextprotocol/server-everything`. HTTP: `claude mcp add --scope user --transport http <name> <url> [--header "K: V"]`. **remote transport 판별**: `--transport` 는 `stdio`/`http`/`sse` 를 받지만 `sse` 는 공식적으로 deprecated 다. 소스가 url 하나로 sse·http 를 모두 표현하는 도구(Cursor 등)라 전송 방식을 구분할 수 없으면 **`http` 를 쓰고** 그 사실(소스에 transport 표기가 없어 http 로 가정함)을 리포트에 기록한다. 소스가 sse 를 명시한 경우에만 `--transport sse` 를 쓰고, deprecated 라는 점을 함께 안내한다. env 값·헤더 값 모두 security.md 시크릿 탐지 대상 — 시크릿은 `<REDACTED-REENTER>` 로 두고 수동 조치 목록에 기재 |
| 스킬 | `skills/<name>/SKILL.md` | 디렉토리째 복사. 동명 스킬 존재 시 건너뛰고 리포트에 기록 |
| 커맨드 | `commands/<name>.md` | 평문 markdown. `$1`-`$9`/`$ARGUMENTS` 치환 지원 — 소스의 치환 토큰 원문 유지 |
| 훅 | `settings.json`의 `hooks` 키 | 구조: `{Event: [{matcher, hooks: [{type:"command", command, timeout}]}]}`. 기존 훅 배열에 append — 동일 command 면 스킵. 경로 표기·플래그만 다르고 같은 스크립트를 부르는 **근사 중복**도 스킵 후보로 보고 Confirm 에서 확인한다(문자열이 달라 자동 판정이 안 되므로 사용자에게 묻는다). 유효 이벤트: **소스** 도구 문서가 나열한 이벤트 전부(소스가 Cursor면 cursor.md 훅 이벤트 매핑표의 8개, Codex면 codex.md 의 공통 이벤트) + Notification, PermissionDenied, PostToolUseFailure, ConfigChange, WorktreeCreate 같은 Claude 확장 이벤트(동명이면 그대로 수용). 이 목록에 없는 이벤트명은 Claude 공식 훅 이벤트인지 확인하고, 확인되지 않으면 드롭한 뒤 리포트에 기록한다 |
| 권한 | `settings.json`의 `permissions.allow` / `deny` / `ask` | 배열에 append, 중복 제거. 공식 문서는 세션 내 `/permissions` 사용을 권하지만, 일괄 마이그레이션에서는 백업+jq 검증+실패 시 복원을 전제로 직접 병합한다(의도된 이탈). `defaultMode`는 절대 자동 설정하지 않음 — 근사 매핑표는 제안으로만 리포트에 기재 |
| env | `settings.json`의 `env` 객체 | 키 단위 병합. 기존 키와 값이 다르면 충돌 — 사용자에게 질문 |
| 서브에이전트 | `agents/<name>.md` | frontmatter: `name`·`description` (필수), `tools`·`model` (선택). 본문 = 시스템 프롬프트. `model` 유효 값: `opus`/`sonnet`/`haiku` 같은 별칭, 전체 모델 ID, 그리고 `inherit`(메인 대화 모델을 그대로 쓴다). **`inherit` 은 여러 도구가 공통으로 쓰는 값이므로 소스에 `inherit` 이 있으면 그대로 옮긴다** — 무손실이다. 이 목록에 없는 값(다른 벤더의 모델명 등)은 필드를 쓰지 말고 소스 값을 리포트에 인용해 수동 확인으로 남긴다(값 추측 금지). **동명 파일이 이미 있으면 덮어쓰지 말고 건너뛴 뒤 리포트에 기록** — 실사용 환경에서는 같은 플러그인이 양쪽에 설치돼 전량 충돌하는 경우가 흔하다 |

## settings.json 병합 규칙

1. 수정 전 원본을 `.migrate/<run-id>/backup/settings.json` 으로 복사.
2. 깊은 병합(deep merge): 객체는 키 단위 병합, 배열은 append 후 중복 제거, 기존 스칼라 값은 보존.
3. 쓰기 후 `jq -e . settings.json` 으로 JSON 유효성 확인. 실패 시 백업 복원 후 중단·보고.

## MCP 명령 실행 규칙

- 실제 환경(타겟 = 실제 `~/.claude`): `claude mcp add` 를 직접 실행하고 `claude mcp list` 로 확인.
- 테스트 모드(타겟 루트가 실제 홈이 아님): 실행하지 않고 명령 목록을 `.migrate/<run-id>/mcp-commands.sh` 로만 산출.
- 두 경우 모두 감사 기록용으로 `mcp-commands.sh` 는 항상 생성한다. **이 규칙은 Claude 가 타겟일 때만 적용된다** — 다른 타겟은 MCP 를 CLI 가 아니라 설정 파일에 직접 쓰므로 산출할 명령이 없고, 그때는 이 파일을 만들지 않는다.
- `mcp-commands.sh` 내용 규격: 첫 줄 `#!/usr/bin/env bash`, 서버당 명령 한 줄, 실행 전 확인이 필요한 항목(시크릿 재입력·동명 서버 가능성)은 주석으로 남긴다. 실행 권한은 붙이지 않아도 된다 — 사용자가 내용을 검토한 뒤 직접 실행하는 파일이다.

## 테스트 모드에서의 경로 해석 (Claude 가 소스든 타겟이든)

`~/.claude.json` 은 `~/.claude` 디렉토리 **바깥**에 있다. 타겟 루트(또는 소스 루트)가 실제 홈이 아닐 때 이 파일의 대응 위치는 **`<루트>/.claude.json`** 이다 — 루트를 `~/.claude` 자리에 그대로 대입하고, 형제 파일은 루트 **안쪽**으로 접는다.

**실제 `~/.claude.json` 을 읽지 않는다.** 테스트 실행이 사용자의 진짜 설정을 끌어들이면 결과가 오염되고, security.md 가 그 파일의 나머지 키를 읽지 말라고 한 것과도 어긋난다. 루트 안에 대응 파일이 없으면 "해당 스코프 없음" 으로 0건 처리하고 리포트에 적는다.

## 읽기 인벤토리 (Claude가 소스일 때)

| 카테고리 | 위치 | 비고 |
|---|---|---|
| 전역 규칙 | `~/.claude/CLAUDE.md` | `@경로` import 줄은 **원문 그대로 옮기고 내용을 펼치지 않는다** — 대상 파일을 열어 병합하지 마라 |
| MCP | `~/.claude.json` 최상위 `mcpServers` (user scope), `projects["<path>"].mcpServers` (local scope), 프로젝트 `.mcp.json`, `~/.claude/mcp.json` (비표준이지만 실사용 사례 있음) | **네 곳 모두 이관 소스다** — "충돌 검사용" 이 아니라 여기서 발견한 서버를 타겟으로 옮긴다. 서버 정의 필드: stdio 는 `command`/`args`/`env`, remote 는 `url`/`headers` + 선택 `type`(`http`\|`sse`). 타겟으로 넘길 때 `type` 은 타겟이 전송 방식을 구분하는 경우에만 쓰고, 구분 개념이 없는 타겟(TOML 계열은 `url` 유무로 판별)에서는 드롭한다. `headers` 는 타겟의 헤더 필드명으로 옮긴다(Codex·Grok 은 `http_headers`). 같은 서버가 여러 곳에 있으면 한 번만 옮기고 중복 출처를 리포트에 적는다 |
| 스킬 | `~/.claude/skills/<name>/SKILL.md` | 지원 파일 포함 디렉토리 전체 |
| 커맨드 | `~/.claude/commands/<name>.md` | 평문 markdown. `$1`-`$9`/`$ARGUMENTS` 치환 토큰 원문 유지 |
| 서브에이전트 | `~/.claude/agents/*.md` | frontmatter `name`·`description`(필수) + `tools`·`model`(선택) + 본문(시스템 프롬프트). `tools`·`model`·`color` 는 타겟에 대응 필드가 없으면 드롭 후 리포트 |
| 훅 | `settings.json` `hooks` | command 타입만 이관 대상 — http/mcp_tool/prompt/agent 타입은 타 도구 미지원, 스킵 후 기록 |
| 권한 | `settings.json`, `settings.local.json` 의 `permissions` | `allow`/`ask`/`deny` 배열. `defaultMode` 는 아래 승인 정책 행 |
| env 주입 | `settings.json` 최상위 `env` 객체 | |
| 승인 정책 | `settings.json` `permissions.defaultMode` | 이관하지 않음 — 타겟의 대응 개념으로 근사 매핑해 리포트 제안만 |
| 모델 | `settings.json` 최상위 `model` | 이관하지 않음 — 리포트에 키와 **현재 값**을 그대로 인용해 안내 |
| 읽지 말 것 | `~/.claude.json` 의 나머지 키(앱 상태), `projects/` 세션 데이터, `.credentials.json` | security.md 적용 |
