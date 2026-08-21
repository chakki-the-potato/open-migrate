# Cursor (Anysphere)

Home: `~/.cursor`. MCP, skills, subagents, hooks, permissions, and approval policy all live under that home. Rules (`.cursor/rules/*.mdc`), commands (`.cursor/commands/*.md`), and `AGENTS.md` (the migration target) are relative to the project root, not the home directory. Use this doc both when reading Cursor as a source and when writing to it as a target.

## Detection

Consider it installed when `~/.cursor/mcp.json` or `~/.cursor/cli-config.json` exists.

## Config inventory (read)

| Category | Location | Format |
|---|---|---|
| Global rules | `.cursor/rules/*.mdc` (project root) **and** `AGENTS.md` (`~/.cursor/AGENTS.md` plus the project root) | Frontmatter `description`/`globs`/`alwaysApply` followed by a markdown body. Cursor ignores plain `.md` files in the same directory — the official docs tell you to use `AGENTS.md` for plain-markdown rules. Cursor reads `AGENTS.md` and `CLAUDE.md` natively, so **treat `AGENTS.md` as a global-rule source too** — if there are no `.mdc` files at all but an `AGENTS.md` exists, that file is the rule source |
| User Rules | No local file — stored in the Cursor account (cloud-synced) | Not migratable — manual guidance only |
| MCP | `mcpServers` in `~/.cursor/mcp.json` | JSON. stdio: `command`/`args`/`env`/`envFile`. remote: `url`/`headers`. Server names may contain spaces. Supports `${env:NAME}` interpolation. No enabled/disabled flag |
| Skills | `~/.cursor/skills/<name>/SKILL.md` | agent-skills standard layout. Frontmatter: `name`/`description`/`paths`/`disable-model-invocation`/`metadata`. No `$ARGUMENTS` substitution. `~/.cursor/skills-cursor/` is app-managed built-in content — not migratable in either direction |
| Commands / prompts | `.cursor/commands/*.md` (project root) | Deprecated — Cursor recommends skills instead |
| Subagents | `~/.cursor/agents/*.md` | Frontmatter: `name`/`description`/`model`/`readonly`/`is_background` |
| Hooks | `~/.cursor/hooks.json` | JSON. See "Hook file structure" below — the top-level `hooks` is **an object keyed by camelCase event names**, and each value is a flat array of hook objects (unlike Claude's PascalCase plus `{matcher, hooks:[...]}` nesting) |
| Permission rules | `permissions.allow` / `permissions.deny` in `~/.cursor/cli-config.json` | Five token types: `Shell(cmd)` / `Read(glob)` / `Write(glob)` / `WebFetch(domain)` / `Mcp(server:tool)`. Argument matching uses colon syntax (for example `curl:*`) |
| Env injection | No global env surface | Only per-server `env`/`envFile` in `~/.cursor/mcp.json` and `${env:NAME}` interpolation exist |
| Approval policy | `approvalMode` in `~/.cursor/cli-config.json` | Values: `allowlist` / `auto-review` / `unrestricted` |
| Never read | credentials, `state.vscdb`, `projects/`, `extensions/` | security.md applies |

## Conversion rules (Cursor → other tools)

### Global rules
- `.cursor/rules/*.mdc` → merge verbatim into the target's global rule file (Claude: `CLAUDE.md`, Codex: `AGENTS.md`); never summarize or rewrite. Move the entire file including its frontmatter (`description`/`globs`/`alwaysApply`) — do not expand it or extract only the frontmatter.
- `AGENTS.md` (`~/.cursor/AGENTS.md` or the project root) moves the same way. It is a rule surface Cursor reads natively, so treat it as equal to `.mdc` — **never conclude "no rules to migrate" just because there are no `.mdc` files.** If both surfaces exist, migrate both and keep them separated per file.
- For the merge section and subheading format, follow procedure.md's "Global-rule merge format" (add the `### <filename>` subheading even when there is only one file).
- User Rules: they do not exist locally, so automatic migration is impossible — leave a note in the report telling the user to check their Cursor account's User Rules and move them over manually.

### MCP
- `mcpServers.<name>` → the target's MCP format. stdio (`command`/`args`/`env`) and remote (`url`/`headers`) map directly.
- Never open an `envFile` to inline its values (secret exposure risk) — mark it impossible and record only the path in the report as manual guidance.
- `${env:NAME}` interpolation is Cursor-specific syntax and no equivalent has been confirmed on the other tools — carry the value over verbatim but flag it for manual review.
- If a server name contains spaces, the target's naming rules (CLI argument vs. file key) may require quoting — flag for manual review.
- `env` and `headers` values are subject to security.md secret detection.

### Skills
- Copy the `SKILL.md` directory into the target's skill directory as-is.
- Cursor skills have no `$ARGUMENTS` substitution to begin with — if the target supports argument substitution, simply note that there was nothing to fill in (this is an absence, not a loss).
- `~/.cursor/skills-cursor/` is app-managed content; exclude it from migration.

### Commands / prompts
- The surface is deprecated, but migrate it when present: move the file contents verbatim into the target's command file.
- Cursor commands also lack `$1`-`$9` / `$ARGUMENTS` substitution tokens — if the target format supports them, just note that there was nothing to carry over.

### Subagents
- `agents/<name>.md` → the target's subagent format. `name` and `description` map directly.
- `model`: Claude's subagent frontmatter also has a `model` field. The problem is not a missing field but that **the value space differs per tool.** `inherit` is a value both sides share, so **carry it over as-is** (lossless). For any other value, drop the field unless you have confirmed it is a valid alias or model ID on the target, and quote the source value in the report as a manual-review item. Never guess a replacement value.
- `readonly` and `is_background` have no corresponding field in Claude's subagent frontmatter — drop and record in the report.

### Hooks
- Structural conversion: turn the flat arrays keyed by camelCase event names into the target's PascalCase event names (the 11 shared by Claude and Codex), and wrap each array element in the target's `{matcher, hooks:[...]}` shape.
- See "Hook event mapping" below for the event-name table.
- Matchers: `Glob`, `WebFetch`, and `WebSearch` do not exist as Cursor hook matchers at all, so in this direction there is nothing to carry over — those three only matter in the opposite direction (write rules). **Cursor's `Write` matcher, on the other hand, does lose information in this direction** — the reverse mapping merges Claude's `Write` and `Edit` into a single Cursor `Write`, so the restoration is not unique. Follow the Cursor → Claude/Codex rule in the tool-name matcher mapping below.

### Hook event mapping

| Claude/Codex (PascalCase) | Cursor (camelCase) |
|---|---|
| `PreToolUse` | `preToolUse` |
| `PostToolUse` | `postToolUse` |
| `UserPromptSubmit` | `beforeSubmitPrompt` |
| `SessionStart` | `sessionStart` |
| `SessionEnd` | `sessionEnd` |
| `PreCompact` | `preCompact` |
| `Stop` | `stop` |
| `SubagentStop` | `subagentStop` |

Only `UserPromptSubmit` → `beforeSubmitPrompt` is more than a case change — for the other seven, lowercasing the first letter is enough.

- Unsupported (no corresponding Cursor event): `Notification`, plus the approval-request event — `PermissionDenied` when the source is Claude, `PermissionRequest` when it is Codex (the two tools use different names; see claude.md's hook row and codex.md's official event list). Either way, drop and record in the report.
- For any event name outside those eight plus the two unsupported ones, do not guess a mapping — drop it and leave it as a manual-review item.
- Tool-name matcher mapping (Claude → Cursor): `Bash`→`Shell`, `Read`→`Read`, `Write`→`Write`, `Edit`→`Write`, `Grep`→`Grep`, `Task`→`Task`. `Glob`, `WebFetch`, and `WebSearch` have no corresponding matcher — drop and record.
- Tool-name matcher mapping (Codex → Cursor): Codex uses different tool names — `apply_patch`→`Write`, `Bash`→`Shell` (Codex normalizes the shell family to `Bash`), `Task`→`Task`. Any other Codex tool name has no corresponding Cursor matcher — drop and record. **Never route through Claude's names as an intermediate representation** — a two-step conversion invents losses at the points where a mapping is many-to-one.
- Tool-name matcher mapping (Grok → Cursor): Grok uses the same tool names as Claude, so apply the Claude row above unchanged.
- Tool-name matcher mapping (Cursor → Claude/Grok): `Shell`→`Bash`, `Read`→`Read`, `Grep`→`Grep`, `Task`→`Task`. `Write` is the result of `Write` and `Edit` merging in the mapping above, so its reverse is not unique — **restore it as the regex alternation `Edit|Write` so both match.** Picking just one is forbidden, because it narrows the scope beyond what the source specified. Record this approximation in the report.
- Tool-name matcher mapping (Cursor → Codex): Codex's tool naming differs, so the mapping above does not apply — `Write`→`apply_patch`, `Shell`→`Bash`, `Task`→`Task`. `Read` and `Grep` have no first-class equivalent in Codex and would become dead patterns — drop and record (see codex.md's hook event conversion section). **Never route through Claude's names as an intermediate representation.**
- Cursor-only events (`postToolUseFailure`, `beforeShellExecution`, `afterFileEdit`, and the like) have no equivalent in Claude or Codex — drop and record when Cursor is the source.

