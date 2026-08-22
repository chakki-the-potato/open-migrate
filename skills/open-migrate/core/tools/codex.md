# Codex CLI (OpenAI)

Home: `$CODEX_HOME` (defaults to `~/.codex`). Use this doc both when reading Codex as a source and when writing to it as a target.

## Detection

Consider it installed when `~/.codex/config.toml` or `~/.codex/AGENTS.md` exists.

## Config inventory (read)

| Category | Location | Format |
|---|---|---|
| Global rules | If `AGENTS.override.md` exists, read **only that** and ignore `AGENTS.md` entirely. Read `AGENTS.md` only when the override is absent | Markdown with `@path` import support. Never migrate, merge, or even quote the contents of an ignored `AGENTS.md` in the report |
| Skills | `skills/<name>/SKILL.md` | agent-skills standard; copy as-is. Exclude everything under `skills/.system/` (tool built-ins). Vendor distributions (shipped with LICENSE/NOTICE) and plugin-provided skills are not owned by the user — flag them separately in the report and let the user decide whether to migrate them |
| Custom prompts | `prompts/*.md` (deprecated) | Plain markdown with `$1`-`$9` / `$ARGUMENTS` substitution |
| Hooks | `hooks.json` (primary) or inline `[[hooks.Event]]` in `config.toml` | Same JSON structure as Claude. Note: `[hooks.state]` in `config.toml` is a trust-hash cache, not a hook definition — it is not migratable and the target regenerates it |
| Permission rules | `rules/*.rules` | Starlark `prefix_rule(pattern=[...], decision=...)` |
| Subagents | `agents/*.toml` | TOML with `description` and `developer_instructions` |
| Env injection | `[shell_environment_policy]` in `config.toml` — migrate the `set` table only. `inherit`, `exclude`, and `include_only` are inheritance policy rather than value injection, and no target has a corresponding concept (Grok reuses the table name, but those are policy fields there too) → record as not migratable in the report | TOML |
| Approval policy | `approval_policy` and `sandbox_mode` in `config.toml` | Approximate mapping only |
| Model / personality | top-level keys in `config.toml` such as `model` and `personality` | Not migrated — quote the key and its **current value** verbatim in the report |
| Project trust | `[projects."<path>"]` in `config.toml` | Not migratable — mention only |
| Plugins / marketplaces | `[plugins."<name>@<market>"]`, `[marketplaces.*]`, and `plugins/cache/` in `config.toml` | Not migrated — plugins must be reinstalled from their marketplace. But **a large share of skills, subagents, and hooks are plugin-provided**, so identify which items a plugin owns before migrating and list the marketplace and plugin names in the report, letting the user decide whether reinstalling covers it |
| Project hooks | `<repo>/.codex/hooks.json` | Outside the scope of a global migration — if you find one, just mention it in the report |
| Keybindings | `keybindings.json` | Command systems differ — not migratable, mention only |
| Never read | `auth.json`, `sessions/`, `history.jsonl`, `*.sqlite`, `.codex-global-state.json` | security.md applies |

## Conversion rules (Codex → other tools)

### Hooks
- The 11 official events: SessionStart, SessionEnd, SubagentStart, SubagentStop, PreToolUse, PermissionRequest, PostToolUse, PreCompact, PostCompact, UserPromptSubmit, Stop. All share Claude's names — no event-name conversion needed.
- **If `hooks.json` contains an event outside those 11** (dead config that Codex silently ignores): check the target tool doc's valid-event list and migrate unchanged if the same name exists there; otherwise drop it and record it in the report. Example: `Notification` is unofficial in Codex but exists in Claude — migrate it.
- Codex's native tool names include `read_file`, `grep_files`, and `apply_patch` alongside the shell family. Map the obvious ones by function — `read_file`→`Read`, `grep_files`→`Grep` — and for any name not listed here, do not invent a mapping: drop the matcher and record the original name, since a guessed matcher silently scopes a hook to the wrong tool or to nothing.
- Tool-name matchers: `apply_patch` → the target's edit tool. Claude and Grok split this into two tools, so match both via a regex alternation (`Edit|Write`); Cursor has only `Write`. The `shell` / `local_shell` / `exec_command` variants → `Bash` for Claude and Grok, `Shell` for Cursor. `mcp__server__tool` is identical on every target. **If the target doc has its own tool-name mapping table, that table wins.**
- The timeout unit is seconds on both sides.
- **A matcher can be a regex alternation, not one tool name.** `Edit|Write|apply_patch` and
  `Bash|shell|local_shell|read_file|grep_files|mcp__.*` are both ordinary Codex matchers, and
  real config is full of them. Split on `|`, map each alternative with the rules above, join the
  survivors back with `|`, and **de-duplicate** — several Codex names collapse onto one target
  name (`shell`, `local_shell`, `exec_command` all become `Bash`), so a naive join repeats it.
  An alternative may also *expand*: `apply_patch` becomes `Edit|Write` on Claude and Grok.
