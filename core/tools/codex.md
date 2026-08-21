# Codex CLI (OpenAI)

Home: `$CODEX_HOME` (defaults to `~/.codex`). Use this doc both when reading Codex as a source and when writing to it as a target.

## Detection

Consider it installed when `~/.codex/config.toml` or `~/.codex/AGENTS.md` exists.

## Config inventory (read)

| Category | Location | Format |
|---|---|---|
| Global rules | If `AGENTS.override.md` exists, read **only that** and ignore `AGENTS.md` entirely. Read `AGENTS.md` only when the override is absent | Markdown with `@path` import support. Never migrate, merge, or even quote the contents of an ignored `AGENTS.md` in the report |
| MCP | `[mcp_servers.<name>]` in `config.toml` | TOML. stdio uses command/args/env. HTTP is identified by the presence of a `url` key (plus optional http_headers / bearer_token_env_var). `enabled=false` means disabled |
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
- Tool-name matchers: `apply_patch` → the target's edit tool. Claude and Grok split this into two tools, so match both via a regex alternation (`Edit|Write`); Cursor has only `Write`. The `shell` / `local_shell` / `exec_command` variants → `Bash` for Claude and Grok, `Shell` for Cursor. `mcp__server__tool` is identical on every target. **If the target doc has its own tool-name mapping table, that table wins.**
- The timeout unit is seconds on both sides.

### Custom prompts (prompts/*.md → the target's commands)
- The surface is deprecated, but migrate it when present. **The target doc decides the destination and format** — write to the target's command file if it has one (Claude's `commands/<name>.md`), otherwise to whatever surface the target doc designates (skills for Cursor and Grok). Carry the file contents over unchanged.
- Keep `$1`-`$9` / `$ARGUMENTS` substitution tokens **verbatim**. If the target does not support substitution the tokens remain as literal text; record that as a loss in the report and do not edit the body.

### Permission rules (rules DSL)
- Decision mapping: `allow`→allow, `prompt`→ask, `forbidden`→deny.
- `pattern=["git","status"]` → `Bash(git status:*)`.
- If an element is itself a list, expand every combination: `["npm","run",["build","test"]]` → `Bash(npm run build:*)` plus `Bash(npm run test:*)`.

### Subagents (TOML → md)
`agents/<name>.toml` → `<name>.md`:

```markdown
---
name: <filename>
description: <the description value>
---

<the developer_instructions value>
```

### MCP (TOML → target format)
- stdio: carry command/args/env over unchanged. HTTP: url plus headers.
- `http_headers` values are subject to security.md secret detection.
- Do not migrate servers with `enabled=false`; record them in the report.

## Write rules (when Codex is the target)

| Category | Write location | How |
|---|---|---|
| Global rules | `AGENTS.md` | Append a `## Migrated from <source> (<date>)` section at the end of the file, **verbatim** (never summarize or rewrite). Keep the `@import` lines from both the source and the existing file. Never delete existing content. Copy the original to `.migrate/<run-id>/backup/AGENTS.md` before writing. **Caution: if the target has an `AGENTS.override.md`, `AGENTS.md` is ignored** — when it exists, stop the merge and ask the user which file to write |
| MCP | `[mcp_servers.<name>]` in `config.toml` | stdio: `command`/`args`/`env` (sub-table `[mcp_servers.<name>.env]`). HTTP: `url` plus `[mcp_servers.<name>.http_headers]` when needed. API-key style headers that are not `Bearer` auth go in `http_headers`, not `bearer_token_env_var`. Replace secret values with `<REDACTED-REENTER>` and list them under manual action. **If a server with the same name exists, do not overwrite — skip and record in the report** |
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
| Settings | `.codex/config.toml` | Only some sections load at project level. Migrate MCP servers and permission rules; leave model, approval policy, and sandbox to home scope |
| Hooks | `.codex/hooks.json` | Same `{"hooks": {...}}` structure as home scope |
| Skills | `.codex/skills/<name>/` | Whole directory |

**Trust gate — read this before writing anything.** Codex ignores a project's `.codex/config.toml`, `.codex/hooks.json`, and skills layer unless `~/.codex/config.toml` contains a trust entry for that project:

```toml
[projects."/absolute/path/to/project"]
trust_level = "trusted"
```

Without it, everything you write into `.codex/` is a file the tool never reads. **Do not add the trust entry yourself** — trusting a repository is a security decision belonging to the user. Instead, check whether the entry already exists and, if it does not, put it in the report's manual-action list with the exact TOML block above and the project's absolute path filled in.
