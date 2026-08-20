# source-cursor.sh — Cursor 를 소스로 이관했을 때 migration-report.md 에 남아야 하는
# 소스 종속 문자열 체크. _common.sh 가 내보낸 mig_dir, chk/chk_not 만 쓴다 —
# target 이 무엇이든(target-*.sh 가 만드는 변수에 기대지 않으므로) 안전하게
# 조합된다. migration-report.md 파일 자체의 존재는 _common.sh 가 이미 검증했다.

chk "report: secret re-entry listed"      grep -qF "X-API-Key" "${mig_dir}migration-report.md"
chk "report: approval policy suggested"   grep -qE "approvalMode|approval_policy|sandbox_mode|defaultMode" "${mig_dir}migration-report.md"

# User Rules는 로컬 파일이 없다 — Cursor 계정(클라우드 동기화)에만 있어 자동 이관이
# 원천적으로 불가능하다(core/tools/cursor.md "설정 인벤토리" User Rules 행 + "전역
# 규칙" 변환 규칙 행). 리포트는 이 사실과 "자동 이관 불가"를 모두 명시해야 한다.
chk "report: User Rules noted as account-stored" grep -qF "User Rules" "${mig_dir}migration-report.md"
chk "report: User Rules manual action"    grep -qE "User Rules.*(수동|manual|직접)" "${mig_dir}migration-report.md"

# Cursor 권한은 allow/deny 2단계뿐이라 ask 티어 자체가 없다(core/tools/cursor.md
# 권한 규칙 인벤토리). 두 가지를 모두 리포트에 남겨야 한다: (1) 다른 도구의 ask
# 규칙은 Cursor에 표현할 대상이 없다는 점, (2) 반대로 Cursor가 소스일 때
# allow/deny 어디에도 없는 커맨드는 Cursor 런타임이 암묵적으로 prompt하지만
# 이는 명시적으로 기록된 규칙이 아니므로 소스 쪽에 옮길 명시적 표현이 없다는 점.
chk "report: approvalMode value quoted"   grep -qF "allowlist" "${mig_dir}migration-report.md"
chk "report: app-managed area noted"      grep -qF "skills-cursor" "${mig_dir}migration-report.md"
