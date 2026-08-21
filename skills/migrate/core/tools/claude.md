# Claude Code (Anthropic)

Home: `~/.claude` (plus `~/.claude.json`). In test mode, use the target root the user specified instead of `~/.claude`.

## Detection

Consider it installed when `~/.claude/settings.json` or `~/.claude/CLAUDE.md` exists.

## Write rules (when Claude is the target)

| Category | Write location | How |
|---|---|---|
| Global rules | `CLAUDE.md` | Append a `## Migrated from <source> (<date>)` section at the end of the file, **verbatim** (never summarize or rewrite). Keep both the source's `@import` lines and the existing file's `@import` lines as-is. Never delete existing content. Copy the original to `.migrate/<run-id>/backup/CLAUDE.md` before modifying |
| MCP | `claude mcp add` CLI | **If a server with the same name already exists on the target, skip registration and record it in the report** (never decide on your own even when the definitions differ — ask in Confirm). In real environments most active servers already exist under the same name. Check the existing list in all of: `mcpServers` and `projects[<path>].mcpServers` in `~/.claude.json`, the project's `.mcp.json`, and `~/.claude/mcp.json`. **Never edit `~/.claude.json` directly** (official guidance). stdio: `claude mcp add --scope user [--env KEY=VALUE ...] <name> -- <command> [args...]` — the `--` separator before server arguments is required (without it, arguments starting with a dash like `-y` get misparsed). Example: `claude mcp add --scope user --env LOG_LEVEL=info everything -- npx -y @modelcontextprotocol/server-everything`. HTTP: `claude mcp add --scope user --transport http <name> <url> [--header "K: V"]`. **Choosing a remote transport**: `--transport` accepts `stdio`, `http`, and `sse`, but `sse` is officially deprecated. When the source expresses both sse and http through a single url field (Cursor, for example) and the transport cannot be determined, **use `http`** and record in the report that the source carried no transport marker so http was assumed. Use `--transport sse` only when the source states sse explicitly, and mention that it is deprecated. Both env values and header values are subject to security.md secret detection — replace secrets with `<REDACTED-REENTER>` and list them under manual action |
| Skills | `skills/<name>/SKILL.md` | Copy the whole directory. If a skill with the same name exists, skip it and record it in the report |
| Commands | `commands/<name>.md` | Plain markdown. `$1`-`$9` and `$ARGUMENTS` substitution is supported — keep the source's substitution tokens verbatim |
| Hooks | `hooks` key in `settings.json` | Structure: `{Event: [{matcher, hooks: [{type:"command", command, timeout}]}]}`. Append to the existing hook arrays — skip when the command is identical. Treat **near-duplicates** (same script invoked with different path notation or flags) as skip candidates and confirm in Confirm (the strings differ, so this cannot be decided automatically — ask the user). Valid events: every event the **source** tool doc lists (8 from cursor.md's hook event table when the source is Cursor; codex.md's common events when it is Codex), plus Claude extension events such as Notification, PermissionDenied, PostToolUseFailure, ConfigChange, WorktreeCreate (accept these as-is when the names match). For an event name outside that list, verify it is an official Claude hook event; if you cannot confirm it, drop it and record it in the report |
| Permissions | `permissions.allow` / `deny` / `ask` in `settings.json` | Append to the arrays and de-duplicate. The official docs recommend `/permissions` inside a session, but a bulk migration merges directly — a deliberate deviation, justified by the backup, the jq validation, and the restore-on-failure path. Never set `defaultMode` automatically — put the approximation table in the report as a suggestion only |
| Env | `env` object in `settings.json` | Merge per key. If an existing key has a different value, that is a conflict — ask the user |
| Subagents | `agents/<name>.md` | Frontmatter: `name` and `description` (required), `tools` and `model` (optional). The body is the system prompt. Valid `model` values: aliases like `opus`/`sonnet`/`haiku`, a full model ID, or `inherit` (use the main conversation's model). **`inherit` is a value several tools share, so carry it over as-is when the source has it** — that is lossless. For any value outside this list (another vendor's model name, for example), do not write the field; quote the source value in the report for manual review instead (never guess a value). **If a file with the same name exists, do not overwrite it — skip and record in the report.** In real environments the same plugin is often installed on both sides, which makes every name collide |

