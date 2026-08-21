# source-grok.sh — Grok Build 를 소스로 이관했을 때 migration-report.md 에 남아야 하는
# 소스 종속 문자열 체크. _common.sh 가 내보낸 mig_dir, chk/chk_not 만 쓴다 —
# target 이 무엇이든(target-*.sh 가 만드는 변수에 기대지 않으므로) 안전하게
# 조합된다. migration-report.md 파일 자체의 존재는 _common.sh 가 이미 검증했다.
#
# 타겟에 따라 달라지는 항목(서브에이전트 Grok 전용 필드 드롭, 스킬 user-invocable 키
# 드롭 등)은 여기 두지 않는다 — 타겟이 그 표면을 가지면 드롭 자체가 일어나지 않는다.

chk "report: source model noted"       grep -qF "grok-5-code" "${mig_dir}migration-report.md"
chk "report: disabled server noted"    grep -qF "disabled_one" "${mig_dir}migration-report.md"
chk "report: secret re-entry listed"   grep -qF "X-API-Key" "${mig_dir}migration-report.md"
chk "report: approval policy suggested" grep -qE "permission_mode|approval_policy|sandbox_mode|defaultMode|approvalMode" "${mig_dir}migration-report.md"

# GROK.md 는 Grok 자신이 읽지 않는 파일이라 이관 대상이 아니다(core/tools/grok.md 전역
# 규칙 변환 규칙). 조용히 무시하지 말고 그런 파일을 발견했다는 사실을 리포트에 남겨야
# 한다 — 사용자가 "규칙을 써뒀는데 왜 안 옮겨졌나" 를 추적할 수 있어야 하기 때문이다.
chk "report: unread rules file noted"  grep -qF "GROK.md" "${mig_dir}migration-report.md"