- **Alternatives you cannot map are dropped from the alternation, not guessed at, and each one
  is named in the report.** Three kinds turn up. A name from a third tool's vocabulary — a
  Codex config can carry `Shell`, which is Cursor's — has no meaning on either side here.
  A name from the *target's* vocabulary that Codex never had (`Read`, `Grep`, `AskUserQuestion`)
  passes through unchanged, since it is already what the target calls that tool. And a regex
  alternative such as `mcp__.*` is a pattern rather than a tool name — carry it over verbatim,
  because MCP tool names are identical on every target.
- **If every alternative drops, drop the whole hook entry** and record it with its original
  matcher. A hook whose matcher became empty does not match nothing — an empty matcher matches
  *everything* on Claude, which silently widens the hook to every tool call.

### Custom prompts (prompts/*.md → the target's commands)
- The surface is deprecated, but migrate it when present. **The target doc decides the destination and format** — write to the target's command file if it has one (Claude's `commands/<name>.md`), otherwise to whatever surface the target doc designates (skills for Cursor and Grok). Carry the file contents over unchanged.
- Keep `$1`-`$9` / `$ARGUMENTS` substitution tokens **verbatim**. If the target does not support substitution the tokens remain as literal text; record that as a loss in the report and do not edit the body.

### Permission rules (rules DSL)
- Decision mapping: `allow`→allow, `prompt`→ask, `forbidden`→deny.
- `pattern=["git","status"]` → `Bash(git status:*)`.
- If an element is itself a list, expand every combination: `["npm","run",["build","test"]]` → `Bash(npm run build:*)` plus `Bash(npm run test:*)`.

**Most real rules do not survive this conversion. Check before converting each one.**

An argv-prefix rule is a list of exact literals; a target's permission string is a pattern with its own syntax. A rule converts only when joining its tokens with spaces produces something the target can actually match. Skip the rule and list it verbatim under manual action when any of these hold:

- **A token contains a quote, a parenthesis, or a shell metacharacter.** `Bash(...)` ends at the first `)`, so a rule holding an inline script — `node -e "const fs=require(\"fs\")…"` — produces a truncated pattern that matches nothing.
- **A token contains whitespace.** Joining on spaces makes the boundary between tokens indistinguishable from the space inside one, and the result no longer describes the same command.
- **The joined string runs past roughly 200 characters.** A prefix that long is a full command line, not a prefix; it will never match anything but itself, and it buries the rules that do work.

This is not a rare edge. On the real machine this rule was written against, a `rules/default.rules` of 353 entries yielded only about a third that convert — the rest are `/bin/zsh -lc "…"` and `node -e "…"` wrappers. Converting them anyway produced 43 permission entries over 200 characters, the longest 806, none of which can ever match.

**Report the count.** "245 of 353 rules could not be expressed as target permissions" is the useful sentence; a target whose allow list silently grew from 2 entries to 334 tells the user nothing about what happened.

### Subagents (TOML → md)
`agents/<name>.toml` → `<name>.md`:

```markdown
---
name: <filename>
description: <the description value>
---

<the developer_instructions value>
```

## Write rules (when Codex is the target)

| Category | Write location | How |
|---|---|---|
| Global rules | `AGENTS.md` | Append a `## Migrated from <source> (<date>)` section at the end of the file, **verbatim** (never summarize or rewrite). Keep the `@import` lines from both the source and the existing file. Never delete existing content. Copy the original to `.migrate/<run-id>/backup/AGENTS.md` before writing. **Caution: if the target has an `AGENTS.override.md`, `AGENTS.md` is ignored** — when it exists, stop the merge and ask the user which file to write |
| Skills | `skills/<name>/` | Copy the whole directory including supporting files. If a skill with the same name exists, skip it and record it in the report |
| Commands / prompts | `prompts/<name>.md` | Plain markdown, unchanged. Keep `$1`-`$9` / `$ARGUMENTS` substitution tokens verbatim. Codex treats this surface as deprecated and recommends skills, so migrate it but add a "consider moving this to a skill" note in the report |
| Subagents | `agents/<name>.toml` | The source filename (or the frontmatter `name`) becomes the **filename** — do not write a `name` key inside the TOML. `description = "<source description>"`, `developer_instructions = '''<source body>'''` |
| Hooks | `hooks.json` | The top-level structure must be `{"hooks": {...}}` — a wrong top-level key makes the whole file ignored. Append to the existing arrays; skip identical commands |
| Permissions | `rules/<name>.rules` | See "Permission write syntax" below |
| Env injection | `[shell_environment_policy.set]` in `config.toml` | Merge per key, preserving existing keys |
| Approval policy | — | **Never set `approval_policy` or `sandbox_mode` automatically.** Put the approximate mapping in the report as a suggestion only |

