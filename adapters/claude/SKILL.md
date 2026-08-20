---
name: migrate
description: Migrate settings from another AI coding tool (Codex, Cursor, Grok) into Claude Code — rules, MCP servers, skills, subagents, hooks, permissions. Use when the user asks to import or migrate settings from another AI tool, or runs /migrate [source].
---

# migrate — AI 설정 마이그레이션 (목적지: Claude Code)

너는 목적지 도구(Claude Code) 안에서 실행 중이다. 소스 도구의 설정을 이 도구로 이관한다.

## 0. 입력 해석

- 스킬 디렉토리 = 이 `SKILL.md` 파일이 있는 디렉토리(통상 `~/.claude/skills/migrate/`). 아래의 모든 `core/...` 경로는 이 디렉토리 기준 상대 경로다.
- 소스 = `$ARGUMENTS` 에서 찾은 도구 이름 (`codex` | `cursor` | `grok`). 인자가 `/migrate codex` 처럼 토큰 하나면 그 단어를, 자연어 문장이면 문장 안에 언급된 도구 이름을 쓴다.
- 해당 소스의 문서가 `core/tools/` 에 없으면 지원 예정이라고 알리고 중단한다.
- 소스 루트 = 소스 도구 문서의 기본 홈. 사용자가 소스 루트 경로를 명시하면 그 경로를 대신 쓴다.
- 타겟 루트 = 실제 Claude 환경 (`~/.claude` 등, `core/tools/claude.md` 기준). 사용자가 타겟 루트를 명시하면 그 경로를 쓰고 **테스트 모드**로 전환한다 (`core/tools/claude.md` 의 "MCP 명령 실행 규칙" 참조).
- 소스도 소스 루트도 특정되지 않았을 때만 자동 감지한다. `~/.codex`, `~/.cursor`, `~/.grok` 존재 여부를 확인해 발견된 도구를 사용자에게 제시하고 고르게 한다(목적지 자신은 제외). 사용자에게 물을 수 없으면 추측하지 말고 중단한다.

## 1. 지식 로드 (스킬 디렉토리 기준, 전부 필수)

1. `core/security.md` — 최우선 정책
2. `core/procedure.md` — 실행 절차
3. `core/tools/<source>.md` — 소스 읽기·변환 규칙
4. `core/tools/claude.md` — 타겟 쓰기 규칙

## 2. 실행

`core/procedure.md` 의 Scan → Plan → Confirm → Apply → Report 를 순서대로 수행한다.
