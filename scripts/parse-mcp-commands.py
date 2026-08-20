#!/usr/bin/env python3
"""mcp-commands.sh 를 파싱해 `claude mcp add` 호출을 구조화된 JSON 배열로 출력한다."""
import json
import shlex
import sys
import pathlib

SEPS = {";", "&&", "||", "|", "&", "(", ")"}
VALUE_FLAGS = {"--scope", "--transport", "--env", "--header", "--timeout", "-e", "-H", "-s", "-t"}


def split_commands(text: str) -> list[list[str]]:
    text = text.replace("\\\n", " ")
    out: list[list[str]] = []
    for raw in text.splitlines():
        lex = shlex.shlex(raw, posix=True, punctuation_chars=True)
        lex.whitespace_split = True
        lex.commenters = "#"
        try:
            toks = list(lex)
        except ValueError:
            toks = []
        cur: list[str] = []
        for tok in toks:
            if tok in SEPS:
                if cur:
                    out.append(cur)
                cur = []
            else:
                cur.append(tok)
        if cur:
            out.append(cur)
    return out


def parse_add(toks: list[str]) -> dict | None:
    if toks[:3] != ["claude", "mcp", "add"]:
        return None
    rest = toks[3:]
    name = None
    flags: list[list[str | None]] = []
    args: list[str] = []
    cmd: list[str] = []
    i = 0
    while i < len(rest):
        tok = rest[i]
        if tok == "--":
            cmd = rest[i + 1:]
            break
        if tok.startswith("-"):
            if "=" in tok:
                key, value = tok.split("=", 1)
                flags.append([key, value])
                i += 1
            elif tok in VALUE_FLAGS and i + 1 < len(rest):
                flags.append([tok, rest[i + 1]])
                i += 2
            else:
                flags.append([tok, None])
                i += 1
            continue
        if name is None:
            name = tok
        else:
            args.append(tok)
        i += 1
    return {"name": name, "flags": flags, "args": args, "cmd": cmd, "argv": toks}


def main() -> None:
    try:
        text = pathlib.Path(sys.argv[1]).read_text()
    except OSError:
        print("[]")
        return
    parsed = [c for c in (parse_add(t) for t in split_commands(text)) if c is not None]
    print(json.dumps(parsed))


if __name__ == "__main__":
    main()
