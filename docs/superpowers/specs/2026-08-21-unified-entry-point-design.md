# Unified Entry Point — Design

**Status:** approved, not yet implemented
**Date:** 2026-08-21

## Problem

`/migrate codex` does not say which direction it means. Read one way it migrates *into* Codex; read the other it migrates *from* Codex. Only the docs settle it, and the person typing the command is exactly the person who has not read them.

Two other problems share a root cause with it.

**The destination is inferred rather than stated.** Every entry point is destination-fixed — `adapters/claude/SKILL.md` writes to Claude because of where it was installed. The plugin distribution cannot do that (one package serves Claude and Codex), so it determines the destination at runtime from its own path. That inference was measured to be unreliable: Grok reads `~/.claude/skills/` for compatibility, so a skill sitting under `.claude` can be running inside Grok. A verification step now guards it, but the guard exists only because the destination was never stated.

**Migration requires already having the destination.** Because the running tool *is* the destination, you cannot migrate into a tool you have not installed yet — which is the situation someone switching tools is usually in.

## Solution

One command, `/open-migrate`, that asks for source and destination.

```
/open-migrate                  ask for both
/open-migrate codex claude     source first, then destination
```

The name matches the repository, contains no spaces, and does not collide with Grok's built-in `/migrate`.

## What this changes

**Destination becomes an input, not an inference.** The runtime detection block in the plugin entry point is deleted outright, along with the compat-path guard it needed.

**The five entry points collapse into one.** They differ only in which destination they hardcode; with the destination supplied, they are the same file. `adapters/` goes from five directories to one.

**Any direction works from anywhere.** Running inside Claude, a user can write to `~/.grok` for a Grok they have not installed yet. Preparing a tool before switching to it becomes possible.

## Argument handling

Arguments are optional, and the interactive path is the primary one — **not a fallback**, because one supported tool cannot receive arguments at all.

| Tool | Argument delivery |
|---|---|
| Claude Code, Codex CLI, Grok Build | `$ARGUMENTS` substitution |
| Cursor | No substitution — read from the message body |

So the entry point reads whatever it can (substitution token, message body) and asks for anything still missing. With both values present it proceeds directly; with one, it asks for the other; with none, it asks for both.

Order is **source first, then destination** — the same order as the words in "migrate from X to Y".

## Interactive flow

Discovery already exists and is reused: the entry point checks which tool homes are present and offers them as choices rather than asking the user to recall names.

```
/open-migrate

  Found: Claude Code, Codex CLI, Cursor, Grok Build
  Migrate from?  → codex
  Migrate to?    → claude
  Include project config?  → home only / a named project / every project

  [plan table]
  Proceed?
```

The destination list is not limited to installed tools; an uninstalled one is offered with a note that its home will be created.

The five-step procedure (Scan → Plan → Confirm → Apply → Report) is untouched. This adds an input-collection step in front of it.

## Migration path for existing installs

The skill directory name is the command name, so `skills/migrate/` must become `skills/open-migrate/`. An upgrade leaves the old directory behind and both commands appear, one of them stale.

`install.sh` removes any `skills/migrate/` it finds at the destination before installing, and the README says to uninstall the old plugin before installing the new one. The plugin name in `plugin.json` changes from `migrate` to `open-migrate`, so the two can be told apart.

## Out of scope

**Per-direction commands** (`/codex2claude`, `/claude2codex`, …) were the first proposal. They solve the ambiguity too, and their destination is unambiguous for the same reason — it is stated, not inferred. They were rejected because they need twelve entry points where this needs one, put three commands in every tool's autocomplete, and still cannot migrate into a tool that is not installed.
