# Claude Code (Anthropic)

홈: `~/.claude` (+ `~/.claude.json`). 테스트 모드에서는 사용자가 지정한 타겟 루트를 `~/.claude` 대신 사용한다.

## 감지

`~/.claude/settings.json` 또는 `~/.claude/CLAUDE.md` 존재 시 설치된 것으로 판단.

## 쓰기 규칙 (Claude가 타겟일 때)

| 카테고리 | 쓰기 위치 | 방법 |
|---|---|---|
| 전역 규칙 | `CLAUDE.md` | 파일 끝에 `## Migrated from <source> (<date>)` 섹션으로 **원문 그대로** 병합(요약·재작성 금지). 소스의 `@import` 줄과 기존 파일의 `@import` 줄 모두 원문 유지. 기존 내용 삭제 금지. 수정 전 원본을 `.migrate/<run-id>/backup/CLAUDE.md` 로 복사 |
| MCP | `claude mcp add` CLI | **`~/.claude.json` 직접 수정 금지** (공식 권고). stdio: `claude mcp add --scope user [--env KEY=VALUE ...] <name> -- <command> [args...]` — 서버 인자 앞 `--` 구분자 필수(인자가 `-y`처럼 대시로 시작하면 없을 때 오파싱). 예: `claude mcp add --scope user --env LOG_LEVEL=info everything -- npx -y @modelcontextprotocol/server-everything`. HTTP: `claude mcp add --scope user --transport http <name> <url> [--header "K: V"]`. env 값·헤더 값 모두 security.md 시크릿 탐지 대상 — 시크릿은 `<REDACTED-REENTER>` 로 두고 수동 조치 목록에 기재 |
| 스킬 | `skills/<name>/SKILL.md` | 디렉토리째 복사. 동명 스킬 존재 시 건너뛰고 리포트에 기록 |
| 커맨드 | `commands/<name>.md` | 평문 markdown. `$1`-`$9`/`$ARGUMENTS` 치환 지원 — 소스의 치환 토큰 원문 유지 |
| 훅 | `settings.json`의 `hooks` 키 | 구조: `{Event: [{matcher, hooks: [{type:"command", command, timeout}]}]}`. 기존 훅 배열에 append — 동일 command 중복이면 스킵. 유효 이벤트: 소스 도구의 11개 공통 이벤트 전부 + Notification, PermissionDenied, PostToolUseFailure, ConfigChange, WorktreeCreate 같은 Claude 확장 이벤트(동명이면 그대로 수용). 이 목록에 없는 이벤트명은 Claude 공식 훅 이벤트인지 확인하고, 확인되지 않으면 드롭한 뒤 리포트에 기록한다 |
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
