---
name: migrate
description: Migrate settings from another AI coding tool (Codex, Cursor, Grok) into Claude Code — rules, MCP servers, skills, subagents, hooks, permissions. Use when the user asks to import or migrate settings from another AI tool, or runs /migrate [source].
---

# migrate — AI settings migration (destination: Claude Code)

You are running inside the destination tool (Claude Code). Migrate another tool's settings into this one.

## 0. Resolve inputs

- Skill directory = the directory holding this `SKILL.md` (normally `~/.claude/skills/migrate/`). Every `core/...` path below is relative to it.
- Source = the tool name found in `$ARGUMENTS` (`codex` | `cursor` | `grok`). When the argument is a single token such as `/migrate codex`, use that word; for a natural-language sentence, use the tool name mentioned in it.
- If that source has no doc under `core/tools/`, say support is planned and stop.
- Source root = the default home from the source tool's doc. If the user gives an explicit source root path, use that instead.
- Target root = the real Claude Code environment (`~/.claude` and similar, per `core/tools/claude.md`). If the user gives an explicit target root, use it and switch to **test mode** (see procedure.md, "Path resolution in test mode").
- Auto-detect only when neither the source nor a source root was given. Check whether `~/.codex`, `~/.cursor`, and `~/.grok` exist, present the tools you found, and let the user choose (excluding the destination itself). If you cannot ask the user, stop rather than guess.

## 1. Load knowledge (relative to the skill directory, all required)

1. `core/security.md` — the policy that overrides everything
2. `core/procedure.md` — the execution procedure
3. `core/tools/<source>.md` — how to read and convert the source
4. `core/tools/claude.md` — how to write to this target
5. If any of those delegates a rule to another tool's doc (for example "apply codex.md's MCP conversion rules directly"), **read that doc too.** Skipping the delegation leaves you with half the rules.

## 2. Execute

Follow procedure.md's Scan → Plan → Confirm → Apply → Report, in order.
