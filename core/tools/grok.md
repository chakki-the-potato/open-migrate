# Grok Build (xAI)

홈: `~/.grok` (`GROK_HOME` 환경변수로 재지정 가능). 메인 설정은 `~/.grok/config.toml` 하나이며 규칙·스킬·서브에이전트·훅만 별도 디렉토리를 쓴다. 이 문서는 소스로 읽을 때와 타겟으로 쓸 때 모두 사용한다.

대상은 xAI 공식 **Grok Build**(`grok`)다. 이름이 비슷한 커뮤니티 CLI(`superagent-ai/grok-cli`, npm `grok-dev`)는 설정 저장 위치가 완전히 다르다(`~/.grok/user-settings.json` 의 `mcp.servers`·`hooks`) — **이 문서를 그 도구에 적용하지 마라.** 홈에 `config.toml` 없이 `user-settings.json` 만 있으면 Grok Build 가 아니므로 중단하고 사용자에게 알린다.

Grok Build 는 다른 도구의 합집합처럼 생겼다 — **훅과 권한은 Claude 와 같은 모양**이고 **MCP 와 env 주입은 Codex 와 같은 모양**이다. 변환 규칙 대부분이 "그대로 옮긴다" 인 이유가 이것이다.

## 감지

`~/.grok/config.toml` 존재 시 설치된 것으로 판단. `GROK_HOME` 이 설정돼 있으면 그 경로를 홈으로 쓴다.

## 설정 인벤토리 (읽기)

| 카테고리 | 위치 | 포맷 |
|---|---|---|
| 전역 규칙 | `~/.grok/rules/*.md` 전부(파일명 무관, 알파벳순 로드) + `~/.grok/AGENTS.md` | markdown 평문. 홈에서 인식되는 named 파일은 `AGENTS.md`·`AGENT.md`·`CLAUDE.md`·`CLAUDE.local.md` 등이다 — **`GROK.md` 는 읽지 않는다** |
| MCP | `~/.grok/config.toml` `[mcp_servers.<name>]` | TOML. Codex 와 같은 모양: stdio 는 `command`/`args` + 하위 테이블 `[mcp_servers.<name>.env]`, remote 는 `url` + `[mcp_servers.<name>.http_headers]`. `enabled = false` 로 비활성 |
| 스킬 | `~/.grok/skills/<name>/SKILL.md` | agent-skills 표준 레이아웃(지원 파일 포함). frontmatter `user-invocable: true` 면 슬래시 명령으로 노출 |
| 커맨드/프롬프트 | **표면 없음** | 전용 커맨드 디렉토리가 없다 — 슬래시 명령은 스킬로 만든다 |
| 서브에이전트 | `~/.grok/agents/<name>.md` | YAML frontmatter(**camelCase**) + 본문(시스템 프롬프트). 필수 `name`·`description`. 선택 `promptMode`(`extend`\|`full`)·`capabilityMode`·`permissionMode`·`tools`·`disallowedTools`·`effort`·`maxTurns`·`isolation`·`background`·`color`·`skills`·`initialPrompt`·`mcpServers` 등 |
| 훅 | `~/.grok/hooks/*.json` (그리고 `config.toml` 인라인) | **JSON 구조가 Claude Code 와 같다**: `{"hooks": {"<Event>": [{"matcher": "...", "hooks": [{"type": "command", "command": "...", "timeout": 10}]}]}}`. 이벤트명도 PascalCase. `timeout` 단위는 초 |
| 권한 규칙 | `~/.grok/config.toml` `[permission]` | 두 형태가 있다. (1) 컴팩트 문자열 배열 `allow`/`ask`/`deny` — 규칙 문자열이 **Claude 와 같은 문법**(`Bash(git status:*)`, `Read(src/**)`, `Edit(**/*.rs)`, `Grep`, `WebFetch(domain:example.com)`, `MCPTool(server__tool)`). (2) 구조적 `rules = [{ action = "allow\|deny\|ask", tool = "bash\|read\|edit\|grep\|mcp\|webfetch\|websearch", pattern = "git *" }]`. 병합 우선순위는 deny > ask > allow |
| env 주입 | `~/.grok/config.toml` `[shell_environment_policy]` | Codex 와 같은 테이블명·구조. 주입할 값은 하위 테이블 `[shell_environment_policy.set]` |
| 승인 정책 | `~/.grok/config.toml` `[ui] permission_mode` | 값: `default`(ask)·`acceptEdits`·`auto`·`dontAsk`·`bypassPermissions`(제품명 always-approve)·`plan` |
| 모델 | `~/.grok/config.toml` `model` | 이관하지 않음 — 리포트에 키와 **현재 값**을 그대로 인용해 안내 |
| 읽지 말 것 | `~/.grok/auth.json`, `~/.grok/sessions/`, `~/.grok/memory/` | security.md 적용. `memory/` 는 평문 markdown 이라 기술적으로는 복사 가능하지만 설정이 아니라 대화 내용이므로 **기본 제외**한다 |

