# Codex CLI (OpenAI)

홈: `$CODEX_HOME` (기본 `~/.codex`). 이 문서는 소스로 읽을 때와 타겟으로 쓸 때 모두 사용한다.

## 감지

`~/.codex/config.toml` 또는 `~/.codex/AGENTS.md` 존재 시 설치된 것으로 판단.

## 설정 인벤토리 (읽기)

| 카테고리 | 위치 | 포맷 |
|---|---|---|
| 전역 규칙 | `AGENTS.override.md` 가 있으면 **그것만** 읽고 `AGENTS.md` 는 완전히 무시. 없을 때만 `AGENTS.md` | markdown, `@경로` import 지원. 무시된 `AGENTS.md` 의 내용은 이관·병합은 물론 리포트에도 인용하지 않는다 |
| MCP | `config.toml` `[mcp_servers.<name>]` | TOML. stdio: command/args/env. HTTP는 `url` 키 존재로 판별 (+선택: http_headers/bearer_token_env_var). `enabled=false`는 비활성 |
| 스킬 | `skills/<name>/SKILL.md` | agent-skills 표준. 그대로 복사 가능 |
| 커스텀 프롬프트 | `prompts/*.md` (deprecated) | 평문 markdown, `$1`-`$9`/`$ARGUMENTS` 치환 |
| 훅 | `hooks.json` 또는 `config.toml` `[[hooks.Event]]` | Claude와 동일 JSON 구조 |
| 권한 규칙 | `rules/*.rules` | Starlark `prefix_rule(pattern=[...], decision=...)` |
| 서브에이전트 | `agents/*.toml` | TOML: `description`, `developer_instructions` |
| env 주입 | `config.toml` `[shell_environment_policy]` — `set` 테이블만 이관. `inherit`·`exclude`·`include_only` 는 Claude 에 등가물 없음 → 리포트에 이관 불가로 기록 | TOML |
| 승인 정책 | `config.toml` `approval_policy`, `sandbox_mode` | 근사 매핑만 |
| 모델/개성 | `config.toml` `model`, `personality` 등 최상위 키 | 이관 안 함 — 리포트에 키와 **현재 값**을 그대로 인용해 안내 |
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
