---
name: open-migrate
description: Migrate settings between AI coding tools (Claude Code, Codex CLI, Cursor, Grok Build) — rules, MCP servers, skills, subagents, hooks, permissions. Use when the user asks to move or import settings from one AI coding tool to another.
user-invocable: true
---

# open-migrate — move settings between AI coding tools

Migrate one tool's configuration into another. Both tools are inputs: you are told which to read from and which to write to, so never infer either from where this file is installed.

## 0. Resolve inputs

### 0-1. Source and destination

Read them from the user's input if present. `/open-migrate codex claude` means **source `codex`, destination `claude`** — source first, matching the order of "migrate from X to Y". Some tools substitute arguments into `$ARGUMENTS`; Cursor does not, so also read the message body. A natural-language request ("move my codex settings into claude") carries the same two values.

Ask for whatever is still missing. Do not guess, and do not assume the tool you are running inside is either one.

When asking, list what is actually on the machine — check for `~/.claude`, `~/.codex`, `~/.cursor`, and `~/.grok` and present what exists. Offer tools that are not installed as destinations too, noting that their home will be created; migrating into a tool before installing it is a normal thing to want.

Valid values: `claude`, `codex`, `cursor`, `grok`. Source and destination must differ. If either has no doc under `core/tools/`, say support is planned and stop.

### 0-2. Scope

Ask what to migrate when the user has not said:

- **Home only** — the tool's own configuration directory. The default.
- **A named project** — that repository's per-project configuration as well.
- **Every project** — discovery per procedure.md's "Project scope" section.

### 0-3. Roots

- Source root = the source doc's default home, unless the user names a path.
- Destination root = the destination doc's default home, unless the user names a path — in which case switch to **test mode** (procedure.md, "Path resolution in test mode").
- Project root = whatever the scope answer produced.

## 1. Load knowledge (relative to this file's directory, all required)

1. `core/security.md` — the policy that overrides everything
2. `core/procedure.md` — the execution procedure
3. `core/tools/<source>.md` — how to read and convert the source
4. `core/tools/<destination>.md` — how to write to the destination
5. If any of those delegates a rule to another tool's doc (for example "apply codex.md's MCP conversion rules directly"), **read that doc too.** Skipping the delegation leaves you with half the rules.

## 2. Execute

Follow procedure.md's Scan → Plan → Confirm → Apply → Report, in order.