## 변환 규칙 (Grok → 다른 도구)

### 전역 규칙
- `rules/*.md` 와 `AGENTS.md` 를 모두 읽어 타겟의 전역 규칙 파일에 원문 그대로 병합(요약·재작성 금지). 파일이 여러 개면 `### <파일명>` 하위 헤딩으로 구분하고 **알파벳순(= Grok 의 실제 로드 순서)** 을 유지한다.
- `@경로` import 줄은 펼치지 말고 원문 그대로 옮긴다.
- `GROK.md` 처럼 Grok 이 인식하지 않는 파일명은 **이관 대상이 아니다** — 발견해도 옮기지 말고 "Grok 이 읽지 않는 파일" 로만 리포트에 기록한다.

### MCP
- `[mcp_servers.<name>]` → 타겟 MCP 형식. Codex 와 테이블 모양이 같으므로 codex.md 의 MCP 변환 규칙을 그대로 적용한다.
- `enabled = false` 서버는 이관하지 않고 리포트에 기록.
- `[mcp_servers.<name>.http_headers]` 와 `.env` 값은 security.md 시크릿 탐지 대상.

### 스킬
- `SKILL.md` 디렉토리를 지원 파일까지 그대로 복사.
- `user-invocable: true` 는 Grok 전용 frontmatter 키다. 타겟이 같은 키를 쓰지 않으면 **그 키만 드롭하고 나머지 frontmatter 와 본문은 유지**한 뒤 리포트에 기록한다.

### 서브에이전트
- frontmatter 가 camelCase 다. `name`·`description` 은 어느 도구에서나 공통이므로 그대로 매핑한다.
- `model` 은 값 공간이 도구마다 다르다 — 타겟 문서의 서브에이전트 규칙을 따른다(`inherit` 처럼 양쪽 공통인 값만 그대로 옮기고, 나머지는 드롭 후 리포트).
- `tools`/`disallowedTools` 는 타겟에 도구 허용목록 개념이 있을 때만 옮긴다.
- Grok 전용 필드(`promptMode`·`capabilityMode`·`permissionMode`·`discoverSkills`·`inheritSkills`·`agentsMd`·`injectDefaultTools`·`maxTurns`·`isolation`·`background`·`initialPrompt`·`mcpServers`)는 타겟에 대응 필드가 없으면 드롭 후 리포트에 기록.

