# Migration Report: grok → cursor (20260823-110013)

Source root: `<REPO>/test/fixtures/grok-home` (test mode — not the real `~/.grok`)
Target root: `<TARGET>` (test mode — not the real `~/.cursor`)
Scope: home. Confirm: approved in full, nothing excluded.

## Scan summary
| Category | Found | Automatic | Approximate | Suggestion | Skipped | Excluded | Impossible |
|---|---|---|---|---|---|---|---|
| Global rules | 2 | 0 | 0 | 0 | 0 | 0 | 2 |
| Skills | 1 | 0 | 1 | 0 | 0 | 0 | 0 |
| Commands/prompts | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| Subagents | 1 | 0 | 1 | 0 | 0 | 0 | 0 |
| Hooks | 2 | 1 | 0 | 0 | 0 | 0 | 1 |
| Permission rules | 5 | 4 | 0 | 0 | 0 | 0 | 1 |
| Env injection | 3 | 0 | 0 | 0 | 0 | 0 | 3 |
| Approval/sandbox policy | 2 | 0 | 0 | 1 | 0 | 0 | 1 |
| Non-migratable items | 2 | 0 | 0 | 0 | 0 | 0 | 2 |

Commands is zero because **Grok has no command surface at all** — slash commands are built as skills there, so there was nothing to find. This is the thinnest direction in the set: Cursor has no global rule file and no env surface, so two whole categories arrive as manual work.

## Migrated (automatic)
- Hooks: `PreToolUse` matcher `Edit|Write` → `hooks.json` `preToolUse`, matcher `Write`. Grok uses Claude's tool names, and Cursor has a single `Write` matcher, so the two alternatives collapse onto it. The flat Cursor array shape replaced Grok's `{matcher, hooks:[...]}` nesting, and the event name was lowercased to camelCase.
- Permission rules: `Bash(git status:*)` allow → `cli-config.json` `permissions.allow` `Shell(git status:*)`
- Permission rules: `Bash(npm run build:*)` allow → `Shell(npm run build:*)`
- Permission rules: `Bash(npm run test:*)` allow → `Shell(npm run test:*)`
- Permission rules: `Bash(rm:*)` deny → `permissions.deny` `Shell(rm:*)`

The tool name had to be renamed on every one of those: Cursor has no `Bash` tool, so a rule left as `Bash(...)` would match nothing. The colon argument syntax (`:*`) is shared and was kept as-is.

## Approximated (review recommended)
- Skills `skills/hello/` → `skills/hello/`. The directory copied over with its supporting file, but **`user-invocable: true` was dropped from the frontmatter.** That key is Grok-specific and is not among Cursor's skill frontmatter keys; the rest of the frontmatter and the body are untouched. What is lost is the source's intent that this skill be reachable as a slash command.
- Subagents `agents/reviewer.md` → `agents/reviewer.md`. `name` and `description` carried over. **Four Grok-only frontmatter keys were dropped**, because Cursor's subagent frontmatter (`name`/`description`/`model`/`readonly`/`is_background`) has no field for any of them: `promptMode: extend`, `capabilityMode: read-only`, `effort: high`, `maxTurns: 5`. Cursor does have a `readonly` field, and `capabilityMode: read-only` looks like it should map onto it — **it was not mapped, because that is a guess.** The two are differently named concepts in different tools, and nothing in these docs confirms they mean the same thing. If they do, set `readonly: true` by hand.

## Manual action required
- Global rules `rules/global.md`: Cursor has no global rule file. Its equivalent, User Rules, lives in the Cursor account and cannot be written to disk, and no project root was given for this run, so **nothing was written**. Paste this into Cursor's User Rules by hand:

```
# Global Rules

@~/.agent-rules-fixture.md

- Answer in Korean.
- Never commit secrets.
```

- Permission rule `Bash(git push:*)` (`config.toml`, `[permission] ask`): **Cursor has no `ask` tier.** Putting it in `allow` would grant what the source wanted to prompt for, and `deny` would forbid what the source allowed with a prompt — both distort the original. It was left out entirely.
- Env injection `FIXTURE_FLAG = "1"` (`config.toml`, `[shell_environment_policy.set]`): Cursor has no global env surface. Move it into a per-server `env` block or your shell profile.
- Env injection `SERVICE_API_KEY` (`config.toml`, `[shell_environment_policy.set]`): same — no global env surface. The value was never written anywhere and is not recorded here; re-enter it by hand wherever you move it.

## Not migrated
- Global rules `GROK.md` (`GROK.md`): **Grok does not read this file.** The recognized names in a Grok home are `AGENTS.md`, `AGENT.md`, `CLAUDE.md`, `CLAUDE.local.md` and the like — `GROK.md` is not among them, so it is not a migration target and was left where it is. Its contents were never opened. Counted under Global rules rather than the catch-all category.
- Hook event `Notification` (`hooks/migrated.json`): Cursor has no corresponding event. Command was `echo notify`.
- Env injection `inherit` (`config.toml`, `[shell_environment_policy]`): `inherit = "core"` is inheritance policy rather than value injection, and Cursor has no env surface at all. Counted under Env injection.
- Sandbox (`config.toml`): `[sandbox] profile = "off"`. **Not migrated and not even suggested** — sandbox profiles are OS-level isolation whose meaning differs per tool, and no equivalent mapping exists. Counted under Approval/sandbox policy.
- Approval policy (`config.toml`): `[ui] permission_mode = "bypassPermissions"`. Suggestion only, nothing written — see below. The target's existing `approvalMode` (`allowlist`) was left untouched.
- Model (`config.toml`): `model = "grok-5-code"` — not migrated.
- Credentials (`auth.json`): existence confirmed only. Never opened, never hashed, and deliberately absent from the ledger.
- MCP servers: **0 found** in `config.toml`. MCP is out of scope for this tool regardless.

## Approval/sandbox suggestion (not applied)
Source `[ui] permission_mode = "bypassPermissions"` lines up with Cursor's `approvalMode = "unrestricted"` (automation level 3). **Nothing was written**, and `approvalMode` is never changed automatically even when it already holds a value. Two cautions apply here: Cursor's modes differ from the others in whether a classifier is involved and that correspondence has never been confirmed by research, and Grok's `permission_mode` also accepts `auto`, `dontAsk`, and `plan`, which have no row in the table at all.

## Verification
- `jq -e . hooks.json` and `jq -e . cli-config.json` — both valid after the merge.
- Placeholder count: **0**, and that is correct here. Cursor has no env surface, so nothing was written for the one secret-bearing source key; it appears by name only under manual action.
- Secret-shape scan of the whole target (high-entropy prefix patterns) — no matches.
- `skills-cursor/canvas/SKILL.md` still reads `APP-MANAGED-DECOY-UNTOUCHED`. That directory is app-managed and was never a write destination.
- Backup: `.migrate/20260823-110013/backup/` holds `hooks.json` and `cli-config.json`, matching `changes.json` `modified` exactly.
- Existing target content preserved: the `sessionStart` entry `echo existing-session`, `approvalMode`, and `Shell(ls)` in `permissions.allow` all survived.
- Ledger written with the 6 source files actually read. `auth.json` and `GROK.md` are absent because neither was opened — the first is forbidden, the second is declared out of scope.
