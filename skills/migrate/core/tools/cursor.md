# Cursor (Anysphere)

홈: `~/.cursor`. MCP·스킬·서브에이전트·훅·권한·승인 정책은 모두 이 홈 아래에 위치한다. Rules(`.cursor/rules/*.mdc`)와 커맨드(`.cursor/commands/*.md`), 그리고 마이그레이션 타겟인 `AGENTS.md`는 프로젝트 루트 기준이며 홈 디렉토리 아래가 아니다. 이 문서는 소스로 읽을 때와 타겟으로 쓸 때 모두 사용한다.

## 감지

`~/.cursor/mcp.json` 또는 `~/.cursor/cli-config.json` 존재 시 설치된 것으로 판단.

## 설정 인벤토리 (읽기)

| 카테고리 | 위치 | 포맷 |
|---|---|---|
| 전역 규칙(Rules) | `.cursor/rules/*.mdc` (프로젝트 루트) **그리고** `AGENTS.md` (`~/.cursor/AGENTS.md` 및 프로젝트 루트) | frontmatter: `description`/`globs`/`alwaysApply` + markdown 본문. 같은 디렉토리의 순수 `.md` 파일은 Cursor가 무시한다 — Cursor 공식 문서는 순수 markdown 규칙에는 `AGENTS.md` 를 쓰라고 안내한다. Cursor는 `AGENTS.md`·`CLAUDE.md` 를 네이티브로 읽으므로 **`AGENTS.md` 도 전역 규칙 소스로 읽는다** — `.mdc` 가 하나도 없어도 `AGENTS.md` 가 있으면 그것이 규칙 소스다 |
| User Rules | 로컬 파일 없음 — Cursor 계정에 저장(클라우드 동기화) | 이관 불가 — 수동 안내만 |
| MCP | `~/.cursor/mcp.json` `mcpServers` | JSON. stdio: `command`/`args`/`env`/`envFile`. remote: `url`/`headers`. 서버명에 공백 허용. `${env:NAME}` 보간 지원. enabled/disabled 플래그 없음 |
| 스킬 | `~/.cursor/skills/<name>/SKILL.md` | agent-skills 표준 레이아웃. frontmatter: `name`/`description`/`paths`/`disable-model-invocation`/`metadata`. `$ARGUMENTS` 치환 없음. `~/.cursor/skills-cursor/` 는 앱 내장 콘텐츠 — 양방향 이관 대상 아님 |
| 커맨드/프롬프트 | `.cursor/commands/*.md` (프로젝트 루트) | deprecated — Cursor는 스킬 사용을 권장 |
| 서브에이전트 | `~/.cursor/agents/*.md` | frontmatter: `name`/`description`/`model`/`readonly`/`is_background` |
| 훅 | `~/.cursor/hooks.json` | JSON. 아래 "훅 파일 구조" 참조 — 최상위 `hooks` 는 **camelCase 이벤트명을 키로 갖는 객체**이고, 각 값이 훅 객체의 평면 배열이다(Claude 의 PascalCase + `{matcher, hooks:[...]}` 중첩과 다름) |
| 권한 규칙 | `~/.cursor/cli-config.json` `permissions.allow` / `permissions.deny` | 토큰 5종: `Shell(cmd)` / `Read(glob)` / `Write(glob)` / `WebFetch(domain)` / `Mcp(server:tool)`. 인자 매칭은 콜론 문법(예: `curl:*`) |
| env 주입 | 전역 env 표면 없음 | MCP 서버별 `env`/`envFile`(`~/.cursor/mcp.json`), `${env:NAME}` 보간만 존재 |
| 승인 정책 | `~/.cursor/cli-config.json` `approvalMode` | 값: `allowlist` / `auto-review` / `unrestricted` |
| 읽지 말 것 | credentials, `state.vscdb`, `projects/`, `extensions/` | security.md 적용 |