### Hook file structure

`hooks.json` has exactly this shape. The top-level `hooks` is an **object** keyed by event name, and each event's value is a flat array of hook objects. There is no extra `{matcher, hooks:[...]}` wrapper like Claude's, and array elements carry no `event` field.

```json
{
  "version": 1,
  "hooks": {
    "preToolUse": [
      { "command": "echo pre-edit-check", "type": "command", "timeout": 10, "matcher": "Write" }
    ],
    "sessionStart": [
      { "command": "echo hi", "type": "command" }
    ]
  }
}
```

- Hook object fields: `command` (required), `type` (`"command"` or `"prompt"`), `timeout` (seconds), `matcher` (tool-name regex), `failClosed`, `loop_limit`.
- One Claude `{matcher, hooks:[{command, timeout}]}` expands into **several** Cursor hook objects — copy the outer `matcher` into each element of the inner `hooks` array.
- **Decomposing compound matchers**: a Claude matcher can hold a regex alternation such as `Edit|Write`. Split on `|`, apply the tool-name mapping to each token, then de-duplicate (`Edit|Write` → both become `Write` → a single `Write`). If a matcher consists only of tokens that the mapping drops (`Glob`, `WebFetch`, `WebSearch`), drop the entire hook and record it in the report.

### Compatibility loading (when migration may be unnecessary)

