# Grok Build (xAI)

Home: `~/.grok` (relocatable via the `GROK_HOME` environment variable). The main config is a single `~/.grok/config.toml`; only rules, skills, subagents, and hooks use separate directories. Use this doc both when reading Grok as a source and when writing to it as a target.

This doc covers xAI's official **Grok Build** (`grok`). The similarly named community CLI (`superagent-ai/grok-cli`, npm `grok-dev`) stores its configuration somewhere else entirely (`mcp.servers` and `hooks` inside `~/.grok/user-settings.json`) — **do not apply this doc to that tool.** If the home has `user-settings.json` but no `config.toml`, it is not Grok Build: stop and tell the user.

Grok Build looks like a union of the other tools — **hooks and permissions have Claude's shape**, while **MCP and env injection have Codex's shape**. That is why most conversion rules here amount to "carry it over unchanged".

## Detection

Consider it installed when `~/.grok/config.toml` exists. If `GROK_HOME` is set, use that path as the home.

## Config inventory (read)

| Category | Location | Format |
|---|---|---|
| Global rules | every `~/.grok/rules/*.md` (any filename, loaded alphabetically) plus `~/.grok/AGENTS.md` | Plain markdown. The named files recognized in the home are `AGENTS.md`, `AGENT.md`, `CLAUDE.md`, `CLAUDE.local.md`, and similar — **`GROK.md` is not read** |
| MCP | `[mcp_servers.<name>]` in `~/.grok/config.toml` | TOML, same shape as Codex: stdio uses `command`/`args` plus the sub-table `[mcp_servers.<name>.env]`; remote uses `url` plus `[mcp_servers.<name>.http_headers]`. `enabled = false` marks it disabled |
| Skills | `~/.grok/skills/<name>/SKILL.md` | agent-skills standard layout including supporting files. Frontmatter `user-invocable: true` exposes the skill as a slash command |
| Commands / prompts | **No surface** | There is no dedicated command directory — slash commands are built as skills |
| Subagents | `~/.grok/agents/<name>.md` | YAML frontmatter (**camelCase**) plus the body (system prompt). Required: `name`, `description`. Full set of optional fields: `model`, `tools`, `color`, `promptMode` (`extend`\|`full`), `capabilityMode`, `permissionMode`, `disallowedTools`, `effort`, `maxTurns`, `isolation`, `background`, `skills`, `discoverSkills`, `inheritSkills`, `agentsMd`, `injectDefaultTools`, `initialPrompt`, `mcpServers`. **This row is the single list of Grok's fields** — other sections reference it instead of repeating the list |
| Hooks | `~/.grok/hooks/*.json` (and inline in `config.toml`) | **The JSON structure is identical to Claude Code's**: `{"hooks": {"<Event>": [{"matcher": "...", "hooks": [{"type": "command", "command": "...", "timeout": 10}]}]}}`. Event names are PascalCase too. `timeout` is in seconds |
| Permission rules | `[permission]` in `~/.grok/config.toml` | Two forms. (1) Compact string arrays `allow`/`ask`/`deny`, where the rule strings use **Claude's syntax** (`Bash(git status:*)`, `Read(src/**)`, `Edit(**/*.rs)`, `Grep`, `WebFetch(domain:example.com)`, `MCPTool(server__tool)`). (2) Structured `rules = [{ action = "allow\|deny\|ask", tool = "bash\|read\|edit\|grep\|mcp\|webfetch\|websearch", pattern = "git *" }]`. Merge precedence is deny > ask > allow |
| Env injection | `[shell_environment_policy]` in `~/.grok/config.toml` | Same table name and structure as Codex. Injected values go in the sub-table `[shell_environment_policy.set]` |
| Approval policy | `[ui] permission_mode` in `~/.grok/config.toml` | Values: `default` (ask), `acceptEdits`, `auto`, `dontAsk`, `bypassPermissions` (product name: always-approve), `plan`. Only three of these have a row in procedure.md's mapping table — for the rest, quote the current value and suggest nothing |
| Sandbox | `[sandbox] profile` in `~/.grok/config.toml` (custom profiles in `[profiles.<name>]` of `~/.grok/sandbox.toml`) | Values: `off`, `workspace`, `devbox`, `read-only`, `strict`. **Not migrated** — this is OS-level isolation whose meaning differs per tool, so no equivalent mapping exists. Quote the current value in the report only |
| Model | `model` in `~/.grok/config.toml` | Not migrated — quote the key and its **current value** verbatim in the report |
| Never read | `~/.grok/auth.json`, `~/.grok/sessions/`, `~/.grok/memory/` | security.md applies. `memory/` is plain markdown and technically copyable, but it is conversation content rather than configuration, so it is **excluded by default** |

## Conversion rules (Grok → other tools)