## 변환 규칙 (Cursor → 다른 도구)

### 전역 규칙 (Rules)
- `.cursor/rules/*.mdc` → 타겟의 전역 규칙 파일(Claude: `CLAUDE.md`, Codex: `AGENTS.md`)에 원문 그대로 병합(요약·재작성 금지). frontmatter(`description`/`globs`/`alwaysApply`)를 포함한 파일 전체를 옮긴다 — 펼치거나 frontmatter만 추출하지 않는다.
- `AGENTS.md`(`~/.cursor/AGENTS.md` 또는 프로젝트 루트) 도 같은 방식으로 옮긴다. Cursor 가 네이티브로 읽는 규칙 표면이므로 `.mdc` 와 동등하게 다룬다 — **`.mdc` 가 없다는 이유로 "이관할 규칙 없음" 으로 처리하지 마라.** 두 표면이 모두 있으면 둘 다 옮기고 파일별로 구분한다.
- 병합 섹션·하위 헤딩 형식은 procedure.md 의 "전역 규칙 병합 형식" 을 따른다(파일이 하나뿐이어도 `### <파일명>` 하위 헤딩을 붙인다).
- User Rules: 로컬에 존재하지 않아 자동 이관 불가 — 리포트에 "Cursor 계정의 User Rules를 직접 확인해 타겟에 옮길 것" 으로 안내만 남긴다.

### MCP
- `mcpServers.<name>` → 타겟 MCP 형식. stdio(`command`/`args`/`env`)와 remote(`url`/`headers`)는 그대로 매핑.
- `envFile` 은 파일을 열어 값을 인라인하지 않는다(시크릿 노출 위험) — 불가·수동 안내: 경로만 리포트에 기록.
- `${env:NAME}` 보간은 Cursor 전용 문법이라 타겟 쪽 동일 기능이 확인되지 않았다 — 값은 원문 그대로 옮기되 수동 확인 항목으로 표시.
- 서버명에 공백이 있으면 타겟의 이름 규칙(CLI 인자 vs 파일 키)에 맞게 인용 처리가 필요할 수 있다 — 수동 확인.
- `env`/`headers` 값은 security.md 시크릿 탐지 적용.

### 스킬
- `SKILL.md` 디렉토리를 타겟의 스킬 디렉토리로 그대로 복사.
- Cursor 스킬에는 애초에 `$ARGUMENTS` 치환이 없다 — 타겟이 인자 치환을 지원해도 채울 원문이 없다는 점만 기록(손실이 아니라 원래 없음).
- `~/.cursor/skills-cursor/` 는 앱 내장 콘텐츠이므로 이관 대상에서 제외.

### 커맨드/프롬프트
- deprecated 표면이지만 존재하면 이관: 파일 내용을 그대로 타겟의 커맨드 파일로 옮긴다.
- Cursor 커맨드에도 `$1`-`$9`/`$ARGUMENTS` 류 치환 토큰이 없다 — 타겟 형식이 지원해도 채울 원문이 없다는 점만 기록.

### 서브에이전트
- `agents/<name>.md` → 타겟 서브에이전트 형식. `name`/`description`은 그대로 매핑.
- `model`: Claude 서브에이전트 frontmatter에도 `model` 필드가 있다. 필드가 없어서가 아니라 **값 공간이 도구마다 달라서** 주의가 필요하다. `inherit` 은 양쪽 공통 값이므로 **그대로 옮긴다**(무손실). 그 외의 값은 타겟에서 유효한 별칭·모델 ID 임이 확인되지 않으면 필드를 드롭하고 리포트에 소스 값을 그대로 인용해 수동 확인 항목으로 남긴다. 값을 추측해 바꿔 쓰지 마라.
- `readonly`/`is_background`는 Claude 서브에이전트 frontmatter에 대응 필드가 없다 — 드롭 후 리포트에 기록.

