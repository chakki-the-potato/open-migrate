#!/usr/bin/env bash
# 저장소 구조(adapters/ + core/)를 플러그인 배치(skills/migrate/)로 빌드한다.
#
# 플러그인 로더는 루트의 skills/ 아래에서 스킬을 찾으므로 배포본이 저장소에
# 커밋돼 있어야 한다. 정본은 adapters/plugin/SKILL.md 와 core/ 이고
# skills/ 는 그 둘에서 생성되는 산출물이다 — skills/ 를 직접 고치지 마라.
#
#   ./scripts/build-plugin.sh          배포본 재생성
#   ./scripts/build-plugin.sh --check  정본과 어긋나면 exit 1 (커밋 전 확인용)
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
out="$repo_dir/skills/migrate"

build_into() {
  local dest="$1"
  rm -rf "$dest"
  mkdir -p "$dest"
  cp "$repo_dir/adapters/plugin/SKILL.md" "$dest/SKILL.md"
  cp -R "$repo_dir/core" "$dest/core"
  # 템플릿은 새 도구 추가용 개발 문서라 배포본에서 제외한다.
  rm -f "$dest/core/tools/_template.md"
}

if [ "${1:-}" = "--check" ]; then
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  build_into "$tmp/migrate"
  if [ ! -d "$out" ]; then
    echo "FAIL: skills/migrate/ 가 없다 — ./scripts/build-plugin.sh 를 실행하라" >&2
    exit 1
  fi
  if diff -r "$tmp/migrate" "$out" >/dev/null 2>&1; then
    echo "OK: 배포본이 정본과 일치한다"
  else
    echo "FAIL: 배포본이 정본과 다르다 — ./scripts/build-plugin.sh 를 실행하라" >&2
    diff -r "$tmp/migrate" "$out" >&2 || true
    exit 1
  fi
else
  build_into "$out"
  echo "built: $out"
fi