### Global rules
- Read both `rules/*.md` and `AGENTS.md` and merge them verbatim into the target's global rule file (never summarize or rewrite). For the merge section and subheading format, follow procedure.md's "Global-rule merge format". Grok's load order is **alphabetical by filename**.
- Carry `@path` import lines over verbatim; never expand them.
- Filenames Grok does not recognize, such as `GROK.md`, are **not migration targets** — if you find one, do not move it; record it in the report as "a file Grok does not read".

### MCP
- `[mcp_servers.<name>]` → the target's MCP format. The table shape matches Codex, so apply codex.md's MCP conversion rules directly.
- Do not migrate servers with `enabled = false`; record them in the report.
- Values in `[mcp_servers.<name>.http_headers]` and `.env` are subject to security.md secret detection.

### Skills
- Copy the `SKILL.md` directory including supporting files, unchanged.
- `user-invocable: true` is a Grok-specific frontmatter key. If the target does not use the same key, **drop only that key and keep the rest of the frontmatter and the body**, then record it in the report.
- **This key drop wins even when the target doc says to "copy the whole directory".** When a general rule (copy unchanged) collides with a specific one (this key is invalid on the target), follow the specific rule — the same holds in every other category.

### Subagents
- The frontmatter is camelCase. `name` and `description` are common to every tool, so map them directly.
- `model` has a different value space per tool — follow the target doc's subagent rule (carry over only values both sides share, such as `inherit`; drop the rest and record in the report).
- Carry `tools` and `color` only when the target has a field of the same name (Claude has both).
- **Derive the rest from the inventory row above** — everything other than `name`, `description`, `model`, `tools`, and `color` is Grok-only, so drop it when the target has no field of the same name and record the key name in the report. The list is not repeated here because two copies drift apart; the test is always the single question "does the target doc have this field?"

