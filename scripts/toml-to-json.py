#!/usr/bin/env python3
"""Convert a TOML file to JSON on stdout.

On a parse failure it prints an empty object and exits 1, so a caller can ask "is this
valid TOML?" and "what is in it?" with the same command.

Run inline via `python3 -c`, `import tomllib` dies with PermissionError in this machine's
sandbox depending on the execution context. It does not reproduce when run from a real
file, which is why this lives in its own script.
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