### 훅
- 구조 변환: flat 배열의 camelCase 이벤트명을 타겟의 PascalCase 이벤트명(Claude/Codex 공통 11개)으로, 배열 항목 하나하나를 타겟의 `{matcher, hooks:[...]}` 형태로 감싼다.
- 이벤트명 매핑표는 아래 "훅 이벤트 매핑" 참고.
- 매처: `Glob`/`WebFetch`/`WebSearch` 는 Cursor 훅에 애초에 없는 매처라 이 방향에서는 옮겨올 대상 자체가 없다 — 이 셋은 반대 방향(쓰기 규칙)에서만 문제가 된다. 반면 **Cursor `Write` 매처는 이 방향에서 실제 손실이 있다** — 반대 방향 매핑에서 Claude `Write` 와 `Edit` 이 Cursor `Write` 하나로 합류하므로 역방향 복원이 유일하지 않다. 아래 도구명 매처 매핑의 Cursor → Claude/Codex 규칙을 따른다.

### 훅 이벤트 매핑

| Claude/Codex (PascalCase) | Cursor (camelCase) |
|---|---|
| `PreToolUse` | `preToolUse` |
| `PostToolUse` | `postToolUse` |
| `UserPromptSubmit` | `beforeSubmitPrompt` |
| `SessionStart` | `sessionStart` |
| `SessionEnd` | `sessionEnd` |
| `PreCompact` | `preCompact` |
| `Stop` | `stop` |
| `SubagentStop` | `subagentStop` |

`UserPromptSubmit` → `beforeSubmitPrompt` 만 단순 대소문자 변환이 아니다 — 나머지 7개는 첫 글자만 소문자로 바꾸면 된다.

- 미지원(대응 Cursor 이벤트 없음): `Notification`, 그리고 승인 요청 계열 이벤트 — 소스가 Claude 면 `PermissionDenied`, 소스가 Codex 면 `PermissionRequest` 다(두 도구가 서로 다른 이름을 쓴다 — claude.md 훅 행과 codex.md 공식 이벤트 목록 참조). 어느 쪽이든 드롭 후 리포트에 기록.
- 위 8개와 미지원 2개 밖의 이벤트명은 매핑을 추측하지 말고 드롭 후 수동 확인 항목으로 남긴다.
- 도구명 매처 매핑 (Claude → Cursor): `Bash`→`Shell`, `Read`→`Read`, `Write`→`Write`, `Edit`→`Write`, `Grep`→`Grep`, `Task`→`Task`. `Glob`·`WebFetch`·`WebSearch` 는 대응 매처가 없어 드롭 후 기록.
- 도구명 매처 매핑 (Codex → Cursor): Codex 는 도구 이름이 다르다 — `apply_patch`→`Write`, `Bash`→`Shell`(Codex 가 shell 계열을 `Bash` 로 정규화한다), `Task`→`Task`. 그 밖의 Codex 도구명은 Cursor 에 대응 매처가 없어 드롭 후 기록한다. **Claude 이름을 중간 표현으로 경유하지 마라** — 2단 변환은 매핑이 다대일인 지점에서 없던 손실을 만든다.
- 도구명 매처 매핑 (Grok → Cursor): Grok 은 Claude 와 같은 도구명을 쓰므로 위 Claude 행을 그대로 적용한다.
- 도구명 매처 매핑 (Cursor → Claude/Codex): `Shell`→`Bash`, `Read`→`Read`, `Grep`→`Grep`, `Task`→`Task`. `Write` 는 위 매핑에서 `Write` 와 `Edit` 두 개가 합류한 결과라 역방향이 유일하지 않다 — **`Edit|Write` 정규식 대안으로 되돌려 둘 다 매칭시킨다.** 둘 중 하나만 고르면 소스에 없던 좁힘이 생기므로 금지한다. 이 근사를 리포트에 기록한다.
- Cursor 전용 이벤트(`postToolUseFailure`, `beforeShellExecution`, `afterFileEdit` 등)는 Claude/Codex 에 등가물이 없다 — Cursor 가 소스일 때 드롭 후 기록.

