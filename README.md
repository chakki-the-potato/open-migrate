# migrate

AI 코딩 도구를 갈아탈 때 설정을 한 번에 옮긴다. 규칙·MCP 서버·스킬·서브에이전트·훅·권한을 소스 도구에서 읽어 목적지 도구의 형식으로 변환한다.

지원 도구는 **Claude Code · Codex CLI · Cursor · Grok Build** 넷이고, 방향은 12가지다.

## 어떻게 동작하나

방향별 변환기를 12개 만들지 않는다. 도구마다 "내 설정을 읽는 법 + 내게 쓰는 법" 을 적은 지식 문서 하나씩만 두고, AI 가 소스 문서와 목적지 문서를 조합해 변환한다. 도구를 하나 추가하면 문서 하나가 늘고 방향은 2N 개가 늘어난다.

```
core/
  procedure.md      5단계 절차 (Scan → Plan → Confirm → Apply → Report)
  security.md       시크릿 탐지·처리 정책
  tools/*.md        도구별 지식 문서 (읽기 규칙 + 쓰기 규칙 양면)
adapters/*/SKILL.md 도구별 진입점 (목적지만 다른 얇은 껍데기)
```

## 설치

### Claude Code · Codex CLI — 플러그인

```
/plugin marketplace add <이 저장소>
/plugin install migrate@migrate-marketplace
```

두 도구가 같은 패키지를 무변환으로 설치한다. 플러그인 배포본은 실행 중인 도구를 스스로 판정해 목적지로 삼는다.

### Cursor · Grok Build — 설치 스크립트

```
./install.sh cursor    # → ~/.cursor/skills/migrate
./install.sh grok      # → ~/.grok/skills/migrate  (GROK_HOME 존중)
```

`./install.sh claude`, `./install.sh codex` 도 있다. 플러그인을 쓰지 않고 개인 스킬로 설치하고 싶을 때 쓴다.

## 사용법

```
/migrate codex          소스를 명시
/migrate                자동 감지 — 설치된 도구를 찾아 고르게 한다
```

자연어도 된다. "코덱스 설정 옮겨줘" 처럼 말해도 문장 안의 도구 이름을 읽는다.

실행하면 계획표를 보여주고 **승인을 받기 전에는 아무것도 쓰지 않는다.** 승인 후 `<타겟 홈>/.migrate/<run-id>/migration-report.md` 에 무엇이 어떻게 옮겨졌는지 남는다.

## 검증된 방향

각 방향은 픽스처를 실제로 이관한 뒤 결정적 검증기로 채점했다. 아래는 실측 결과다.

| 방향 | 체크 | 결과 |
|---|---|---|
| Codex → Claude | 64 | 통과 |
| Claude → Codex | 54 | 통과 |
| Claude → Cursor | 57 | 통과 |
| Cursor → Claude | 59 | 통과 |
| Claude → Grok | 61 | 통과 |
| Grok → Claude | 61 | 통과 |
| Codex → Cursor | 58 | 통과 |

나머지 5방향(Codex↔Grok, Cursor↔Grok, Cursor→Codex)은 같은 구조로 커버되지만 실측하지 않았다. Codex → Cursor 가 **새 픽스처도 새 검증기도 없이** 기존 산출물 조합만으로 통과한 것이 조합 가능성의 근거다.

직접 돌려보려면:

```
./scripts/verify-migration.sh <타겟 루트> <타겟 도구> <소스 도구>
```

## 이관되지 않는 것

**인증 정보는 옮기지 않는다.** API 키·토큰·`auth.json`·크레덴셜 파일은 읽지도 복사하지도 않는다. 설정 안에 들어 있는 시크릿(MCP 헤더의 API 키 등)은 `<REDACTED-REENTER>` 로 치환하고, 어떤 키를 어디에 다시 넣어야 하는지만 리포트에 남긴다.

그 밖에 옮기지 않는 것.

