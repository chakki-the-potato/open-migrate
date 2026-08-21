# Project-Scope Migration — Design

**Status:** approved, not yet implemented
**Date:** 2026-08-21

## Goal

Migrate per-project tool configuration (`<repo>/.claude/`, `<repo>/.codex/`, `AGENTS.md`, …) in addition to the home-scope configuration the tool handles today, so a user who switches tools can keep working in every project on the machine.

## Why this is not just "run the existing flow in another directory"

Three things differ from home scope, and each one drove a design decision.

**Source and target share a directory.** In home scope the source root (`~/.codex`) and target root (`~/.claude`) are two separate trees. In a project they are the same repository: `<repo>/.codex/` → `<repo>/.claude/`. The "source root / target root" pair collapses into a single project root.

**Project config is usually tracked by git.** On the measured machine, `are-you-in` has `CLAUDE.md`, `AGENTS.md`, and `.claude/settings.local.json` all committed. Migrating produces a diff in someone's repository and, once pushed, reaches teammates. Home config only ever affects the local machine.

**Discovery can go badly wrong.** A naive scan for tool config directories on the measured machine returned 38 hits, of which only 17 were real projects. The rest were the tools' own caches — plugin marketplaces, package caches, temp clones.

## Project discovery

Scan from `$HOME`, excluding:

- **Tool homes and everything under them** — `~/.claude/`, `~/.codex/`, `~/.cursor/`, `~/.grok/`, `~/.agents/`
- **Package and build caches** — `node_modules`, `.bun`, `.npm`, `.cache`
- **System locations** — `Library`, `.Trash`

A directory is a project when, outside those exclusions, it contains any tool config surface from the inventory below.

**Depth limit.** Scan to a depth of 5 from `$HOME`. The measured machine finds every real project within that bound, and an unbounded scan spends most of its time inside dependency trees the exclusions would discard anyway. Report the limit in the scan output so a user with deeper layouts knows why something was missed, and let them pass an explicit project root instead.

**Nested projects are separate projects.** `claude-chat-integration/claudecodeui` on the measured machine has its own config inside a parent that also has config. Treat each directory that carries a config surface as its own project with its own ledger. Do not merge a child's config into the parent — the tools resolve them as distinct scopes, and merging would change which settings apply where.

**Being a git repository is not a valid test.** Of the 25 git repositories found in the measured scan, 13 were tool caches — plugin marketplaces are themselves git clones. The tool-home exclusion is the load-bearing rule; git status is only reported, never used to decide.

## Per-tool project surfaces

| Tool | Rules | Settings | Skills / agents | Notes |
|---|---|---|---|---|
| Claude Code | `CLAUDE.md`, `.claude/CLAUDE.md` | `.claude/settings.json`, `.claude/settings.local.json`, `.mcp.json` | `.claude/skills/`, `.claude/agents/`, `.claude/commands/` | |
| Codex CLI | `AGENTS.md` | `.codex/config.toml`, `.codex/hooks.json` | `.codex/skills/` | **Trust-gated** |
| Cursor | `.cursor/rules/*.mdc`, `AGENTS.md` | — | `.cursor/skills/`, `.cursor/agents/`, `.cursor/commands/` | |
| Grok Build | `AGENTS.md` | `.grok/config.toml` (MCP, plugins, permission rules only) | `.grok/skills/`, `.grok/agents/`, `.grok/hooks/` | Project layer loads less than home |
| Vendor-neutral | — | — | `.agents/skills/` | Read natively by several tools |

### Two surfaces need special handling

**Codex trust gate.** A project's `.codex/config.toml`, `.codex/hooks.json`, and skills layer are ignored unless `~/.codex/config.toml` contains `[projects."<absolute path>"] trust_level = "trusted"`. Writing project config for a Codex target without that entry produces files the tool never reads. Either add the trust entry or state in the report that the user must trust the project for the migration to take effect.

**`.agents/skills/` is already shared.** Cursor and Grok read it natively, so a skill living there is visible to them without migration. Copying it into `.claude/skills/` creates a duplicate rather than a gain. Treat it the way cursor.md treats compatibility loading: record it as "already being read" and do not migrate. This was measured — three projects on this machine keep real skills there.

## Execution flow

The existing five steps are kept; only Scan and Apply widen.

1. **Scan** — home scope, then every discovered project.
2. **Plan** — one row per item as before, but grouped by project, and each row records **whether the file is tracked by git**.
3. **Confirm** — the whole plan is approved once. Approving per project would mean 17 prompts on the measured machine, defeating the purpose.
4. **Apply** — iterate projects. Each project gets its own `.migrate/ledger.json` inside that project.
5. **Report** — per-project results plus the home result.

Per-project ledgers mean a failure on the fifth project does not undo the first four; a re-run skips what is already recorded.

## Staged implementation

**Stage 1 — one project at a time.** Add the project surface inventory to each tool doc and complete the path where the user names a single project root. Build the verification fixture here.

**Stage 2 — machine-wide scan.** Add discovery and iteration on top. With stage 1 verified, stage 2 only adds the loop.

Splitting this way keeps scan bugs and conversion bugs from mixing. A failure in stage 2 is a discovery problem; a failure in stage 1 is a conversion problem.

## Out of scope

**Centralization.** An earlier draft considered a hub directory with symlinks or `@import` wiring so every tool shares one source. Measurement killed it: of the three tools tested, only Grok reads the vendor-neutral `~/.agents/skills/`; Claude and Cursor do not. Centralization would therefore rest on symlinks, and MCP servers, permissions, hooks, and env injection cannot be linked at all — they are values inside a larger settings file, not standalone files. The result would be a mode that applies to some categories and not others. Copying into each tool's own directory stays the only mode.