This section applies **only when Cursor is the target.** Ignore it when Cursor is the source.

Cursor reads parts of other tools' configuration **without conversion.** Check for this during Scan; when it applies, record "already being read" in the report instead of migrating, to avoid a duplicate install.

- Rules: reads `AGENTS.md` and `CLAUDE.md` natively.
- Skills: reads `.claude/skills/`, `.codex/skills/`, `~/.claude/skills/`, and `~/.codex/skills/` as compatibility paths.
- Subagents: reads `.claude/agents/`, `.codex/agents/`, `~/.claude/agents/`, and `~/.codex/agents/`.
- Hooks: with third-party support enabled in settings, it reads hooks from `.claude/settings.json` and `~/.claude/settings.json`, converting them per the mapping table above.

These paths can be disabled in the user's settings, so never skip migration automatically — confirm with the user during Confirm. In a mode where you cannot ask (blanket approval), **migrate rather than skip** and record the possibility of duplication in the report.

### Permission rules
- `Shell(cmd)` → Claude `Bash(cmd)`: **you must rename the token.** The argument-matching syntax (colon form, `curl:*`) has the same shape as Claude's `Bash(cmd:*)` and is kept as-is, but the tool name differs — Claude has no `Shell` tool, so writing `Shell(...)` produces a rule that matches nothing. Example: `Shell(git status:*)` → `Bash(git status:*)`. This rename is the exact inverse of the Cursor permission row in the write rules table (source `Bash(...)` → `Shell(...)`); applying only one of the two breaks the round trip. When going to Codex, apply codex.md's "Permission write syntax" instead (split tokens on whitespace, drop `:*`, emit `prefix_rule(pattern=[...], decision="...")`).
- `Read(glob)` → Claude `Read(glob)`, unchanged.
- `Write(glob)` → Claude splits this across two tools (`Edit` and `Write`), so an approximation is needed: when it is unclear whether the target is a new file or an existing one, add it to both `Edit(glob)` and `Write(glob)` and record the approximation in the report.
- `WebFetch(domain)` → Claude `WebFetch(domain)`, unchanged.
- `Mcp(server:tool)` → the exact MCP permission token syntax on the Claude side is not documented in this repository — do not convert it automatically; list the original verbatim under manual action.
- Codex target: the other four token types (`Read`/`Write`/`WebFetch`/`Mcp`) cannot be expressed in Codex's Starlark rules DSL (see codex.md) — do not convert them; list the originals verbatim under manual action.
- `approvalMode` → use procedure.md's approximation table as a report suggestion only; never set it automatically.