### Hook event conversion (other tools → Codex)

- Codex has exactly 11 official events: SessionStart, SessionEnd, SubagentStart, SubagentStop, PreToolUse, PermissionRequest, PostToolUse, PreCompact, PostCompact, UserPromptSubmit, Stop.
- **Drop every event outside those 11 and record it in the report.** Codex silently ignores them, which would leave dead config behind. Claude's `Notification`, `ConfigChange`, `PostToolUseFailure`, and `WorktreeCreate` fall in this group.
- One exception: `PostToolUseFailure` can be merged into `PostToolUse`, because Codex's `PostToolUse` also fires on failure.
- Tool-name matchers: Claude `Edit` and `Write` → `apply_patch`. Claude `Bash` → `Bash` (Codex normalizes the shell family to that name). Claude-only tools (`Read`, `Grep`, `Glob`, `WebFetch`) have no first-class equivalent in Codex and would become dead patterns — drop and record them.
- Types other than `command` (http, mcp_tool, prompt, agent) are unsupported by Codex — skip and record.

### Permission write syntax (other tools → Codex rules DSL)

- The file can have any name under `rules/` (for example `rules/migrated.rules`). The syntax is Starlark.
- Form: `prefix_rule(pattern=["<token>", ...], decision="<decision>")` — **the `decision` value must be a double-quoted string.** An unquoted `decision=allow` is a syntax error.
- Decision mapping: allow→`"allow"`, ask→`"prompt"`, deny→`"forbidden"`.
- Pattern conversion: `Bash(git status:*)` → `pattern=["git", "status"]`. Split on whitespace and discard the trailing `:*`.
- Write each rule on its own line even when several share a prefix — the positional union form (`["build", "test"]`) is a read-side optimization and is not used when writing.
- **Only Bash prefix rules are convertible.** Path rules (`Read`/`Edit`), domain rules (`WebFetch`), MCP rules, and any pattern needing a mid-string wildcard cannot be expressed in this DSL — do not convert them; list the originals verbatim under manual action.

## Project scope surfaces

Read these when Codex is the source in a project migration; write these when it is the target. Paths are relative to the project root.

| Category | Location | Notes |
|---|---|---|
| Global rules | `AGENTS.md` | `AGENTS.override.md` takes precedence here exactly as in home scope |
| Settings | `.codex/config.toml` | Only some sections load at project level. Migrate permission rules; leave model, approval policy, and sandbox to home scope |
| Hooks | `.codex/hooks.json` | Same `{"hooks": {...}}` structure as home scope |
| Skills | `.codex/skills/<name>/` | Whole directory |
| Permission rules | `[permission]` inside `.codex/config.toml` | **Not `rules/*.rules`.** The Starlark rules DSL is a home-scope surface; at project level the rules live inside `config.toml`. Convert accordingly rather than looking for a `.codex/rules/` directory |
| Subagents | **No project surface** | Codex reads subagents only from `$CODEX_HOME/agents/`. A source's project-level subagents cannot be migrated to Codex project scope — record them under manual action with their source location |
| Commands / prompts | **No project surface** | Same as subagents: `prompts/` is home-scope only |
| Env injection | **No project surface** | `[shell_environment_policy]` loads from the home `config.toml` only |
| Vendor-neutral skills | `.agents/skills/<name>/` | **Not listed in any tool's own inventory** — it is a shared project surface. procedure.md's "`.agents/` is shared, not migratable" rule governs it: migrate it when this target does not read the path natively, leave it alone when it does. Never skip it just because it is absent from the table above |

Categories with "No project surface" are not oversights — record each as impossible in the report rather than inventing a path. Writing `.codex/agents/` or `.codex/prompts/` produces files Codex never reads.

**Trust gate — read this before writing anything.** Codex ignores a project's `.codex/config.toml`, `.codex/hooks.json`, and skills layer unless `~/.codex/config.toml` contains a trust entry for that project:

```toml
[projects."/absolute/path/to/project"]
trust_level = "trusted"
```

Without it, everything you write into `.codex/` is a file the tool never reads. **Do not add the trust entry yourself** — trusting a repository is a security decision belonging to the user. Instead, check whether the entry already exists and, if it does not, put it in the report's manual-action list with the exact TOML block above and the project's absolute path filled in.

**Whether trust is inherited by subdirectories has not been confirmed.** A project may have no entry of its own while an ancestor path does. Do not assert either way — report both facts: that the project itself has no entry, and that an ancestor (name it) does. Anything stronger would be a guess, and the two readings lead to opposite conclusions about whether the config was ever active.

**When Codex is the source**, the same entry tells you something different: whether the config you are reading was ever live. A project `.codex/` layer with no trust entry is configuration Codex has been ignoring. Migrate it anyway — the user wrote it and presumably wants it — but say so in the report, because a rule that never took effect in the source may behave differently once it becomes active on the target.
