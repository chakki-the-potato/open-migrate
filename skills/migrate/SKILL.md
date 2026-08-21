---
name: migrate
description: Migrate settings between AI coding tools (Claude Code, Codex CLI, Cursor, Grok Build) — rules, MCP servers, skills, subagents, hooks, permissions. Use when the user asks to import or migrate settings from another AI tool, or runs /migrate [source].
---

# migrate — AI settings migration (plugin distribution)

Migrate another tool's settings into **whichever tool this skill is currently running in**.

This distribution is installed through a plugin marketplace, and both Claude Code and Codex CLI install the same package without conversion. That is why the destination is not fixed here — step 0 determines it. (Cursor and Grok install via the repository's `./install.sh <dest>`, which uses destination-specific entry points instead.)

## 0. Resolve inputs

### 0-1. Determine the destination (do this first)

The destination is **the tool you are running inside** — not the tool whose directory this file happens to sit in. Getting this wrong writes settings into the wrong home, so treat it as the highest-risk decision in the whole run.

**The skill directory path is a hint, not proof.** Several tools load other tools' skill directories for compatibility — Grok Build reads `~/.claude/skills/` and `~/.codex/skills/`, and Cursor reads `.claude/skills/` and `.codex/skills/`. So a path containing `.claude` can perfectly well be running inside Grok or Cursor.

Determine it this way:

1. Form a hypothesis from the skill directory path (`.claude` → claude, `.codex` → codex).
2. **Verify the hypothesis against the session you are actually in.** Ask yourself which tool's runtime you are executing under — the name of the product in your own system context, the tool set you were given, the slash-command namespace you were invoked through (a compat-loaded skill is usually namespaced, for example `/migrate:migrate` or `/user:migrate`).
3. If the verification agrees with the hypothesis, proceed.
4. **If it disagrees, or you cannot verify it, ask the user which tool they are running. Never guess.** A wrong destination is worse than one extra question.

If the destination turns out to be a tool other than Claude Code or Codex CLI (Cursor or Grok Build reading this through a compatibility path), tell the user that this plugin distribution is meant for Claude Code and Codex CLI, and that the destination-specific entry point installed by `./install.sh <dest>` is the correct one for their tool. Stop rather than migrating with a guessed destination.

Use the destination you determined as `<target>` below. If `core/tools/<target>.md` does not exist, say support is planned and stop.

### 0-2. Everything else

- Skill directory = the directory holding this `SKILL.md`. Every `core/...` path below is relative to it.
- Source = the tool name found in the user's input (`claude` | `codex` | `cursor` | `grok`, excluding the destination itself). When the argument is a single token such as `/migrate codex`, use that word; for a natural-language sentence, use the tool name mentioned in it. If the substitution token is empty, read it from the message body.
- If that source has no doc under `core/tools/`, say support is planned and stop.
- Source root = the default home from the source tool's doc. If the user gives an explicit source root path, use that instead.
- Target root = the real home defined by `core/tools/<target>.md`. If the user gives an explicit target root, use it and switch to **test mode** (see procedure.md, "Path resolution in test mode").
- Auto-detect only when neither the source nor a source root was given. Check whether `~/.claude`, `~/.codex`, `~/.cursor`, and `~/.grok` exist, present the tools you found, and let the user choose (excluding the destination itself). If you cannot ask the user, stop rather than guess.

## 1. Load knowledge (relative to the skill directory, all required)

1. `core/security.md` — the policy that overrides everything
2. `core/procedure.md` — the execution procedure
3. `core/tools/<source>.md` — how to read and convert the source
4. `core/tools/<target>.md` — how to write to this target
5. If any of those delegates a rule to another tool's doc (for example "apply codex.md's MCP conversion rules directly"), **read that doc too.** Skipping the delegation leaves you with half the rules.

## 2. Execute

Follow procedure.md's Scan → Plan → Confirm → Apply → Report, in order.