### Hooks
- **No structural conversion is needed.** The `hooks` object in a Grok hook file has the same shape as the `hooks` value in Claude's `settings.json` — when Claude is the target, extract that object and merge it as-is.
- Grok's 15 events: `SessionStart`, `SessionEnd`, `UserPromptSubmit`, `Stop`, `StopFailure`, `StopCancelled`, `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `PermissionDenied`, `SubagentStart`, `SubagentStop`, `Notification`, `PreCompact`, `PostCompact`.
- Event handling **follows the target doc** — Claude shares the event names so nothing is converted (apply claude.md's valid-event rule in its hook row); Codex drops anything outside its official 11 (codex.md); Cursor converts to its 8 camelCase names (cursor.md). For an event name outside the 15 above, do not guess — drop and record.
- `type` is either `command` or `http`. The `http` type has no equivalent in the other tools — drop and record.
- Matchers are tool names and use Claude's names (`Bash`, `Read`, `Edit`, `Write`, `Grep`) — no conversion when going to Claude; for other targets, apply that doc's tool-name matcher mapping.

### Permission rules
- The compact string form (`allow`/`ask`/`deny` arrays) uses **the same syntax as Claude — carry the values over unchanged.** The `ask` tier exists on both sides, so nothing is lost.
- If they are written in the structured form (`rules = [{action, tool, pattern}]`), normalize to compact strings first. Convert `tool` to its PascalCase tool name (`bash`→`Bash`, `read`→`Read`, `edit`→`Edit`, `grep`→`Grep`, `webfetch`→`WebFetch`, `websearch`→`WebSearch`, `mcp`→`MCPTool`), wrap `pattern` in parentheses to form `<Tool>(<pattern>)`, and put it in the array matching `action`. When there is no `pattern`, write the tool name alone without parentheses (`Grep`).
- Per-target losses follow the target doc — Cursor has no `ask` tier (cursor.md), and Codex can only express Bash prefix rules (codex.md).

### Env injection
- `[shell_environment_policy.set]` → the target's global env surface. The structure matches Codex, so apply codex.md's env rules directly.
- For a target with no global env surface, such as Cursor, this is not migratable — record the key names and their source locations under manual action.

### Approval policy
- `[ui] permission_mode` → use procedure.md's approximation table as a report suggestion only. Never set it automatically.

## Write rules (when Grok is the target)

| Category | Write location | How |
|---|---|---|
| Global rules | `~/.grok/AGENTS.md` | Append a `## Migrated from <source> (<date>)` section at the end of the file, **verbatim** (never summarize or rewrite). Keep the `@import` lines from both the source and the existing file. Never delete existing content. Copy the original to `.migrate/<run-id>/backup/AGENTS.md` before writing. Do not write into `rules/` — a single file is easier to trace, and since every `rules/*.md` is loaded, the effect is identical wherever you write |
| MCP | `[mcp_servers.<name>]` in `config.toml` | stdio: `command`/`args` plus `[mcp_servers.<name>.env]`. remote: `url` plus `[mcp_servers.<name>.http_headers]`. Replace secret values with `<REDACTED-REENTER>` and list them under manual action. **If a server with the same name exists, do not overwrite — skip and record in the report** |
| Skills | `~/.grok/skills/<name>/` | Copy the whole directory including supporting files. **If a skill with the same name exists, skip and record in the report** |
| Commands / prompts | `~/.grok/skills/<name>/SKILL.md` (migrate as a skill, not a command) | Grok has no command surface. Wrap the source command in `name`/`description` frontmatter and convert it to a skill; add `user-invocable: true` if it should be usable as a slash command. `name` is the source filename without its extension. If the source has no `description`, do not invent one — use the body's first sentence verbatim and record in the report that it was synthesized. Leave the source's `$1`-`$9` / `$ARGUMENTS` substitution tokens exactly as they are |
| Subagents | `~/.grok/agents/<name>.md` | Write the YAML frontmatter in **camelCase**. `name` and `description` carry over unchanged. Convert snake_case or kebab-case keys from the source to camelCase. Source-only keys with no corresponding field here (Cursor's `readonly`, `is_background`) are dropped and recorded. **Do not drop `color` — Grok has that field too** (see the inventory row above). **If a file with the same name exists, do not overwrite — skip and record in the report** |
| Hooks | `~/.grok/hooks/migrated.json` | The top-level structure must be `{"hooks": {...}}`. When the source is Claude, insert the `hooks` value from `settings.json` **without conversion**. If the file already exists, append to the arrays and skip identical commands. Drop and record any event name outside the 15 above, and any entry whose `type` is neither `command` nor `http` |
| Permissions | the `allow`/`ask`/`deny` arrays under `[permission]` in `config.toml` | When the source is Claude, append the rule strings **verbatim** (de-duplicating). When the source is Cursor, rename `Shell(...)` → `Bash(...)` (the same rename as in cursor.md's permission rules). When the source is Codex, reverse the DSL: `prefix_rule(pattern=["git","status"], decision="allow")` → `Bash(git status:*)` — join the tokens with spaces, append `:*`, and map decisions `prompt`→`ask` and `forbidden`→`deny`. Do not write the structured `rules = [...]` form; the compact arrays stay closer to the source syntax |
| Env injection | `[shell_environment_policy.set]` in `config.toml` | Merge per key, preserving existing keys. Never resolve a same-name key with a different value on your own — ask the user |
| Approval policy | — | **Never set `[ui] permission_mode` automatically.** Put the approximate mapping in the report as a suggestion only |

## TOML config merge rules

`config.toml` is TOML, so the general-purpose merge tooling that works for JSON does not apply. Follow these rules.

1. Copy the original to `.migrate/<run-id>/backup/config.toml` before modifying.
2. **Never parse the whole file and re-serialize it** — that destroys comments and key order. Make minimal edits instead.
   - **Append new tables** (`[mcp_servers.<name>]` and the like) **at the end of the file.** In TOML every line after a table header belongs to that table, so adding a new header cleanly separates it even when an existing table block (`[permission]`, say) sits at the end of the file.
   - To add a **new key** to an existing table, insert the line inside that table's block.
   - To **extend an existing array value** (adding entries to `allow = [...]`), rewrite that single line in place. This is not an exception to "never re-serialize" but a form of minimal editing — an array's line *is* the whole value, so there is nothing else to touch. Preserve the order of existing elements, append after them, and de-duplicate.
3. Quoting: wrap string values in double quotes. Write booleans and integers unquoted. Quote each array element individually when the elements are strings.
4. Validate the TOML after writing (`python3 -c "import tomllib,sys;tomllib.load(open(sys.argv[1],'rb'))" config.toml`). On failure, restore from the backup, then stop and report.

## Project scope surfaces

Read these when Grok is the source in a project migration; write these when it is the target. Paths are relative to the project root.

| Category | Location | Notes |
|---|---|---|
| Global rules | `AGENTS.md` | The project root's `AGENTS.md`; `rules/*.md` is home-scope only |
| Settings | `.grok/config.toml` | **The project layer loads less than the home layer** — only MCP servers, plugins, and permission rules. Do not write model, `[ui] permission_mode`, or `[sandbox]` here; Grok ignores them at project level |
| Skills | `.grok/skills/<name>/` | Whole directory |
| Subagents | `.grok/agents/*.md` | camelCase frontmatter, same as home scope |
| Hooks | `.grok/hooks/*.json` | Project hooks require `/hooks-trust` or `--trust` before Grok honors them — note this in the report |
| Vendor-neutral skills | `.agents/skills/<name>/` | **Not listed in any tool's own inventory** — it is a shared project surface. procedure.md's "`.agents/` is shared, not migratable" rule governs it: migrate it when this target does not read the path natively, leave it alone when it does. Never skip it just because it is absent from the table above |
