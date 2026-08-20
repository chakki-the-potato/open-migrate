#!/usr/bin/env python3
"""TOML 파일을 JSON 으로 변환해 stdout 에 출력한다.

파싱에 실패하면 빈 객체를 출력하고 종료 코드 1 로 끝낸다 — 호출부가 "유효한 TOML 인가"
와 "무엇이 들어 있는가" 를 같은 명령으로 물을 수 있게 하기 위해서다.

인라인 `python3 -c` 로는 이 머신의 샌드박스에서 `import tomllib` 이 실행 컨텍스트에 따라
PermissionError 로 죽는다. 실제 파일로 실행하면 재현되지 않으므로 별도 파일로 둔다.
"""
import json
import pathlib
import sys
import tomllib


def main() -> int:
    try:
        print(json.dumps(tomllib.loads(pathlib.Path(sys.argv[1]).read_text())))
    except Exception:
        print("{}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