## settings.json merge rules

1. Copy the original to `.migrate/<run-id>/backup/settings.json` before modifying.
2. Deep merge: merge objects per key, append to arrays then de-duplicate, preserve existing scalar values.
3. Validate with `jq -e . settings.json` after writing. On failure, restore from the backup, then stop and report.

## MCP command execution rules

- Real environment (target is the actual `~/.claude`): run `claude mcp add` directly and verify with `claude mcp list`.
- Test mode (target root is not the real home): do not execute; emit the command list to `.migrate/<run-id>/mcp-commands.sh` instead.
- **Project scope: write `.mcp.json` directly, never the CLI.** The two cases above are both home scope. A project's MCP servers live in the repository's `.mcp.json`, so write that file and still emit `mcp-commands.sh` as an audit record of what went in. Do not run `claude mcp add` for project scope — its scope flags govern the user's own configuration, not the repository's.
- In all cases, always generate `mcp-commands.sh` as an audit record. **This rule applies only when Claude is the target** — other targets write MCP into config files rather than through a CLI, so there are no commands to emit and the file is not created.
- `mcp-commands.sh` format: `#!/usr/bin/env bash` on the first line, one command per server, and a comment for anything that needs checking before execution (secret re-entry, possible name collision). It does not need the executable bit — the user reviews it and runs it themselves.

## `~/.claude.json` in test mode

`~/.claude.json` lives **outside** the `~/.claude` directory. Its test-mode location follows procedure.md's "Path resolution in test mode" rule: **`<root>/.claude.json`**. Never read the real `~/.claude.json` — this also aligns with security.md forbidding you to read that file's other keys.

## Read inventory (when Claude is the source)

| Category | Location | Notes |
|---|---|---|
| Global rules | `~/.claude/CLAUDE.md` | **Carry `@path` import lines over verbatim and do not expand them** — never open the referenced file and inline it |
| MCP | top-level `mcpServers` in `~/.claude.json` (user scope), `projects["<path>"].mcpServers` (local scope), the project's `.mcp.json`, and `~/.claude/mcp.json` (non-standard but seen in practice) | **All four are migration sources** — not merely "places to check for conflicts". Migrate the servers you find here. Server definition fields: stdio uses `command`/`args`/`env`; remote uses `url`/`headers` plus optional `type` (`http`\|`sse`). When handing off to the target, carry `type` only if the target distinguishes transports; drop it for targets with no such concept (TOML-based tools infer it from the presence of `url`). Map `headers` to the target's header field name (`http_headers` for Codex and Grok). If the same server appears in several places, migrate it once and note the duplicate sources in the report |
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
| Global rules | `CLAUDE.md`, or `.claude/CLAUDE.md` | If both exist, migrate both and keep them separated per file (procedure.md's merge format) |
| MCP | `.mcp.json` | Same server definition fields as the home-scope `mcpServers` object. **Write the file directly — do not use `claude mcp add` here.** The CLI rule in the write-rules table above governs home scope; this row is the more specific rule and wins for project scope (procedure.md precedence 3). Still emit `.migrate/<run-id>/mcp-commands.sh` as an audit record of what was written |
| Settings | `.claude/settings.json` (shared), `.claude/settings.local.json` (personal) | Same schema as home `settings.json`: `hooks`, `permissions`, `env`. Merge each into the matching file — never move a setting between shared and local, since that changes who sees it |
| Skills | `.claude/skills/<name>/` | Whole directory, supporting files included |
| Subagents | `.claude/agents/*.md` | Same frontmatter rules as home scope |
| Commands | `.claude/commands/*.md` | Same substitution rules as home scope |

`.claude/settings.local.json` is personal configuration that repositories usually gitignore — but not always. Report its git status like any other file rather than assuming.