### 훅 파일 구조

`hooks.json` 의 정확한 모양은 다음과 같다. 최상위 `hooks` 는 이벤트명을 키로 갖는 **객체**이고, 각 이벤트의 값은 훅 객체의 평면 배열이다. Claude 처럼 `{matcher, hooks:[...]}` 로 한 번 더 감싸지 않으며, 배열 원소 안에 `event` 필드를 넣지도 않는다.

```json
{
  "version": 1,
  "hooks": {
    "preToolUse": [
      { "command": "echo pre-edit-check", "type": "command", "timeout": 10, "matcher": "Write" }
    ],
    "sessionStart": [
      { "command": "echo hi", "type": "command" }
    ]
  }
}
```

- 훅 객체 필드: `command`(필수), `type`(`"command"` 또는 `"prompt"`), `timeout`(초), `matcher`(도구명 정규식), `failClosed`, `loop_limit`.
- Claude 의 `{matcher, hooks:[{command, timeout}]}` 하나는 Cursor 의 훅 객체 **여러 개**로 펼쳐진다 — 안쪽 `hooks` 배열의 원소마다 바깥 `matcher` 를 복사해 넣는다.
- **복합 매처 분해**: Claude 매처는 `Edit|Write` 처럼 정규식 대안을 담을 수 있다. `|` 로 토큰을 나눠 각각 도구명 매핑표를 적용한 뒤 중복을 제거한다(`Edit|Write` → 둘 다 `Write` → 최종 `Write` 하나). 매핑에서 드롭되는 토큰(`Glob`·`WebFetch`·`WebSearch`)만 남는 매처는 훅 전체를 드롭하고 리포트에 기록한다.

### 호환 로드 (이관이 아예 불필요할 수 있는 경우)

이 절은 **Cursor 가 타겟일 때만** 적용된다. Cursor 가 소스일 때는 무시한다.

Cursor 는 다른 도구의 설정 일부를 **변환 없이 직접 읽는다.** Scan 단계에서 이를 확인하고, 해당하면 이관 대신 "이미 읽히고 있음" 으로 리포트에 기록해 중복 설치를 피한다.

- 규칙: `AGENTS.md`·`CLAUDE.md` 를 네이티브로 읽는다.
- 스킬: `.claude/skills/`, `.codex/skills/`, `~/.claude/skills/`, `~/.codex/skills/` 를 호환 경로로 읽는다.
- 서브에이전트: `.claude/agents/`, `.codex/agents/`, `~/.claude/agents/`, `~/.codex/agents/` 를 읽는다.
- 훅: 설정에서 third-party 를 켜면 `.claude/settings.json`·`~/.claude/settings.json` 의 훅을 위 매핑표대로 자동 변환해 읽는다.

이 경로들은 사용자 설정에 따라 꺼져 있을 수 있으므로 자동으로 생략하지 않는다 — Confirm 단계에서 사용자에게 확인한다. 전체 승인처럼 되물을 수 없는 모드에서는 **생략하지 말고 이관한 뒤** 중복 가능성을 리포트에 기록한다.

