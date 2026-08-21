# Codex CLI (OpenAI)

홈: `$CODEX_HOME` (기본 `~/.codex`). 이 문서는 소스로 읽을 때와 타겟으로 쓸 때 모두 사용한다.

## 감지

`~/.codex/config.toml` 또는 `~/.codex/AGENTS.md` 존재 시 설치된 것으로 판단.

## 설정 인벤토리 (읽기)

| 카테고리 | 위치 | 포맷 |
|---|---|---|
| 전역 규칙 | `AGENTS.override.md` 가 있으면 **그것만** 읽고 `AGENTS.md` 는 완전히 무시. 없을 때만 `AGENTS.md` | markdown, `@경로` import 지원. 무시된 `AGENTS.md` 의 내용은 이관·병합은 물론 리포트에도 인용하지 않는다 |
| MCP | `config.toml` `[mcp_servers.<name>]` | TOML. stdio: command/args/env. HTTP는 `url` 키 존재로 판별 (+선택: http_headers/bearer_token_env_var). `enabled=false`는 비활성 |
| 스킬 | `skills/<name>/SKILL.md` | agent-skills 표준. 그대로 복사 가능. 단 `skills/.system/` 하위(도구 내장)는 제외하고, 벤더 배포물(LICENSE/NOTICE 동반)이나 플러그인 공급 스킬은 사용자 소유가 아니므로 리포트에 구분해 표시한 뒤 이관 여부를 사용자가 정하게 한다 |
| 커스텀 프롬프트 | `prompts/*.md` (deprecated) | 평문 markdown, `$1`-`$9`/`$ARGUMENTS` 치환 |
| 훅 | `hooks.json` (주 위치) 또는 `config.toml` `[[hooks.Event]]` 인라인 정의 | Claude와 동일 JSON 구조. 주의: `config.toml` 의 `[hooks.state]` 는 훅 정의가 아니라 신뢰 해시 캐시다 — 이관 대상이 아니며 타겟에서 재생성된다 |
| 권한 규칙 | `rules/*.rules` | Starlark `prefix_rule(pattern=[...], decision=...)` |
| 서브에이전트 | `agents/*.toml` | TOML: `description`, `developer_instructions` |
| env 주입 | `config.toml` `[shell_environment_policy]` — `set` 테이블만 이관. `inherit`·`exclude`·`include_only` 는 값 주입이 아니라 상속 정책이라 대응 개념을 가진 타겟이 없다(Grok 은 같은 테이블명을 쓰지만 그쪽도 정책 필드다) → 리포트에 이관 불가로 기록 | TOML |
| 승인 정책 | `config.toml` `approval_policy`, `sandbox_mode` | 근사 매핑만 |
| 모델/개성 | `config.toml` `model`, `personality` 등 최상위 키 | 이관 안 함 — 리포트에 키와 **현재 값**을 그대로 인용해 안내 |
| 프로젝트 신뢰 | `config.toml` `[projects."<path>"]` | 이관 불가 — 안내만 |
| 플러그인/마켓 | `config.toml` `[plugins."<name>@<market>"]`, `[marketplaces.*]`, `plugins/cache/` | 이관하지 않음 — 플러그인은 마켓플레이스에서 재설치해야 한다. 다만 **스킬·서브에이전트·훅의 상당수가 플러그인이 공급한 것**이므로, 이관 전에 어떤 항목이 플러그인 소유인지 확인하고 리포트에 마켓·플러그인 이름을 나열해 사용자가 재설치로 갈음할지 결정하게 한다 |
| 프로젝트 훅 | `<repo>/.codex/hooks.json` | 전역 이관 범위 밖 — 존재를 발견하면 리포트에 안내만 |
| 키바인딩 | `keybindings.json` | 명령 체계 상이 — 이관 불가, 안내만 |
| 읽지 말 것 | `auth.json`, `sessions/`, `history.jsonl`, `*.sqlite`, `.codex-global-state.json` | security.md 적용 |

## 변환 규칙 (Codex → 다른 도구)

### 훅
- 공식 이벤트 11개: SessionStart, SessionEnd, SubagentStart, SubagentStop, PreToolUse, PermissionRequest, PostToolUse, PreCompact, PostCompact, UserPromptSubmit, Stop. Claude와 전부 동명 — 이벤트명 무변환.
- **공식 11개 밖의 이벤트명이 hooks.json에 있으면** (Codex는 조용히 무시하는 죽은 설정): 타겟 도구 문서의 유효 이벤트 목록을 확인해 동명 이벤트가 존재하면 무변환 이관하고, 없으면 드롭 후 리포트에 기록한다. 예: `Notification`은 Codex 비공식이지만 Claude에 존재 — 이관.
- 도구명 매처: `apply_patch` → 타겟의 편집 도구. Claude·Grok 은 `Edit|Write` 두 도구로 갈라져 있으므로 정규식 대안으로 둘 다 매칭시키고, Cursor 는 `Write` 하나다. `shell`/`local_shell`/`exec_command` 변형 → Claude·Grok `Bash`, Cursor `Shell`. `mcp__server__tool`은 어느 타겟에서나 동일. **타겟 문서에 도구명 매핑표가 있으면 그 표가 우선한다.**
- timeout 단위는 초로 동일.

### 커스텀 프롬프트 (prompts/*.md → 타겟 커맨드)
- deprecated 표면이지만 존재하면 이관한다. **목적지와 형식은 타겟 문서가 정한다** — 타겟에 커맨드 표면이 있으면 그 파일로(Claude `commands/<name>.md`), 없으면 타겟 문서가 지정한 대체 표면으로 옮긴다(Cursor·Grok 은 스킬). 파일 내용은 그대로 옮긴다.
- `$1`-`$9`/`$ARGUMENTS` 치환 토큰은 **원문 그대로 유지**한다. 타겟이 치환을 지원하지 않으면 토큰이 문자 그대로 남는데, 그것이 손실이라는 사실만 리포트에 적고 본문을 고치지 않는다.

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