### Env injection
- Cursor has no global env surface — when Cursor is the source there is no global env block to migrate at all (per-server env is already handled by the MCP rules above).

## Write rules (when Cursor is the target)

| Category | Write location | How |
|---|---|---|
| Global rules | **There is nowhere to write in home scope** — see below | Cursor has no global rule **file**. The equivalent, User Rules, is stored in the account and cannot be written to disk. Therefore: (a) if the user specifies a project root, merge into that root's `AGENTS.md` as a `## Migrated from <source> (<date>)` section, **verbatim** (never summarize or rewrite, keep `@import` lines as-is, never delete existing content, back up to `.migrate/<run-id>/backup/AGENTS.md` first); (b) if there is no project root, **write nothing** — put the rule text in the manual-action list so the user can paste it into Cursor's User Rules. In neither case write to `.cursor/rules/*.md`, because Cursor ignores plain `.md` |
| MCP | `mcpServers.<name>` in `~/.cursor/mcp.json` | stdio: `command`/`args`/`env`. remote: `url`/`headers`. **If a server with the same name exists, do not overwrite — skip and record in the report.** Replace secret values with `<REDACTED-REENTER>` and list them under manual action. Do not write Cursor-specific fields (`envFile`, `${env:NAME}` interpolation) since the source has none |
| Skills | `~/.cursor/skills/<name>/SKILL.md` | Copy the whole directory. **If a skill with the same name exists, skip and record in the report.** Never write into `~/.cursor/skills-cursor/` (app-only area) |
| Commands | `~/.cursor/skills/<name>/SKILL.md` (migrate as a skill, not a command) | `.cursor/commands/*.md` is deprecated, so exclude it as a write destination; wrap the source command in `name`/`description` frontmatter and write it as a skill. `name` is the source filename without its extension. If the source has no `description`, do not invent one — use the body's first sentence verbatim and record in the report that it was synthesized. The source's `$1`-`$9` / `$ARGUMENTS` substitution tokens have no equivalent in Cursor skills and are therefore **lost** — state this as a loss in the report |
| Subagents | `~/.cursor/agents/<name>.md` | Write only `name`/`description`/`model`/`readonly`/`is_background` in the frontmatter. When the source is Claude, `tools` and `color` have no corresponding Cursor field — drop and record. **If a file with the same name exists, do not overwrite — skip and record in the report** |
| Hooks | `~/.cursor/hooks.json` | `version: 1`, flat arrays, converted to camelCase event names, appended (skip identical commands). Apply only the confirmed range of the "Hook event mapping" above — for anything else, do not guess a mapping; leave it as a manual-review item. `Notification` and the approval-request event (Claude `PermissionDenied` / Codex `PermissionRequest`) are unsupported by Cursor — drop and record. Hooks scoped by a `Glob`/`WebFetch`/`WebSearch` matcher have no corresponding matcher — drop and record |
| Permissions | `permissions.allow` / `permissions.deny` in `~/.cursor/cli-config.json` | Token rename: the source's Bash/shell rules (`Bash(git status:*)`, Codex `prefix_rule(["git","status"])`) become `Shell(...)` — keep the colon argument syntax (`:*`) as-is. When the source is Claude, `Edit(glob)` and `Write(glob)` both collapse into a single Cursor `Write(glob)` — note in the report that the merge naturally de-duplicates them. Append to the arrays and de-duplicate. **Cursor has no `ask`/`prompt` tier** — do not put the source's ask rules in either `allow` or `deny` (both distort the original meaning); list them verbatim under manual action. **Never change `approvalMode`**, even when it already has a value — put the approximation table in the report as a suggestion only |
| Env injection | — | Cursor has no global env surface — the source's global env block (Claude's `env` in `settings.json`, Codex's `[shell_environment_policy.set]`) is **not migratable**. Do not let it disappear silently: record every key name and its source-side location under manual action so the user can move them into per-server `env` or a shell profile |
| Approval policy | — | Never set `approvalMode` automatically. Use procedure.md's approximation table as a report suggestion only |

## JSON config merge rules

`mcp.json`, `hooks.json`, and `cli-config.json` are all JSON.

1. Copy the original to `.migrate/<run-id>/backup/<filename>` before modifying.
2. Deep merge: merge objects per key, append to arrays then de-duplicate, preserve existing scalar values. Never resolve same-name collisions (server name, skill name, filename) on your own — confirm with the user during Confirm.
3. Validate with `jq -e . <filename>` after writing. On failure, restore from the backup, then stop and report.
