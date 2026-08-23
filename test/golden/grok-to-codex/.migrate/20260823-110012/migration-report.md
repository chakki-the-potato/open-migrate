# Migration Report: grok → codex (20260823-110012)

Source root: `<REPO>/test/fixtures/grok-home` (test mode — not the real `~/.grok`)
Target root: `<TARGET>` (test mode — not the real `~/.codex`)
Scope: home. Confirm: approved in full, nothing excluded.

## Scan summary
| Category | Found | Automatic | Approximate | Suggestion | Skipped | Excluded | Impossible |
|---|---|---|---|---|---|---|---|
| Global rules | 2 | 1 | 0 | 0 | 0 | 0 | 1 |
| Skills | 1 | 0 | 1 | 0 | 0 | 0 | 0 |
| Commands/prompts | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| Subagents | 1 | 0 | 1 | 0 | 0 | 0 | 0 |
| Hooks | 2 | 1 | 0 | 0 | 0 | 0 | 1 |
| Permission rules | 5 | 5 | 0 | 0 | 0 | 0 | 0 |
| Env injection | 3 | 1 | 1 | 0 | 0 | 0 | 1 |
| Approval/sandbox policy | 2 | 0 | 0 | 1 | 0 | 0 | 1 |
| Non-migratable items | 2 | 0 | 0 | 0 | 0 | 0 | 2 |

Commands is zero because **Grok has no command surface at all** — slash commands are built as skills there, so there was nothing to find.

## Migrated (automatic)
- Global rules: `rules/global.md` → `AGENTS.md` (appended `## Migrated from grok (2026-08-23)` → `### global.md`, body verbatim, `@~/.agent-rules-fixture.md` carried over unexpanded). Grok loads `rules/*.md` alphabetically; there is one file here, and it still gets its own `### ` subheading so the format does not change with the file count. The target has no `AGENTS.override.md`, so `AGENTS.md` is the file Codex actually reads and the merge was safe to make.
- Hooks: PreToolUse `Edit|Write` → `hooks.json` PreToolUse matcher `apply_patch`. Grok uses Claude's tool names, and Codex has one edit tool, so the two alternatives collapse onto it.
- Permission rules: `Bash(git status:*)` allow → `rules/migrated.rules` `prefix_rule(pattern=["git", "status"], decision="allow")`
- Permission rules: `Bash(npm run build:*)` allow → `prefix_rule(pattern=["npm", "run", "build"], decision="allow")`
- Permission rules: `Bash(npm run test:*)` allow → `prefix_rule(pattern=["npm", "run", "test"], decision="allow")`
- Permission rules: `Bash(git push:*)` ask → `prefix_rule(pattern=["git", "push"], decision="prompt")`. **Codex has a `prompt` decision**, so the ask tier survives here where it would be lost going to Cursor.
- Permission rules: `Bash(rm:*)` deny → `prefix_rule(pattern=["rm"], decision="forbidden")`
- Env injection: `FIXTURE_FLAG` → `config.toml` `[shell_environment_policy.set]`

Every rule is on its own line even where two share the `npm run` prefix. The positional union form is a read-side convenience and is not used when writing. The `decision` values are double-quoted; an unquoted one is a syntax error in this DSL.

## Approximated (review recommended)
- Skills `skills/hello/` → `skills/hello/`. The directory copied over with its supporting file, but **`user-invocable: true` was dropped from the frontmatter.** That key is Grok-specific; the rest of the frontmatter and the body are untouched. This is the specific rule beating the general one — "copy the whole directory" would otherwise have carried a key the target does not read. What is lost is the source's intent that this skill be reachable as a slash command.
- Subagents `agents/reviewer.md` → `agents/reviewer.toml`. `description` and the body carried over as `developer_instructions`; the name lives in the filename, not in a TOML key. **Four Grok-only frontmatter keys were dropped**, because Codex's subagent TOML has no field for any of them: `promptMode: extend`, `capabilityMode: read-only`, `effort: high`, `maxTurns: 5`. The `capabilityMode` loss is the one that changes behavior — the agent is no longer restricted to read-only operation.
- Env injection `SERVICE_API_KEY`: the key was migrated, the value was not. `config.toml` holds `<REDACTED-REENTER>`; see manual action.

## Manual action required
- `SERVICE_API_KEY` (`config.toml`, `[shell_environment_policy.set]`): re-enter the value by hand at the target's `config.toml` → `[shell_environment_policy.set]`, which currently holds `<REDACTED-REENTER>`.

## Not migrated
- Global rules `GROK.md` (`GROK.md`): **Grok does not read this file.** The recognized names in a Grok home are `AGENTS.md`, `AGENT.md`, `CLAUDE.md`, `CLAUDE.local.md` and the like — `GROK.md` is not among them, so it is not a migration target and was left where it is. Its contents were never opened. Counted under Global rules rather than the catch-all category — it is a rules-shaped file that could not travel.
- Hook event `Notification` (`hooks/migrated.json`): outside Codex's 11 official events. Codex ignores unknown events silently, so migrating it would leave dead config behind. Command was `echo notify`.
- Env injection `inherit` (`config.toml`, `[shell_environment_policy]`): `inherit = "core"` is inheritance policy rather than value injection. Codex has a key of that name, but only the `set` table is a write destination, so there is nothing to migrate into. The target's `[shell_environment_policy.set]` was merged per key and its `EXISTING_KEY` preserved. Counted under Env injection.
- Sandbox (`config.toml`): `[sandbox] profile = "off"`. **Not migrated and not even suggested** — sandbox profiles are OS-level isolation whose meaning differs per tool, and no equivalent mapping exists. Counted under Approval/sandbox policy, which is the category it belongs to. Note this is a different thing from Codex's `sandbox_mode`, which appears in the suggestion below.
- Approval policy (`config.toml`): `[ui] permission_mode = "bypassPermissions"`. Suggestion only, nothing written — see below.
- Model (`config.toml`): `model = "grok-5-code"` — not migrated. The target's existing `model` (`gpt-5.6-sol`) was left untouched.
- Credentials (`auth.json`): existence confirmed only. Never opened, never hashed, and deliberately absent from the ledger.
- MCP servers: **0 found** in `config.toml`. MCP is out of scope for this tool regardless.

## Approval/sandbox suggestion (not applied)
Source `[ui] permission_mode = "bypassPermissions"` lines up with Codex `approval_policy = "never"` plus `sandbox_mode = "danger-full-access"` (automation level 3). **Nothing was written.** Grok's `permission_mode` also accepts `auto`, `dontAsk`, and `plan`, which have no row in the mapping table — that is why this stays a suggestion.

## Verification
- `python3 -c "import tomllib…"` — `config.toml` parses after the merge. The file was edited line by line rather than re-serialized, so key order and spacing survived.
- `jq -e . hooks.json` — valid JSON, top-level key is `hooks` (a wrong top-level key would make Codex ignore the whole file).
- Placeholder present: exactly 1 occurrence of `<REDACTED-REENTER>` in the target. The source held exactly 1 secret-bearing key, so the counts agree.
- Secret-shape scan of the whole target (high-entropy prefix patterns) — no matches.
- Backup: `.migrate/20260823-110012/backup/` holds `AGENTS.md` and `config.toml`, matching `changes.json` `modified` exactly.
- Existing target content preserved: `AGENTS.md` still opens with `# Existing / Keep me.`; `config.toml` kept `model` and `[shell_environment_policy.set] EXISTING_KEY`.
- Ledger written with the 6 source files actually read. `auth.json` and `GROK.md` are absent because neither was opened — the first is forbidden, the second is declared out of scope.
