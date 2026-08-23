# Migration Report: grok → claude (20260823-110011)

Source root: `<REPO>/test/fixtures/grok-home` (test mode — not the real `~/.grok`)
Target root: `<TARGET>` (test mode — not the real `~/.claude`)
Scope: home. Confirm: approved in full, nothing excluded.

## Scan summary
| Category | Found | Automatic | Approximate | Suggestion | Skipped | Excluded | Impossible |
|---|---|---|---|---|---|---|---|
| Global rules | 2 | 1 | 0 | 0 | 0 | 0 | 1 |
| Skills | 1 | 0 | 1 | 0 | 0 | 0 | 0 |
| Commands/prompts | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| Subagents | 1 | 0 | 1 | 0 | 0 | 0 | 0 |
| Hooks | 2 | 2 | 0 | 0 | 0 | 0 | 0 |
| Permission rules | 5 | 5 | 0 | 0 | 0 | 0 | 0 |
| Env injection | 3 | 1 | 1 | 0 | 0 | 0 | 1 |
| Approval/sandbox policy | 2 | 0 | 0 | 1 | 0 | 0 | 1 |
| Non-migratable items | 2 | 0 | 0 | 0 | 0 | 0 | 2 |

Commands is zero because **Grok has no command surface at all** — slash commands are built as skills there, so there was nothing to find.

## Migrated (automatic)
- Global rules: `rules/global.md` → `CLAUDE.md` (appended `## Migrated from grok (2026-08-23)` → `### global.md`, body verbatim, `@~/.agent-rules-fixture.md` carried over unexpanded). Grok loads `rules/*.md` alphabetically; there is one file here, and it still gets its own `### ` subheading so the format does not change with the file count.
- Hooks: PreToolUse `Edit|Write` → `settings.json` hooks.PreToolUse, unchanged. Grok's hook JSON has the same shape as Claude's `hooks` value and uses the same tool names, so **nothing was converted** — the object was merged as-is.
- Hooks: `Notification` → `settings.json` hooks.Notification, unchanged.
- Permission rules: `Bash(git status:*)`, `Bash(npm run build:*)`, `Bash(npm run test:*)` allow → `permissions.allow`
- Permission rules: `Bash(git push:*)` ask → `permissions.ask`. **The `ask` tier exists on both sides**, so nothing was lost.
- Permission rules: `Bash(rm:*)` deny → `permissions.deny`
- Env injection: `FIXTURE_FLAG` → `settings.json` env

Grok's compact permission arrays already use Claude's rule syntax, so the strings were appended verbatim with no rewriting.

## Approximated (review recommended)
- Skills `skills/hello/` → `skills/hello/`. The directory copied over with its supporting file, but **`user-invocable: true` was dropped from the frontmatter.** That key is Grok-specific and Claude does not read it; the rest of the frontmatter and the body are untouched. This is the specific rule beating the general one — "copy the whole directory" would otherwise have carried an invalid key across. What is lost is the source's intent that this skill be reachable as a slash command.
- Subagents `agents/reviewer.md` → `agents/reviewer.md`. `name` and `description` carried over. **Four Grok-only frontmatter keys were dropped**, because Claude has no field of the same name for any of them: `promptMode: extend`, `capabilityMode: read-only`, `effort: high`, `maxTurns: 5`. The `capabilityMode` loss is the one that changes behavior — the agent is no longer restricted to read-only operation. Claude's subagent frontmatter has `tools` and `model`, but mapping any of these four onto them is a guess this tool will not make for you.
- Env injection `SERVICE_API_KEY`: the key was migrated, the value was not. `settings.json` holds `<REDACTED-REENTER>`; see manual action.

## Manual action required
- `SERVICE_API_KEY` (`config.toml`, `[shell_environment_policy.set]`): re-enter the value by hand at `settings.json` → `env.SERVICE_API_KEY`, which currently holds `<REDACTED-REENTER>`.

## Not migrated
- Global rules `GROK.md` (`GROK.md`): **Grok does not read this file.** The recognized names in a Grok home are `AGENTS.md`, `AGENT.md`, `CLAUDE.md`, `CLAUDE.local.md` and the like — `GROK.md` is not among them, so it is not a migration target and was left where it is. Its contents were never opened. Counted under Global rules rather than the catch-all category — it is a rules-shaped file that could not travel.
- Env injection `inherit` (`config.toml`, `[shell_environment_policy]`): `inherit = "core"` is inheritance policy rather than value injection, and Claude has no corresponding concept. Counted under Env injection.
- Sandbox (`config.toml`): `[sandbox] profile = "off"`. **Not migrated and not even suggested** — sandbox profiles are OS-level isolation whose meaning differs per tool, and no equivalent mapping exists. The value is quoted here and nowhere else. Counted under Approval/sandbox policy, which is the category it belongs to.
- Approval policy (`config.toml`): `[ui] permission_mode = "bypassPermissions"`. Suggestion only, nothing written — see below.
- Model (`config.toml`): `model = "grok-5-code"` — not migrated. The target's existing `model` (`claude-fable-5`) was left untouched.
- Credentials (`auth.json`): existence confirmed only. Never opened, never hashed, and deliberately absent from the ledger.
- MCP servers: **0 found** in `config.toml`. MCP is out of scope for this tool regardless.

## Judgment calls worth seeing
- The source's `Notification` hook entry has **no `matcher` key at all**. Claude's documented hook structure names one, but the target doc for this direction says to merge Grok's `hooks` object without conversion, so the entry was carried over exactly as written rather than having `matcher: ""` invented for it. If Claude turns out to require the key, that is the line to change.

## Approval/sandbox suggestion (not applied)
Source `[ui] permission_mode = "bypassPermissions"` lines up with Claude's `permissions.defaultMode = "bypassPermissions"` (automation level 3). **Nothing was written.** The names coincide here, which makes it tempting to apply — but approval policy is never set automatically, and Grok's `permission_mode` also accepts `auto`, `dontAsk`, and `plan`, which have no row in the mapping table.

## Verification
- `jq -e . settings.json` — valid JSON after the merge.
- Placeholder present: exactly 1 occurrence of `<REDACTED-REENTER>` in the target. The source held exactly 1 secret-bearing key, so the counts agree.
- Secret-shape scan of the whole target (high-entropy prefix patterns) — no matches.
- Backup: `.migrate/20260823-110011/backup/` holds `settings.json` and `CLAUDE.md`, matching `changes.json` `modified` exactly.
- Existing target content preserved: `CLAUDE.md` still opens with `# Existing / Keep me.`; `settings.json` kept `model`, `env.EXISTING_KEY`, `permissions.allow[Bash(ls:*)]`, and its existing PreToolUse hook on `Read`.
- Ledger written with the 6 source files actually read. `auth.json` and `GROK.md` are absent because neither was opened — the first is forbidden, the second is declared out of scope.
