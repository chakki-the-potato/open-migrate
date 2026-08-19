# AI Settings Migration Skill — Design

날짜: 2026-08-19
상태: 사용자 리뷰 대기 (any→any 확장 반영)

## 목표

AI 코딩 도구 간 갈아타기를 명령 하나로 끝낸다. 방향 제한 없음(any→any).
사용자는 새로 옮겨간 도구 안에서 `/migrate <source>` 한 번으로 규칙·MCP·스킬·훅·권한 설정을
그 도구 위치에 맞게 옮기고, 못 옮긴 항목은 수동 조치 목록으로 받는다.

## 포지셔닝 (리서치 근거)

- Claude→Codex 방향은 포화 상태다. OpenAI 공식 migrate-to-codex 스킬, Codex CLI 네이티브 `/import`(v0.145+), 커뮤니티 도구 6개 이상.
- Codex→Claude 방향(into-Claude)은 2026-08 현재 전용 도구가 없다. 부분 커버 도구 1개(MCP·세션만)와 세션 전용 도구뿐.
- 전략: 빈 방향(into-Claude)을 첫 완성 목표로 삼되, 구조는 처음부터 any→any로 설계한다. 변환 엔진은 각 목적지 도구의 AI 자신이고, 도구별 지식은 markdown 문서로 관리한다.
- 기존 도구들과의 차별점: 방향 고정 도구(단방향)와 달리 지식 문서 공유로 모든 방향을 지원하고, 결정적 파서가 아니라 AI 변환이라 포맷 변화에 강하다.

## 범위

- 대상 도구 4개: Claude Code, Codex CLI, Cursor, Grok CLI. 이들 사이 12방향 전부 지원이 목표.
- 실행 모델: 마이그레이션은 항상 목적지 도구 안에서 실행된다. 사용자가 새로 구독한 도구의 AI가 변환 엔진이다.
- 도구 추가 = 지식 문서 1개 + 진입점 1개 추가. 후순위 후보: Gemini CLI, Copilot, Windsurf, Cline/Roo, Aider.
- 비범위(v1): 세션/대화 기록 이관, API 키·auth 파일 이관.

## 명령 UX

목적지 도구 안에서 실행한다. 모든 도구에서 동일한 명령 체계.

```
/migrate           설치된 소스 도구 자동 감지 → 선택 후 이관
/migrate codex     Codex에서 이관
/migrate claude    Claude Code에서 이관
/migrate cursor    Cursor에서 이관
/migrate grok      Grok에서 이관
```

- 스킬 이름은 `migrate` (kebab-case, 공백 불가). 소스는 `$ARGUMENTS`로 받는다. 목적지 자신은 소스 목록에서 제외.
- 자동 감지: `~/.codex`, `~/.claude`, `~/.cursor`, `~/.grok` 등 알려진 설정 경로 존재 여부를 훑고, 발견된 도구를 사용자에게 제시한다.
- 커스텀 명령 시스템이 없는 도구용 폴백: 사용자가 그 도구의 채팅에 붙여넣는 실행 프롬프트 문서(runbook) 제공. 진입점이 프롬프트 한 장이므로 어떤 도구든 목적지가 될 수 있다.

## 아키텍처

지식과 절차는 공유 코어에 두고, 도구별 진입점은 얇은 껍데기로 만든다.

```
core/
  procedure.md           5단계 절차 (Scan→Plan→Confirm→Apply→Report). 모든 방향 공통
  security.md            시크릿 탐지 패턴과 처리 정책
  tools/
    claude.md            Claude Code 지식: 소스로 읽는 법 + 목적지로 쓰는 법 양면 기술
    codex.md             Codex CLI 지식 (아래 매핑표 수록)
    cursor.md            Cursor 지식 (구현 단계에서 리서치로 작성)
    grok.md              Grok CLI 지식 (구현 단계에서 리서치로 작성)
    _template.md         새 도구 추가용 템플릿 (섹션: 설정 인벤토리, 읽기 규칙, 쓰기 규칙, 시크릿 위치, 함정)
adapters/
  claude/SKILL.md        Claude Code 진입점 (~/.claude/skills/migrate/)
  codex/SKILL.md         Codex CLI 진입점 (~/.codex/skills/migrate/, 동일 SKILL.md 포맷)
  cursor/SKILL.md        Cursor 진입점 (~/.cursor/skills/migrate/, 동일 SKILL.md 포맷. IDE 채팅·CLI 양쪽에서 동작 확인됨)
  grok/SKILL.md          Grok Build 진입점 (~/.grok/skills/migrate/, 동일 SKILL.md 포맷)
  runbook.md             스킬 시스템 없는 도구용 폴백 (채팅에 붙여넣는 실행 프롬프트)
```

리서치 결과 4개 도구 전부 같은 `SKILL.md` 포맷(agent-skills 표준)을 지원한다.
진입점 4개는 사실상 같은 파일이고 설치 경로만 다르다.