### 권한 규칙
- `Shell(cmd)` → Claude `Bash(cmd)`: **토큰 이름을 반드시 개명한다.** 인자 매칭 문법(콜론 문법 `curl:*`)은 Claude `Bash(cmd:*)` 와 형태가 같아 그대로 유지하지만 도구 이름은 다르다 — Claude 에는 `Shell` 도구가 없어 `Shell(...)` 을 그대로 쓰면 아무것도 매칭하지 않는 무효 규칙이 된다. 예: `Shell(git status:*)` → `Bash(git status:*)`. 이 개명은 쓰기 규칙 표의 Cursor 권한 행(소스 `Bash(...)` → `Shell(...)`)과 정확히 역방향 한 쌍이며, 둘 중 하나만 적용하면 왕복이 깨진다. Codex로 갈 때는 codex.md의 "권한 쓰기 문법"(공백으로 토큰 분리, `:*` 제거, `prefix_rule(pattern=[...], decision="...")`)을 그대로 적용한다.
- `Read(glob)` → Claude `Read(glob)` 그대로.
- `Write(glob)` → Claude는 `Edit`/`Write` 두 도구로 분리돼 있어 근사가 필요하다: 대상이 신규 생성인지 기존 수정인지 불명확하면 `Edit(glob)`과 `Write(glob)` 양쪽에 추가하고 근사 매핑으로 리포트에 기록.
- `WebFetch(domain)` → Claude `WebFetch(domain)` 그대로.
- `Mcp(server:tool)` → Claude 측 정확한 MCP 권한 토큰 문법이 이 저장소 문서들에 명시돼 있지 않다 — 자동 변환하지 말고 원문을 수동 조치 목록에 그대로 나열.
- Codex 타겟: `Shell(cmd)` 외 나머지 4종(`Read`/`Write`/`WebFetch`/`Mcp`)은 Codex의 Starlark rules DSL로 표현할 수 없다(codex.md 참고) — 변환하지 말고 원문 그대로 수동 조치 목록에 나열.
- `approvalMode` → procedure.md의 근사 매핑표를 리포트 제안으로만 사용, 자동 설정 금지.

### env 주입
- Cursor에는 전역 env 표면이 없다 — Cursor가 소스일 때 이관할 전역 env 블록 자체가 존재하지 않는다(MCP 서버별 env는 위 MCP 규칙에서 이미 처리).

## 쓰기 규칙 (Cursor가 타겟일 때)

