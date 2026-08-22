# Claude Code (Anthropic)

Home: `~/.claude` (plus `~/.claude.json`). In test mode, use the target root the user specified instead of `~/.claude`.

## Detection

Consider it installed when `~/.claude/settings.json` or `~/.claude/CLAUDE.md` exists.

## Write rules (when Claude is the target)

| Category | Write location | How |
|---|---|---|
| Global rules | `CLAUDE.md` | Append a `## Migrated from <source> (<date>)` section at the end of the file, **verbatim** (never summarize or rewrite). Keep both the source's `@import` lines and the existing file's `@import` lines as-is. Never delete existing content. Copy the original to `.migrate/<run-id>/backup/CLAUDE.md` before modifying |
| Skills | `skills/<name>/SKILL.md` | Copy the whole directory. If a skill with the same name exists, skip it and record it in the report |
| Commands | `commands/<name>.md` | Plain markdown. `$1`-`$9` and `$ARGUMENTS` substitution is supported — keep the source's substitution tokens verbatim |
| Hooks | `hooks` key in `settings.json` | Structure: `{Event: [{matcher, hooks: [{type:"command", command, timeout}]}]}`. **A source hook object may carry fields outside that structure** (Codex's `statusMessage`, for example). Drop them and name each dropped field with its value in the report — carrying an unrecognized key into `settings.json` risks a config the tool rejects, while dropping one silently loses something the user wrote. Append to the existing hook arrays — skip when the command is identical. Treat **near-duplicates** (same script invoked with different path notation or flags) as skip candidates and confirm in Confirm (the strings differ, so this cannot be decided automatically — ask the user). **When you cannot ask — a blanket approval, a scripted run — skip them.** Skipping leaves the target's existing hook working and costs one line in the report; adding a near-duplicate silently runs the same script twice on every matching tool call, which is harder to notice and harder to undo. Name every hook you skipped this way and both versions of its command, so the user can add it deliberately if the difference mattered. Valid events: every event the **source** tool doc lists (8 from cursor.md's hook event table when the source is Cursor; codex.md's common events when it is Codex), plus Claude extension events such as Notification, PermissionDenied, PostToolUseFailure, ConfigChange, WorktreeCreate (accept these as-is when the names match). For an event name outside that list, verify it is an official Claude hook event; if you cannot confirm it, drop it and record it in the report |
| Permissions | `permissions.allow` / `deny` / `ask` in `settings.json` | Append to the arrays and de-duplicate. The official docs recommend `/permissions` inside a session, but a bulk migration merges directly — a deliberate deviation, justified by the backup, the jq validation, and the restore-on-failure path. Never set `defaultMode` automatically — put the approximation table in the report as a suggestion only |
| Env | `env` object in `settings.json` | Merge per key. If an existing key has a different value, that is a conflict — ask the user |
| Subagents | `agents/<name>.md` | Frontmatter: `name` and `description` (required), `tools` and `model` (optional). The body is the system prompt. Valid `model` values: aliases like `opus`/`sonnet`/`haiku`, a full model ID, or `inherit` (use the main conversation's model). **`inherit` is a value several tools share, so carry it over as-is when the source has it** — that is lossless. For any value outside this list (another vendor's model name, for example), do not write the field; quote the source value in the report for manual review instead (never guess a value). **If a file with the same name exists, do not overwrite it — skip and record in the report.** In real environments the same plugin is often installed on both sides, which makes every name collide |

## settings.json merge rules

1. Copy the original to `.migrate/<run-id>/backup/settings.json` before modifying.
2. Deep merge: merge objects per key, append to arrays then de-duplicate, preserve existing scalar values.
3. Validate with `jq -e . settings.json` after writing. On failure, restore from the backup, then stop and report.

## `~/.claude.json` in test mode

`~/.claude.json` lives **outside** the `~/.claude` directory. Its test-mode location follows procedure.md's "Path resolution in test mode" rule: **`<root>/.claude.json`**. Never read the real `~/.claude.json` — this also aligns with security.md forbidding you to read that file's other keys.

## Read inventory (when Claude is the source)

| Category | Location | Notes |
|---|---|---|
| Global rules | `~/.claude/CLAUDE.md` | **Carry `@path` import lines over verbatim and do not expand them** — never open the referenced file and inline it |
| Skills | `~/.claude/skills/<name>/SKILL.md` | The entire directory including supporting files |
| Commands | `~/.claude/commands/<name>.md` | Plain markdown. Keep `$1`-`$9` and `$ARGUMENTS` substitution tokens verbatim |
| Subagents | `~/.claude/agents/*.md` | Frontmatter `name` and `description` (required) plus `tools` and `model` (optional), then the body (system prompt). Drop `tools`, `model`, or `color` when the target has no corresponding field, and record it in the report |
| Hooks | `hooks` in `settings.json` | Only `command` type is migratable — http/mcp_tool/prompt/agent types are unsupported by the other tools; skip and record |
| Permissions | `permissions` in `settings.json` and `settings.local.json` | The `allow`/`ask`/`deny` arrays. `defaultMode` belongs to the approval policy row below |
| Env injection | top-level `env` object in `settings.json` | |
| Approval policy | `permissions.defaultMode` in `settings.json` | Not migrated — approximate it against the target's corresponding concept and put it in the report as a suggestion only |
| Model | top-level `model` in `settings.json` | Not migrated — quote the key and its **current value** verbatim in the report |
| Never read | the remaining keys in `~/.claude.json` (app state), `projects/` session data, `.credentials.json` | security.md applies |

## Project scope surfaces

Read these when Claude is the source in a project migration; write these when it is the target. Paths are relative to the project root.

| Category | Location | Notes |
|---|---|---|
| Global rules | `CLAUDE.md`, or `.claude/CLAUDE.md` | Reading: if both exist, migrate both and keep them separated per file (procedure.md's merge format). **Writing: prefer the root `CLAUDE.md`.** It is the location Claude Code documents first, and repositories frequently gitignore the whole `.claude/` directory — writing rules there would hide them from the team that the rules are for. Choose `.claude/CLAUDE.md` only when that file already exists and the root one does not; say which you picked and why in the report |
| Settings | `.claude/settings.json` (shared), `.claude/settings.local.json` (personal) | Same schema as home `settings.json`: `hooks`, `permissions`, `env`. Merge each into the matching file — never move a setting between shared and local, since that changes who sees it |
| Skills | `.claude/skills/<name>/` | Whole directory, supporting files included. **A same-name skill is skipped, but say whether the contents differ** — two skills sharing a name while holding different files is the fact the user needs, and reporting a bare "skipped" hides it. Compare the directories and, when they diverge, name what each side has |
| Subagents | `.claude/agents/*.md` | Same frontmatter rules as home scope |
| Commands | `.claude/commands/*.md` | Same substitution rules as home scope |
| Vendor-neutral skills | `.agents/skills/<name>/` | **Not listed in any tool's own inventory** — it is a shared project surface. procedure.md's "`.agents/` is shared, not migratable" rule governs it: migrate it when this target does not read the path natively, leave it alone when it does. Never skip it just because it is absent from the table above |

`.claude/settings.local.json` is personal configuration that repositories usually gitignore — but not always. Report its git status like any other file rather than assuming.