## 쓰기 규칙 (Codex가 타겟일 때)

| 카테고리 | 쓰기 위치 | 방법 |
|---|---|---|
| 전역 규칙 | `AGENTS.md` | 파일 끝에 `## Migrated from <source> (<date>)` 섹션으로 **원문 그대로** 병합(요약·재작성 금지). 소스와 기존 파일의 `@import` 줄 모두 원문 유지. 기존 내용 삭제 금지. 쓰기 전 원본을 `.migrate/<run-id>/backup/AGENTS.md` 로 복사. **주의: 타겟에 `AGENTS.override.md` 가 있으면 `AGENTS.md` 는 무시되므로**, 존재하면 병합을 멈추고 어느 파일에 쓸지 사용자에게 묻는다 |
| MCP | `config.toml` `[mcp_servers.<name>]` | stdio: `command`/`args`/`env`(하위 테이블 `[mcp_servers.<name>.env]`). HTTP: `url` + 필요 시 `[mcp_servers.<name>.http_headers]`. `Bearer` 인증이 아닌 API-Key 계열 헤더는 `bearer_token_env_var` 가 아니라 `http_headers` 에 쓴다. 시크릿 값은 `<REDACTED-REENTER>` 로 두고 수동 조치 목록에 기재. **동명 서버가 이미 있으면 덮어쓰지 말고 건너뛴 뒤 리포트에 기록** |
| 스킬 | `skills/<name>/` | 디렉토리째 복사(지원 파일 포함). 동명 스킬이 있으면 건너뛰고 리포트에 기록 |
| 커맨드/프롬프트 | `prompts/<name>.md` | 평문 markdown 그대로. `$1`-`$9`/`$ARGUMENTS` 치환 토큰 원문 유지. Codex 는 이 표면을 deprecated 로 두고 스킬을 권장하므로, 이관은 하되 리포트에 "스킬로 옮기는 것을 권장" 안내를 남긴다 |
| 서브에이전트 | `agents/<name>.toml` | 소스 파일명(또는 frontmatter `name`)이 **파일명**이 된다 — TOML 안에는 `name` 키를 쓰지 않는다. `description = "<소스 description>"`, `developer_instructions = '''<소스 본문>'''` |
| 훅 | `hooks.json` | 최상위 구조는 반드시 `{"hooks": {...}}` — 최상위 키가 틀리면 파일 전체가 무시된다. 기존 배열에 append, 동일 command 는 스킵 |
| 권한 | `rules/<name>.rules` | 아래 "권한 쓰기 문법" 참조 |
| env 주입 | `config.toml` `[shell_environment_policy.set]` | 키 단위 병합, 기존 키 보존 |
| 승인 정책 | — | `approval_policy`·`sandbox_mode` 를 **자동 설정하지 않는다.** 근사 매핑은 리포트 제안으로만 |

### 훅 이벤트 변환 (다른 도구 → Codex)

- Codex 공식 이벤트는 11개뿐이다: SessionStart, SessionEnd, SubagentStart, SubagentStop, PreToolUse, PermissionRequest, PostToolUse, PreCompact, PostCompact, UserPromptSubmit, Stop.
- **이 11개 밖의 이벤트는 전부 드롭하고 리포트에 기록한다.** Codex 가 조용히 무시해 죽은 설정이 되기 때문이다. Claude 의 `Notification`·`ConfigChange`·`PostToolUseFailure`·`WorktreeCreate` 등이 여기 해당한다.
- 예외: `PostToolUseFailure` 는 Codex `PostToolUse` 가 실패 시에도 발화하므로 PostToolUse 로 병합할 수 있다.
- 도구명 매처: Claude `Edit`·`Write` → `apply_patch`. Claude `Bash` → `Bash`(Codex 가 shell 계열을 이 이름으로 정규화한다). Claude 전용 도구(`Read`·`Grep`·`Glob`·`WebFetch`)는 Codex 에 1급 도구가 없어 죽은 패턴이 되므로 드롭 후 기록.
- `command` 외 타입(http·mcp_tool·prompt·agent)은 Codex 미지원 — 스킵 후 기록.

### 권한 쓰기 문법 (다른 도구 → Codex rules DSL)

- 파일은 `rules/` 아래 아무 이름이나 가능하다(예: `rules/migrated.rules`). 문법은 Starlark 다.
- 형식: `prefix_rule(pattern=["<토큰>", ...], decision="<결정>")` — **`decision` 값은 반드시 큰따옴표로 감싼 문자열이다.** 따옴표 없는 `decision=allow` 는 문법 오류다.
- decision 매핑: allow→`"allow"`, ask→`"prompt"`, deny→`"forbidden"`.
- 패턴 변환: `Bash(git status:*)` → `pattern=["git", "status"]`. 공백으로 토큰을 나누고 뒤의 `:*` 는 버린다.
- 여러 규칙이 앞부분을 공유해도 묶지 말고 각각 한 줄씩 쓴다 — 위치별 union(`["build", "test"]`)은 읽기 전용 최적화이며 쓰기 시 사용하지 않는다.
- **Bash prefix 규칙만 변환 가능하다.** 경로(`Read`/`Edit`)·도메인(`WebFetch`)·MCP 규칙, 그리고 중간 와일드카드가 필요한 패턴은 이 DSL 로 표현할 수 없다 — 변환하지 말고 수동 조치 목록에 원문 그대로 나열한다.