- **모델 설정** — 도구마다 모델명이 다르다. 현재 값을 리포트에 인용해 안내만 한다.
- **승인 정책·샌드박스** — 대응 개념은 있지만 의미가 달라 자동 적용하지 않는다. 제안만 한다.
- **단축키·세션 기록·앱 상태** — 설정이 아니거나 이식 대상이 아니다.
- **계정에 저장된 설정** — Cursor 의 User Rules 처럼 디스크에 없는 것은 원문을 수동 조치 목록에 실어 직접 붙여넣게 안내한다.

## 손실이 생기는 지점

권한 모델은 도구마다 표현력이 달라 근사가 불가피하다.

- Cursor 에는 `ask` 티어가 없다. 다른 도구의 ask 규칙은 allow 나 deny 어디에도 넣지 않고(둘 다 원래 의미를 왜곡한다) 수동 조치로 넘긴다.
- Codex 권한은 argv 접두사 DSL 이라 경로·도메인·MCP 규칙을 표현할 수 없다. 변환하지 않고 원문을 그대로 넘긴다.
- Cursor 에는 전역 env 주입 표면이 없다. 키 이름과 소스 위치를 기록해 직접 옮기게 안내한다.
- 훅 도구 매처가 다대일로 합쳐지는 구간이 있다(Claude `Edit`·`Write` → Cursor `Write`). 역방향은 유일하게 복원되지 않아 `Edit|Write` 로 되돌린다.

이런 항목은 전부 리포트의 "근사 매핑" 또는 "수동 조치" 섹션에 무엇이 어떻게 손실됐는지와 함께 남는다.

## 안전 보장

- **승인 전 무쓰기.** Confirm 단계에서 계획표를 승인받기 전에는 어떤 파일도 건드리지 않는다.
- **덮어쓰지 않고 병합.** 기존 설정을 지우지 않는다. 수정 전 원본을 `.migrate/<run-id>/backup/` 에 복사하고, 쓰기 후 파싱에 실패하면 백업에서 복원한 뒤 중단한다.
- **재실행 안전.** `.migrate/ledger.json` 에 이관한 소스 파일의 sha256 을 기록한다. 같은 설정을 다시 돌려도 중복 병합되지 않는다.
- **동명 충돌은 건너뛴다.** 타겟에 같은 이름의 스킬·서브에이전트·MCP 서버가 있으면 덮어쓰지 않고 리포트에 남긴다.

## 개발

`skills/` 는 **빌드 산출물**이다. 정본은 `adapters/plugin/SKILL.md` 와 `core/` 이고, 플러그인 로더가 루트의 `skills/` 를 찾기 때문에 저장소에 커밋해둔다.

```
./scripts/build-plugin.sh           배포본 재생성
./scripts/build-plugin.sh --check   정본과 어긋나면 exit 1 (커밋 전 확인)
claude plugin validate . --strict   매니페스트 검증
```

`core/` 나 `adapters/plugin/SKILL.md` 를 고쳤으면 빌드를 다시 돌린다. 도구 홈에 설치된 사본도 낡으므로 `./install.sh <dest>` 를 다시 실행해야 한다.

새 도구를 추가하려면 `core/tools/_template.md` 를 채워 지식 문서를 만들고, 픽스처 하나와 타겟 검증기 하나, 소스 체크 하나를 추가한다. 방향별로 만들 것은 없다.

## 알려진 제약

- **Grok Build 는 실기기에서 검증되지 않았다.** 개발 환경에 Grok Build 가 설치돼 있지 않아, `~/.grok/skills/migrate` 에 설치되는 것까지는 확인했지만 Grok 이 그 스킬을 실제로 로드하는지는 확인하지 못했다. 파일 변환 자체는 양방향 61/61 로 검증됐다.
- 지식 문서는 2026년 8월 기준 각 도구의 설정 표면을 반영한다. 도구가 포맷을 바꾸면 해당 문서를 고쳐야 한다.
- 같은 이름의 커뮤니티 CLI `superagent-ai/grok-cli` 는 설정 저장 위치가 완전히 다르다(`~/.grok/user-settings.json`). 이 도구는 xAI 공식 **Grok Build** 만 다루며, 감지 단계에서 구분한다.

## 라이선스

MIT
