---
name: migrate
description: Migrate settings from another AI coding tool (Claude Code, Codex CLI, Grok) into Cursor — rules, MCP servers, skills, subagents, hooks, permissions. Use when the user asks to import or migrate settings from another AI tool.
---

# migrate — AI settings migration (destination: Cursor)

You are running inside the destination tool (Cursor). Migrate another tool's settings into this one.

## 0. Resolve inputs

- Skill directory = the directory holding this `SKILL.md` (normally `~/.cursor/skills/migrate/`). Every `core/...` path below is relative to it.
- Source = the tool name found in the user's message (`claude` | `codex` | `grok`). Cursor skills have no argument substitution, so read the tool name from **the user's message body**.
- If that source has no doc under `core/tools/`, say support is planned and stop.
- Source root = the default home from the source tool's doc. If the user gives an explicit source root path, use that instead.
- Target root = the real Cursor environment (`~/.cursor`, per `core/tools/cursor.md`). If the user gives an explicit target root, use it and switch to **test mode** (see procedure.md, "Path resolution in test mode").
- Project scope = per-project configuration in a repository. Migrate it when the user names a project root, or every project on the machine when they ask for that — procedure.md's "Project scope" section defines both, including the discovery command. With neither, migrate home scope only and never go looking for projects.
- Auto-detect only when neither the source nor a source root was given. Check whether `~/.claude`, `~/.codex`, and `~/.grok` exist, present the tools you found, and let the user choose (excluding the destination itself). If you cannot ask the user, stop rather than guess.

## 1. Load knowledge (relative to the skill directory, all required)

1. `core/security.md` — the policy that overrides everything
2. `core/procedure.md` — the execution procedure
3. `core/tools/<source>.md` — how to read and convert the source
4. `core/tools/cursor.md` — how to write to this target
5. If any of those delegates a rule to another tool's doc (for example "apply codex.md's MCP conversion rules directly"), **read that doc too.** Skipping the delegation leaves you with half the rules.

## 2. Execute

Follow procedure.md's Scan → Plan → Confirm → Apply → Report, in order.