- 매핑표는 방향별(N×N)로 만들지 않는다. 도구 문서가 자기 설정 표면의 읽기/쓰기 규칙을 기술하고, AI가 소스 문서와 목적지 문서를 조합해 변환한다. 도구 4개 = 문서 4개로 12방향 커버.
- 파서·변환 코드는 두지 않는다. AI가 지식 문서를 읽고 직접 변환한다.
- Claude Code와 Codex CLI는 동일한 `skills/<name>/SKILL.md` 포맷을 쓰므로 두 진입점은 거의 같은 내용이다.
- 배포: 개인 스킬로 시작, 이후 Claude 플러그인 패키징(`/plugin install`) + 저장소 설치 스크립트(다른 도구용).

## 실행 흐름 (5단계)

1. **Scan** — 소스 지식 문서 기준으로 설정 파일 인벤토리. 시크릿 파일(auth.json 등)은 존재만 확인, 내용 접근 금지.
2. **Plan** — 카테고리별 분류 제시: 자동 이관 / 손실 매핑(근사치) / 이관 불가(수동 조치).
3. **Confirm** — 사용자 승인. 카테고리 단위 제외 선택 가능. 승인 전 어떤 쓰기도 하지 않는다.
4. **Apply** — 대상 파일 백업(`.bak-<timestamp>`) 후 병합. 덮어쓰기 금지. MCP 등록은 `~/.claude.json` 직접 수정 대신 `claude mcp add` CLI 경유(공식 문서 권고).
5. **Report** — 이관 완료 / 근사 매핑 상세 / 수동 조치 목록(시크릿 재입력 등) 출력. 검증 명령(`claude mcp list` 등) 실행 결과 포함.

## Codex↔Claude 매핑표 (리서치 검증 완료)

아래 표는 Codex→Claude 방향으로 표기했지만, 각 행은 양방향 대응 관계다. 역방향(Claude→Codex)은 같은 표를 반대로 읽는다.

| Codex | Claude | 이식성 | 비고 |
|---|---|---|---|
| `~/.codex/AGENTS.md` | `~/.claude/CLAUDE.md` 병합 또는 `@import` | 상 | import 체인(`@path`) 유지 |
| `config.toml [mcp_servers.*]` | `claude mcp add` (stdio/http) | 상 | env/headers의 시크릿 값은 별도 처리 |
| `skills/<name>/SKILL.md` | `~/.claude/skills/` | 상 | 디렉토리 구조 동일, 거의 복사 |
| `hooks.json` | `settings.json` hooks | 상 | JSON 스키마 동일, 이벤트명 차이만 매핑 |
| `rules/default.rules` (prefix_rule DSL) | `permissions.allow`의 `Bash(...)` 패턴 | 중 | argv prefix → glob 의미 변환 |
| `agents/*.toml` | `~/.claude/agents/*.md` | 중 | TOML → Markdown+frontmatter 변환 |
| `prompts/*.md` (deprecated) | commands/skills | 중 | `$1-$9`/`$ARGUMENTS` 치환 유지 |
| `[shell_environment_policy.set]` | `settings.json` env | 상 | |
| `approval_policy` + `sandbox_mode` | `permissions.defaultMode` | 하 | 근사 제안만, 자동 적용 안 함 |
| `[projects] trust_level` | 해당 없음 | — | 리포트에 안내만 |
| model·personality·auth.json·세션·캐시 | 이관 안 함 | — | 리포트에 안내만 |

## Cursor 설정 표면 (리서치 검증 완료, 2026-08-20)

공식 문서 + 이 머신의 실제 `~/.cursor`로 검증.

