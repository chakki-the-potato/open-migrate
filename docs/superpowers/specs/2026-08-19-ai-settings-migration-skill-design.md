# AI Settings Migration Skill — Design

날짜: 2026-08-19
상태: 사용자 리뷰 대기

## 목표

다른 AI 코딩 도구에서 Claude Code로 갈아탄 사용자가 명령 하나로 기존 설정을 이관한다.
사용자는 `/migrate` 한 번으로 규칙·MCP·스킬·훅·권한 설정을 Claude Code 위치에 맞게 옮기고,
못 옮긴 항목은 수동 조치 목록으로 받는다.

## 포지셔닝 (리서치 근거)

- Claude→Codex 방향은 포화 상태다. OpenAI 공식 migrate-to-codex 스킬, Codex CLI 네이티브 `/import`(v0.145+), 커뮤니티 도구 6개 이상.
- Codex→Claude 방향(into-Claude)은 2026-08 현재 전용 도구가 없다. 부분 커버 도구 1개(MCP·세션만)와 세션 전용 도구뿐.
- 이 스킬은 into-Claude 마이그레이션을 전담한다. 변환 엔진은 AI 자신이고, 도구별 지식은 markdown 문서로 관리한다.

## 범위

- 목적지: Claude Code (이 스킬이 실행되는 환경).
- v1 소스: Codex CLI, Cursor, Grok CLI.
- 후순위 소스 후보: Gemini CLI, Copilot, Windsurf, Cline/Roo, Aider. 소스 추가 = `sources/` 문서 1개 추가.
- 비범위(v1): 세션/대화 기록 이관, API 키·auth 파일 이관, 목적지가 Claude가 아닌 방향.

## 명령 UX

```
/migrate           설치된 소스 도구 자동 감지 → 선택 후 이관
/migrate codex     Codex에서 이관
/migrate cursor    Cursor에서 이관
/migrate grok      Grok에서 이관
```

- 스킬 이름은 `migrate` (kebab-case, 공백 불가). 소스는 `$ARGUMENTS`로 받는다.
- 자동 감지: `~/.codex`, `~/.cursor`, `~/.grok` 등 알려진 설정 경로 존재 여부를 훑고, 발견된 도구를 사용자에게 제시한다.

## 아키텍처

```
migrate/
  SKILL.md               진입점. 5단계 절차 오케스트레이션. 소스 인자 파싱과 자동 감지 로직
  sources/
    codex.md             Codex 매핑 지식 (아래 매핑표 수록)
    cursor.md            Cursor 매핑 지식 (구현 단계에서 리서치로 작성)
    grok.md              Grok 매핑 지식 (구현 단계에서 리서치로 작성)
    _template.md         새 소스 추가용 템플릿 (섹션: 설정 인벤토리, 매핑표, 시크릿 위치, 함정)
  references/
    claude-target.md     Claude 쪽 쓰기 규칙 (직접 쓰기 허용 파일 vs CLI 경유 항목)
    security.md          시크릿 탐지 패턴과 처리 정책
```

- 허브-스포크 구조. 소스별 지식 문서가 스포크, Claude 타겟 문서와 절차가 허브.
- 파서·변환 코드는 두지 않는다. AI가 지식 문서를 읽고 직접 변환한다.
- 배포: 개인 스킬(`~/.claude/skills/migrate/`)로 시작, 이후 `.claude-plugin/plugin.json` 패키징으로 `/plugin install` 배포.

## 실행 흐름 (5단계)

1. **Scan** — 소스 지식 문서 기준으로 설정 파일 인벤토리. 시크릿 파일(auth.json 등)은 존재만 확인, 내용 접근 금지.
2. **Plan** — 카테고리별 분류 제시: 자동 이관 / 손실 매핑(근사치) / 이관 불가(수동 조치).
3. **Confirm** — 사용자 승인. 카테고리 단위 제외 선택 가능. 승인 전 어떤 쓰기도 하지 않는다.
4. **Apply** — 대상 파일 백업(`.bak-<timestamp>`) 후 병합. 덮어쓰기 금지. MCP 등록은 `~/.claude.json` 직접 수정 대신 `claude mcp add` CLI 경유(공식 문서 권고).
5. **Report** — 이관 완료 / 근사 매핑 상세 / 수동 조치 목록(시크릿 재입력 등) 출력. 검증 명령(`claude mcp list` 등) 실행 결과 포함.

## Codex 매핑표 (리서치 검증 완료)

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

Cursor·Grok 매핑표는 구현 단계에서 동일 형식으로 리서치 후 작성한다. Grok CLI는 설정 표면이 덜 표준화되어 있어 커버 범위가 좁으면 리포트에 명시한다.

## 안전 정책

- auth·API 키·`.env`류 파일은 읽기·복사 금지. 존재 확인만.
- MCP env/headers 등 설정 안의 시크릿 패턴 값은 마스킹하고 "재입력 필요" 목록으로 리포트한다. 평문 복사 금지.
- 쓰기 전 대상 파일 백업 필수. 병합만 하고 덮어쓰기 금지.
- 기존 Claude 설정과 충돌하는 항목은 자동 결정하지 않고 사용자에게 묻는다.
- Confirm 단계 승인 전에는 파일 시스템 변경 금지.

## 검증 방법

- 격리 테스트: `CLAUDE_CONFIG_DIR`을 임시 디렉토리로 지정해 스킬 실행 → 산출 파일(설정 JSON 유효성, CLAUDE.md 병합 결과, 스킬 복사 결과) 검사.
- 실기기 테스트: 이 머신의 실제 `~/.codex` 설정을 첫 테스트 케이스로 사용 (Confirm 단계에서 중단하는 dry-run 우선).
- MCP 등록 검증: `claude mcp list` 출력으로 확인.

## 구현 순서

1. `SKILL.md` 골격 + `references/` 2개 + `sources/codex.md` (매핑 완료분) → Codex 경로 end-to-end 완성.
2. `sources/cursor.md` 리서치·작성 → Cursor 경로.
3. `sources/grok.md` 리서치·작성 → Grok 경로.
4. 자동 감지 모드 마감, 플러그인 패키징.
