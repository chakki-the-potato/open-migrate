---
name: migrate
description: Migrate settings from another AI coding tool (Codex, Cursor, Grok) into Claude Code — rules, MCP servers, skills, subagents, hooks, permissions. Use when the user asks to import or migrate settings from another AI tool, or runs /migrate [source].
---

# migrate — AI 설정 마이그레이션 (목적지: Claude Code)

너는 목적지 도구(Claude Code) 안에서 실행 중이다. 소스 도구의 설정을 이 도구로 이관한다.

## 0. 입력 해석

- 소스 = "$ARGUMENTS" 의 첫 단어 (`codex` | `cursor` | `grok`).
- 인자가 없으면 자동 감지: `~/.codex`, `~/.cursor`, `~/.grok` 존재 여부를 확인해 발견된 도구를 제시하고 사용자에게 하나를 고르게 한다 (목적지 자신은 제외).
- 해당 소스의 문서가 `core/tools/` 에 없으면 지원 예정이라고 알리고 중단한다.
- 소스 루트 = 소스 도구 문서의 기본 홈. 사용자가 메시지에서 소스 루트 경로를 명시하면 그 경로를 대신 사용한다.
- 타겟 루트 = 실제 Claude 환경 (`~/.claude` 등, core/tools/claude.md 기준). 사용자가 메시지에서 테스트용 타겟 루트를 명시한 경우에만 그 경로를 사용하고, MCP 등록을 명령 목록 산출 모드로 전환한다.

## 1. 지식 로드 (이 스킬 디렉토리 기준, 전부 필수)

1. `core/security.md` — 최우선 정책
2. `core/procedure.md` — 실행 절차
3. `core/tools/<source>.md` — 소스 읽기·변환 규칙
4. `core/tools/claude.md` — 타겟 쓰기 규칙

## 2. 실행

core/procedure.md 의 Scan → Plan → Confirm → Apply → Report 를 순서대로 수행한다.
Confirm 에서 사용자 승인 전에는 어떤 파일도 쓰지 않는다.