### 훅
- **구조 변환이 필요 없다.** Grok 훅 파일의 `hooks` 객체는 Claude `settings.json` 의 `hooks` 값과 같은 모양이다 — Claude 가 타겟이면 그 객체를 꺼내 그대로 병합한다.
- Grok 이벤트 15종: `SessionStart`, `SessionEnd`, `UserPromptSubmit`, `Stop`, `StopFailure`, `StopCancelled`, `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `PermissionDenied`, `SubagentStart`, `SubagentStop`, `Notification`, `PreCompact`, `PostCompact`.
- 이벤트 처리는 **타겟 문서를 따른다** — Codex 는 공식 11개 밖을 드롭하고(codex.md), Cursor 는 camelCase 8개로 변환한다(cursor.md). 이 목록에 없는 이벤트명은 추측하지 말고 드롭 후 기록.
- `type` 은 `command` 와 `http` 두 가지다. `http` 타입은 다른 도구에 등가물이 없다 — 드롭 후 리포트.
- 매처는 도구명이며 Claude 와 같은 이름(`Bash`·`Read`·`Edit`·`Write`·`Grep`)을 쓴다 — Claude 로 갈 때 무변환, 그 외 타겟은 해당 문서의 도구명 매처 매핑을 적용한다.

### 권한 규칙
- 컴팩트 문자열 형태(`allow`/`ask`/`deny` 배열)는 **Claude 와 문법이 같다 — 값을 그대로 옮긴다.** `ask` 티어도 양쪽에 있어 손실이 없다.
- 구조적 형태(`rules = [{action, tool, pattern}]`)로 적혀 있으면 먼저 컴팩트 문자열로 정규화한다. `tool` 을 PascalCase 도구명으로 바꾸고(`bash`→`Bash`, `read`→`Read`, `edit`→`Edit`, `grep`→`Grep`, `webfetch`→`WebFetch`, `websearch`→`WebSearch`, `mcp`→`MCPTool`) `pattern` 을 괄호에 넣어 `<Tool>(<pattern>)` 을 만든 뒤 `action` 에 해당하는 배열에 넣는다. `pattern` 이 없으면 괄호 없이 도구명만 쓴다(`Grep`).
- 타겟별 손실은 타겟 문서를 따른다 — Cursor 에는 `ask` 티어가 없고(cursor.md), Codex 는 Bash prefix 규칙만 표현할 수 있다(codex.md).

### env 주입
- `[shell_environment_policy.set]` → 타겟의 전역 env 표면. Codex 와 같은 구조이므로 codex.md 의 env 규칙을 그대로 적용한다.
- Cursor 처럼 전역 env 표면이 없는 타겟으로 갈 때는 이관 불가 — 키 이름과 소스 위치를 수동 조치 목록에 기록한다.

### 승인 정책
- `[ui] permission_mode` → procedure.md 의 근사 매핑표를 리포트 제안으로만 사용한다. 자동 설정 금지.

## 쓰기 규칙 (Grok이 타겟일 때)

| 카테고리 | 쓰기 위치 | 방법 |
|---|---|---|
| 전역 규칙 | `~/.grok/AGENTS.md` | 파일 끝에 `## Migrated from <source> (<date>)` 섹션으로 **원문 그대로** 병합(요약·재작성 금지). 소스와 기존 파일의 `@import` 줄 모두 원문 유지. 기존 내용 삭제 금지. 쓰기 전 원본을 `.migrate/<run-id>/backup/AGENTS.md` 로 복사. `rules/` 에는 쓰지 않는다 — 한 파일로 모으는 편이 추적이 쉽고, `rules/*.md` 는 전부 로드되므로 어디에 써도 효력은 같다 |
| MCP | `config.toml` `[mcp_servers.<name>]` | stdio: `command`/`args` + `[mcp_servers.<name>.env]`. remote: `url` + `[mcp_servers.<name>.http_headers]`. 시크릿 값은 `<REDACTED-REENTER>` 로 두고 수동 조치 목록에 기재. **동명 서버가 이미 있으면 덮어쓰지 말고 건너뛴 뒤 리포트에 기록** |
| 스킬 | `~/.grok/skills/<name>/` | 디렉토리째 복사(지원 파일 포함). **동명 스킬이 있으면 건너뛰고 리포트에 기록** |
| 커맨드/프롬프트 | `~/.grok/skills/<name>/SKILL.md` (커맨드가 아니라 스킬로 이관) | Grok 에는 커맨드 표면이 없다. 소스 커맨드를 `name`/`description` frontmatter 로 감싸 스킬로 변환하고, 슬래시 명령으로 쓰려면 `user-invocable: true` 를 함께 넣는다. `name` 은 소스 파일명(확장자 제외). 소스에 `description` 이 없으면 지어내지 말고 본문 첫 문장을 그대로 쓰고 합성했다는 사실을 리포트에 기록한다. 소스의 `$1`-`$9`/`$ARGUMENTS` 치환 토큰은 원문 그대로 둔다 |
| 서브에이전트 | `~/.grok/agents/<name>.md` | YAML frontmatter는 **camelCase** 로 쓴다. `name`·`description` 은 그대로. 소스의 스네이크·케밥 표기 키는 camelCase 로 바꾼다. 타겟에 대응 필드가 없는 소스 전용 키(Claude `color`, Cursor `readonly`·`is_background` 등)는 드롭 후 리포트. **동명 파일이 있으면 덮어쓰지 말고 건너뛴 뒤 리포트에 기록** |
| 훅 | `~/.grok/hooks/migrated.json` | 최상위 구조는 반드시 `{"hooks": {...}}`. Claude 소스면 `settings.json` 의 `hooks` 값을 **무변환으로** 넣는다. 기존 파일이 있으면 배열에 append 하고 동일 command 는 스킵. 위 이벤트 15종 밖의 이름은 드롭 후 리포트. `type` 이 `command`·`http` 가 아닌 항목도 드롭 후 리포트 |
| 권한 | `config.toml` `[permission]` 의 `allow`/`ask`/`deny` 배열 | Claude 소스면 규칙 문자열을 **그대로** append(중복 제거). Cursor 소스면 `Shell(...)` → `Bash(...)` 로 개명한다(cursor.md 권한 규칙과 같은 개명). Codex 소스면 `prefix_rule(pattern=["git","status"], decision="allow")` → `Bash(git status:*)` 로 되돌린다 — 토큰을 공백으로 잇고 `:*` 를 붙이며, decision `prompt`→`ask`, `forbidden`→`deny` 로 매핑한다. 구조적 `rules = [...]` 형태로는 쓰지 않는다(컴팩트 배열이 소스 문법과 더 가깝다) |
| env 주입 | `config.toml` `[shell_environment_policy.set]` | 키 단위 병합, 기존 키 보존. 값이 다른 동명 키는 자동 결정하지 않고 사용자에게 묻는다 |
| 승인 정책 | — | `[ui] permission_mode` 를 **자동 설정하지 않는다.** 근사 매핑은 리포트 제안으로만 |

## TOML 설정 파일 병합 규칙

`config.toml` 은 TOML 이다. JSON 처럼 범용 병합 도구를 쓸 수 없으므로 아래를 따른다.

1. 수정 전 원본을 `.migrate/<run-id>/backup/config.toml` 로 복사한다.
2. **기존 줄을 재작성하지 않는다.** 새 테이블(`[mcp_servers.<name>]` 등)은 파일 끝에 append 하고, 기존 테이블에 키를 추가할 때는 그 테이블 블록 안에만 줄을 넣는다. 전체를 파싱해 다시 직렬화하면 주석과 키 순서가 사라진다.
3. 값 인용: 문자열 값은 큰따옴표로 감싼다. 불리언·정수는 따옴표 없이 쓴다. 배열 원소가 문자열이면 각각 큰따옴표로 감싼다.
4. 쓰기 후 TOML 유효성을 확인한다(`python3 -c "import tomllib,sys;tomllib.load(open(sys.argv[1],'rb'))" config.toml`). 실패 시 백업을 복원하고 중단·보고한다.
