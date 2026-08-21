---
name: migrate
description: Migrate settings between AI coding tools (Claude Code, Codex CLI, Cursor, Grok Build) — rules, MCP servers, skills, subagents, hooks, permissions. Use when the user asks to import or migrate settings from another AI tool, or runs /migrate [source].
---

# migrate — AI 설정 마이그레이션 (플러그인 배포본)

소스 도구의 설정을 **지금 이 스킬이 실행되고 있는 도구**로 이관한다.

이 배포본은 플러그인 마켓플레이스로 설치되며, Claude Code 와 Codex CLI 양쪽이 같은 패키지를 무변환으로 설치한다. 그래서 목적지가 고정되어 있지 않고 0단계에서 판정한다. (Cursor·Grok 은 저장소의 `./install.sh <dest>` 로 설치하며, 그쪽은 목적지가 고정된 전용 진입점을 쓴다.)

## 0. 입력 해석

### 0-1. 목적지 판정 (먼저 한다)

목적지는 **너 자신이 실행 중인 도구**다. 스킬 디렉토리 경로로 판정한다.

- 경로에 `.claude` 가 있으면 목적지는 `claude`.
- 경로에 `.codex` 가 있으면 목적지는 `codex`.
- 둘 다 아니거나 둘 다 해당하면 **추측하지 말고** 사용자에게 어느 도구에서 실행 중인지 묻는다.

판정한 목적지를 아래에서 `<target>` 으로 쓴다. `core/tools/<target>.md` 가 없으면 지원 예정이라고 알리고 중단한다.

### 0-2. 나머지 입력

- 스킬 디렉토리 = 이 `SKILL.md` 파일이 있는 디렉토리. 아래의 모든 `core/...` 경로는 이 디렉토리 기준 상대 경로다.
- 소스 = 사용자 입력에서 찾은 도구 이름 (`claude` | `codex` | `cursor` | `grok`, 단 목적지 자신은 제외). `/migrate codex` 처럼 토큰 하나면 그 단어를, 자연어 문장이면 문장 안에 언급된 도구 이름을 쓴다. 인자 치환이 비어 있으면 메시지 본문에서 찾는다.
- 해당 소스의 문서가 `core/tools/` 에 없으면 지원 예정이라고 알리고 중단한다.
- 소스 루트 = 소스 도구 문서의 기본 홈. 사용자가 소스 루트 경로를 명시하면 그 경로를 대신 쓴다.
- 타겟 루트 = `core/tools/<target>.md` 가 정한 실제 홈. 사용자가 타겟 루트를 명시하면 그 경로를 쓰고 **테스트 모드**로 전환한다(procedure.md "테스트 모드의 경로 해석" 참조).
- 소스도 소스 루트도 특정되지 않았을 때만 자동 감지한다. `~/.claude`, `~/.codex`, `~/.cursor`, `~/.grok` 존재 여부를 확인해 발견된 도구를 사용자에게 제시하고 고르게 한다(목적지 자신은 제외). 사용자에게 물을 수 없으면 추측하지 말고 중단한다.

## 1. 지식 로드 (스킬 디렉토리 기준, 전부 필수)

1. `core/security.md` — 최우선 정책
2. `core/procedure.md` — 실행 절차
3. `core/tools/<source>.md` — 소스 읽기·변환 규칙
4. `core/tools/<target>.md` — 타겟 쓰기 규칙
5. 위 문서가 다른 도구 문서로 규칙을 위임하면(예: "codex.md 의 MCP 변환 규칙을 그대로 적용한다") **그 문서도 읽는다.** 위임을 따라가지 않으면 규칙의 절반만 아는 상태가 된다.

## 2. 실행

`core/procedure.md` 의 Scan → Plan → Confirm → Apply → Report 를 순서대로 수행한다.
