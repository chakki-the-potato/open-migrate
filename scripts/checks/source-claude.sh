# source-claude.sh — Claude Code 를 소스로 이관했을 때 migration-report.md 에 남아야 하는
# 소스 종속 문자열 체크. _common.sh 가 내보낸 mig_dir, chk/chk_not 만 쓴다 —
# target 이 무엇이든(target-*.sh 가 만드는 변수에 기대지 않으므로) 안전하게
# 조합된다. migration-report.md 파일 자체의 존재는 _common.sh 가 이미 검증했다.

chk "report: source model noted"         grep -qF "claude-fable-5" "${mig_dir}migration-report.md"
chk "report: dropped ConfigChange hook noted" grep -qF "ConfigChange" "${mig_dir}migration-report.md"
chk "report: secret re-entry listed"     grep -qF "X-API-Key" "${mig_dir}migration-report.md"
chk "report: approval policy suggested"  grep -qE "approval_policy|sandbox_mode|defaultMode" "${mig_dir}migration-report.md"