| 카테고리 | Cursor 위치 | 비고 |
|---|---|---|
| 규칙 | `.cursor/rules/*.mdc` (frontmatter: description/globs/alwaysApply), 레거시 `.cursorrules` | AGENTS.md·CLAUDE.md도 네이티브로 읽음 |
| User Rules (전역) | Cursor 계정에 동기화 (파일 아님, state.vscdb) | 파일 이관 불가 → 수동 안내 |
| MCP | `~/.cursor/mcp.json`, `.cursor/mcp.json` — mcpServers 맵 (stdio: command/args/env/envFile, remote: url/headers/auth) | 서버 이름에 공백 허용 |
| 커맨드 | `.cursor/commands/*.md`, `~/.cursor/commands/` | 평문 markdown |
| 스킬 | `~/.cursor/skills/`, `.cursor/skills/` — SKILL.md 표준 | `.claude/skills/`·`.codex/skills/`도 호환 로드함. `skills-cursor/`는 앱 관리 내장분 — 이관 금지 |
| 서브에이전트 | `~/.cursor/agents/*.md`, `.cursor/agents/` | Claude agents/*.md와 1:1 |
| 훅 | `hooks.json` (version:1, camelCase 이벤트, 평면 배열) | Claude 스키마와 다름. 단 Cursor가 `.claude/settings.json` 훅을 자동 매핑해 읽음 |
| 권한 | `cli-config.json` — permissions.allow/deny(`Shell(ls)` 문법), approvalMode, sandbox | Claude permissions와 근사 매핑 |
| GUI 전용 | Memories, Team Rules, 커스텀 모드 | 이관 불가 → 수동 안내 |

## Grok 설정 표면 (리서치 검증 완료, 2026-08-20)

대상은 xAI 공식 **Grok Build** (`grok`, github.com/xai-org/grok-build — 공식·지배적).
커뮤니티 superagent grok-cli는 보조 문서로만 다루고 진입점은 runbook 폴백.

| 카테고리 | Grok Build 위치 | 비고 |
|---|---|---|
| 규칙 | `~/.grok/rules/*.md` (전역 디렉토리), AGENTS.md·CLAUDE.md 네이티브 읽기 | GROK.md는 안 읽음 — 이관 타겟은 AGENTS.md |
| MCP | `~/.grok/config.toml`, `.grok/config.toml`의 `[mcp_servers.*]` TOML | Codex와 같은 TOML 모양. `.claude.json`·`.cursor/mcp.json`·`.mcp.json`도 호환 읽기 |
| 스킬/커맨드 | `~/.grok/skills/`, `.grok/skills/` — SKILL.md 표준, user-invocable이면 슬래시 명령 | `/migrate` 진입점 가능 확인 |
| 서브에이전트 | `~/.grok/agents/`, `.grok/agents/` | |
| 훅 | `~/.grok/hooks/*.json`, config.toml 인라인 — PascalCase 이벤트, Claude와 동일 JSON 구조 | 이벤트 15개, Claude와 대부분 동명 |
| 모델/인증 | config.toml `[models]`, `auth.json` (자동 관리) | 이관 안 함 |

## 훅 이벤트 매핑 (검증 완료)

- Codex 11개 이벤트(SessionStart/End, SubagentStart/Stop, PreToolUse, PermissionRequest, PostToolUse, Pre/PostCompact, UserPromptSubmit, Stop)는 Claude에 전부 동명 존재 — 무변환.
- Claude 전용 이벤트 약 20개(Notification, ConfigChange, WorktreeCreate 등)는 Codex에 등가물 없음 — 경고 후 드롭.
- 도구명 매처는 변환 필요: Codex `apply_patch` ↔ Claude `Edit|Write`, Codex에 Read/Grep/Glob 없음.
- Claude의 비-command 훅 타입(http/mcp_tool/prompt/agent)은 타 도구 미지원 — 스킵.
- Cursor 훅은 camelCase + 평면 구조라 이벤트명·구조 양쪽 변환 필요.

## 배포 (리서치 반영)

- Claude 플러그인 형식(`.claude-plugin/plugin.json` + marketplace.json)으로 패키징하면 **Codex가 Claude 마켓플레이스를 무변환으로 직접 설치**함(이 머신에서 실증). 패키지 하나로 Claude·Codex 배포 커버.
- Cursor·Grok은 저장소 설치 스크립트(스킬 디렉토리 복사)로 배포.
- Codex `/import`의 세션 dedupe 원장(`content_sha256` 기록) 패턴을 재실행 안전성에 차용.

원본 리서치 전문: `docs/research/*.json`.

## 안전 정책

- auth·API 키·`.env`류 파일은 읽기·복사 금지. 존재 확인만.
- MCP env/headers 등 설정 안의 시크릿 패턴 값은 마스킹하고 "재입력 필요" 목록으로 리포트한다. 평문 복사 금지.
- 쓰기 전 대상 파일 백업 필수. 병합만 하고 덮어쓰기 금지.
- 기존 Claude 설정과 충돌하는 항목은 자동 결정하지 않고 사용자에게 묻는다.
- Confirm 단계 승인 전에는 파일 시스템 변경 금지.

## 검증 방법

- 격리 테스트: 목적지 설정 경로를 임시 디렉토리로 지정(`CLAUDE_CONFIG_DIR`, `CODEX_HOME` 등)해 실행 → 산출 파일(설정 JSON/TOML 유효성, 규칙 파일 병합 결과, 스킬 복사 결과) 검사.
- 실기기 테스트: 이 머신의 실제 `~/.codex`·`~/.claude` 설정을 첫 테스트 케이스로 사용 (Confirm 단계에서 중단하는 dry-run 우선).
- 등록 검증: `claude mcp list` 등 목적지 도구의 조회 명령 출력으로 확인.

## 구현 순서

1. **코어 + Codex→Claude**: `core/procedure.md`, `core/security.md`, `core/tools/codex.md`, `core/tools/claude.md`, Claude 진입점. 빈 방향(into-Claude)을 end-to-end로 먼저 완성하고 검증.
2. **Claude→Codex**: Codex 진입점 추가. 새 지식 문서 없이 기존 문서 재사용으로 역방향이 동작하는지 검증 — any→any 구조 증명.
3. **Cursor 편입**: `core/tools/cursor.md` 작성(리서치 완료분 반영) + Cursor 진입점. Cursor↔Claude, Cursor↔Codex 검증.
4. **Grok 편입**: `core/tools/grok.md` 작성(Grok Build 기준) + Grok 진입점 스킬. 커뮤니티 grok-cli는 runbook 폴백만.
5. **마감**: 자동 감지 모드, 플러그인 패키징, 설치 스크립트.