| 카테고리 | 쓰기 위치 | 방법 |
|---|---|---|
| 전역 규칙 | **홈 스코프에는 쓸 곳이 없다** — 아래 참조 | Cursor 에는 전역 규칙 **파일**이 없다. 전역 규칙에 해당하는 User Rules 는 계정에 저장되며 디스크에 쓸 수 없다. 따라서 (a) 사용자가 프로젝트 루트를 지정하면 그 루트의 `AGENTS.md` 에 `## Migrated from <source> (<date>)` 섹션으로 **원문 그대로** 병합(요약·재작성 금지, `@import` 줄 원문 유지, 기존 내용 삭제 금지, 쓰기 전 `.migrate/<run-id>/backup/AGENTS.md` 로 백업), (b) 프로젝트 루트가 없으면 **쓰지 말고** 규칙 원문을 수동 조치 목록에 실어 사용자가 Cursor 설정의 User Rules 에 직접 붙여넣게 안내한다. 어느 경우든 `.cursor/rules/*.md` 로는 쓰지 않는다 — Cursor 가 순수 `.md` 를 무시하기 때문이다 |
| MCP | `~/.cursor/mcp.json` `mcpServers.<name>` | stdio: `command`/`args`/`env`. remote: `url`/`headers`. **동명 서버가 이미 있으면 덮어쓰지 말고 건너뛴 뒤 리포트에 기록**. 시크릿 값은 `<REDACTED-REENTER>` 로 두고 수동 조치 목록에 기재. Cursor 전용 필드(`envFile`, `${env:NAME}` 보간)는 소스에 없으므로 쓰지 않는다 |
| 스킬 | `~/.cursor/skills/<name>/SKILL.md` | 디렉토리째 복사. **동명 스킬이 있으면 건너뛰고 리포트에 기록**. `~/.cursor/skills-cursor/` 에는 절대 쓰지 않는다(앱 전용 영역) |
| 커맨드 | `~/.cursor/skills/<name>/SKILL.md` (커맨드가 아니라 스킬로 이관) | `.cursor/commands/*.md` 는 deprecated이므로 신규 쓰기 대상에서 제외하고, 소스 커맨드를 `name`/`description` frontmatter로 감싸 스킬로 변환해 쓴다. `name` 은 소스 파일명(확장자 제외). 소스에 `description` 이 없으면 지어내지 말고 본문 첫 문장을 그대로 쓰고, 합성했다는 사실을 리포트에 기록한다. 소스의 `$1`-`$9`/`$ARGUMENTS` 치환 토큰은 Cursor 스킬에 대응 문법이 없어 **버려진다** — 손실로 리포트에 명시 |
| 서브에이전트 | `~/.cursor/agents/<name>.md` | frontmatter는 `name`/`description`/`model`/`readonly`/`is_background`만 쓴다. 소스가 Claude면 `tools`/`color`는 Cursor에 대응 필드가 없어 드롭 후 리포트. **동명 파일이 있으면 덮어쓰지 말고 건너뛴 뒤 리포트에 기록** |
| 훅 | `~/.cursor/hooks.json` | `version: 1`, flat 배열, camelCase 이벤트명으로 변환해 append(동일 command면 스킵). 이벤트명 매핑은 위 "훅 이벤트 매핑"의 확인된 범위만 적용 — 나머지는 매핑을 추측하지 말고 수동 확인 항목으로 남긴다. `Notification` 과 승인 요청 계열 이벤트(Claude `PermissionDenied` / Codex `PermissionRequest`)는 Cursor 미지원이므로 드롭 후 리포트. `Glob`/`WebFetch`/`WebSearch` 매처로 스코프된 훅은 대응 매처가 없어 드롭 후 리포트 |
| 권한 | `~/.cursor/cli-config.json` `permissions.allow` / `permissions.deny` | 토큰 개명: 소스의 Bash/셸 규칙(`Bash(git status:*)`, Codex `prefix_rule(["git","status"])`)은 `Shell(...)` 로 바꾼다 — 콜론 인자 문법(`:*`)은 그대로 유지한다. 소스가 Claude면 `Edit(glob)`과 `Write(glob)`이 둘 다 Cursor `Write(glob)` 하나로 합쳐진다 — 병합 후 자연히 중복 제거됨을 리포트에 안내. 배열에 append, 중복 제거. **`ask`/`prompt` 티어는 Cursor 에 없다** — 소스의 ask 규칙을 `allow` 나 `deny` 어디에도 넣지 말고(둘 다 원래 의미를 왜곡한다) 수동 조치 목록에 원문 그대로 올린다. `approvalMode`는 이미 값이 있어도 **바꾸지 않는다** — 근사 매핑표는 제안으로만 리포트에 기재 |
| env 주입 | — | Cursor에는 전역 env 표면이 없다 — 소스의 전역 env 블록(예: Claude `settings.json`의 `env`, Codex `[shell_environment_policy.set]`)은 **이관 불가**. 누락시키지 말고 수동 조치 목록에 키 이름과 소스 쪽 위치를 전부 기록해, 사용자가 MCP 서버별 `env`나 셸 프로파일로 직접 옮기게 안내한다 |
| 승인 정책 | — | `approvalMode`를 자동 설정하지 않는다. 근사 매핑은 procedure.md 매핑표를 리포트 제안으로만 사용 |

## JSON 설정 파일 병합 규칙

`mcp.json`, `hooks.json`, `cli-config.json` 은 모두 JSON이다.

1. 수정 전 원본을 `.migrate/<run-id>/backup/<파일명>` 으로 복사.
2. 깊은 병합(deep merge): 객체는 키 단위 병합, 배열은 append 후 중복 제거, 기존 스칼라 값은 보존. 동명 키(서버명·스킬명·파일명) 충돌은 자동 결정하지 않고 Confirm 단계에서 사용자에게 확인.
3. 쓰기 후 `jq -e . <파일명>` 으로 JSON 유효성 확인. 실패 시 백업 복원 후 중단·보고.
