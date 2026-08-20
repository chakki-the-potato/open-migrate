# _common.sh — 타겟 툴에도 소스 툴에도 무관한 검증(공통 체크) + run-directory 해석 메커니즘.
#
# 소싱하는 쪽(verify-migration.sh)이 이미 정의해 둔 것: TARGET, TOOL, SOURCE,
# script_dir, chk/chk_not, fail. set -uo pipefail 도 이미 적용돼 있다.
# 로드 순서는 _common.sh -> target-$TOOL.sh -> source-$SOURCE.sh 이므로,
# source-<tool>.sh 는 target-<tool>.sh 가 만든 변수(예: mcp_json)까지도
# 참조할 수는 있다 — 다만 그렇게 하면 그 source 파일은 "그 변수를 만드는
# target 파일" 과 짝지어질 때만 안전해진다(다른 target 조합에서 set -u
# 미정의 변수 에러로 죽는다). mig_dir 처럼 이 파일이 내보내는 변수만 쓰면
# 어떤 target 과 조합해도 안전하다 — source-<tool>.sh 는 가능하면 이쪽만
# 쓸 것.
#
# 이 파일이 target-<tool>.sh / source-<tool>.sh 를 위해 내보내는 것:
#   mig_dir            최신 run 디렉터리 경로(trailing slash 포함).
#                       .migrate/<run-id>/ 가 하나도 없으면 존재하지
#                       않는 .migrate/__missing__/ 를 가리켜, 하위
#                       체크들이 "파일 없음"으로 자연스럽게 FAIL 한다.
#   is_noop_rerun       "1" | "0". 최신 run 의 REPORT.md 가 "이미
#                       이관됨"을 기록한 정당한 no-op 재실행이면 "1" —
#                       이때만 과거 run 의 산출물을 인정해도 된다.
#                       "0" 이면 반드시 mig_dir 하나만 신뢰해서, 깨진
#                       최신 run 이 과거 run 산출물로 위장 통과하는
#                       것을 막는다.
#   find_run_artifact <run-dir 상대경로>
#                       is_noop_rerun 을 반영해 "런 하나 시점의
#                       스냅샷" 성격 산출물(예: backup/CLAUDE.md) 경로를
#                       해석하는 헬퍼. 여러 run 에 걸쳐 누적되는
#                       산출물(예: mcp-commands.sh)은 합치는 방식이
#                       달라 이 헬퍼를 쓰지 않고 타겟 파일이
#                       is_noop_rerun 을 직접 보고 처리한다.

mig_dir="$(ls -d "$TARGET/.migrate/"*/ 2>/dev/null | sort | tail -1)"
if [ -z "$mig_dir" ]; then
  echo "ERROR: no .migrate/<run-id>/ directory under $TARGET — every run-output check below fails for this one reason"
  mig_dir="$TARGET/.migrate/__missing__/"
fi

# 실행 단위 산출물(백업·MCP 명령)은 원칙적으로 최신 run 에서 찾는다.
# 최신 run 이 원장 스킵으로 정당하게 아무것도 새로 만들지 않은 경우(리포트에 "이미 이관됨" 기록)에만
# 과거 run 의 산출물을 인정한다 — 그렇지 않으면 깨진 최신 run 이 과거 흔적으로 위장 통과한다.
if grep -q "이미 이관됨" "${mig_dir}REPORT.md" 2>/dev/null; then
  is_noop_rerun=1
else
  is_noop_rerun=0
fi

find_run_artifact() {
  local rel="$1"
  if [ "$is_noop_rerun" = "1" ]; then
    ls "$TARGET/.migrate/"*/"$rel" 2>/dev/null | sort | tail -1
  else
    echo "${mig_dir}${rel}"
  fi
}

# 전역 규칙 — override 프리시던스 (decoy 미노출)
chk_not "AGENTS.override precedence"   grep -rqF "OVERRIDDEN-DECOY" "$TARGET"

# 리포트 산출물 존재 (내용은 타겟별 체크가 검증한다)
chk "report exists"                    test -f "${mig_dir}REPORT.md"

# 원장 (존재 + 유효 + sha256 기록)
chk "ledger exists"                    test -f "$TARGET/.migrate/ledger.json"
chk "ledger is valid JSON"             jq -e . "$TARGET/.migrate/ledger.json"
chk "ledger records source hashes"     jq -e '[..|strings] | map(select(test("^[0-9a-f]{64}$"))) | unique | length >= 5' "$TARGET/.migrate/ledger.json"

# 시크릿 불가침
chk_not "no MCP secret leaked"         grep -rqF "FAKE-SECRET-123" "$TARGET"
chk_not "auth.json never copied"       grep -rqF "AUTH-FAKE-SECRET" "$TARGET"
