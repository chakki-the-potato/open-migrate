# Migration Report: claude → grok (20260823-110003)

Source root: `<REPO>/test/fixtures/claude-home` (test mode — not the real `~/.claude`)
Target root: `<TARGET>` (test mode — not the real `~/.grok`)
Scope: home. Confirm: approved in full, nothing excluded.

## Scan summary
| Category | Found | Automatic | Approximate | Suggestion | Skipped | Excluded | Impossible |
|---|---|---|---|---|---|---|---|
| Global rules | 1 | 1 | 0 | 0 | 0 | 0 | 0 |
| Skills | 1 | 1 | 0 | 0 | 0 | 0 | 0 |
| Commands/prompts | 1 | 0 | 1 | 0 | 0 | 0 | 0 |
| Subagents | 1 | 1 | 0 | 0 | 0 | 0 | 0 |
| Hooks | 3 | 2 | 0 | 0 | 0 | 0 | 1 |
| Permission rules | 5 | 5 | 0 | 0 | 0 | 0 | 0 |
| Env injection | 2 | 1 | 1 | 0 | 0 | 0 | 0 |
| Approval/sandbox policy | 1 | 0 | 0 | 1 | 0 | 0 | 0 |
| Non-migratable items | 2 | 0 | 0 | 0 | 0 | 0 | 2 |

## Migrated (automatic)
- Global rules: `CLAUDE.md` → `AGENTS.md` (appended `## Migrated from claude (2026-08-23)` → `### CLAUDE.md`, body verbatim, `@~/.agent-rules-fixture.md` carried over unexpanded). Written to `AGENTS.md` rather than `rules/`: every `rules/*.md` is loaded anyway, so a single file is easier to trace with identical effect.
- Skills: `skills/hello/` (SKILL.md + reference/tone.md) → `skills/hello/`
- Subagents: `agents/reviewer.md` → `agents/reviewer.md` (`name` and `description` in camelCase frontmatter; the source had no other keys to convert or drop)
- Hooks: PreToolUse `Edit|Write` → `hooks/migrated.json`, matcher unchanged. Grok's hook JSON has the same shape as Claude's and uses the same tool names, so nothing was converted.
- Hooks: `Notification` → `hooks/migrated.json`, unchanged. It is one of Grok's 15 events, so unlike a migration to Codex or Cursor this one survives.
- Permission rules: `Bash(git status:*)`, `Bash(npm run build:*)`, `Bash(npm run test:*)` allow → `config.toml` `[permission] allow`
- Permission rules: `Bash(git push:*)` ask → `[permission] ask`. **The `ask` tier exists on both sides**, so nothing was lost here — the same rule going to Cursor or Codex would not survive.
- Permission rules: `Bash(rm:*)` deny → `[permission] deny`
- Env injection: `FIXTURE_FLAG` → `config.toml` `[shell_environment_policy.set]`

The permission strings were appended verbatim. Grok uses Claude's rule syntax, so no rewriting was needed.

## Approximated (review recommended)
- Commands/prompts `commands/greet.md` → `skills/greet/SKILL.md`. Grok has no command surface, so the target doc converts commands into skills. The source command had no `description`, so the body's first sentence was used verbatim rather than invented — **the description is synthesized, and that is worth a look.** `user-invocable: true` was added so it stays reachable as a slash command, which is what it was in Claude. The `$ARGUMENTS` token was left exactly as it stands, per the target doc; whether Grok skills interpolate it is not documented in this repository, so verify before relying on it.
- Env injection `SERVICE_API_KEY`: the key was migrated, the value was not. `config.toml` holds `<REDACTED-REENTER>`; see manual action.

## Manual action required
- `SERVICE_API_KEY` (`settings.json`, `env`): re-enter the value by hand at `config.toml` → `[shell_environment_policy.set]`, which currently holds `<REDACTED-REENTER>`.

## Not migrated
- Hook event `ConfigChange` (`settings.json`, hooks): outside Grok's 15 events. Guessing a mapping is forbidden, so it was dropped and recorded. Command was `echo claude-only-event`.
- Model (`settings.json`): `model = "claude-fable-5"` — not migrated. The target's existing `model` (`grok-5-code`) was left untouched.
- Approval policy (`settings.json`): `permissions.defaultMode = "bypassPermissions"`. Suggestion only, nothing written — see below.
- Credentials (`.credentials.json`): existence confirmed only. Never opened, never hashed, and deliberately absent from the ledger.
- MCP servers: **0 found** in `settings.json`. MCP is out of scope for this tool regardless.

## Approval/sandbox suggestion (not applied)
Source `permissions.defaultMode = "bypassPermissions"` lines up with Grok's `[ui] permission_mode = "bypassPermissions"` (automation level 3; Grok's product name for it is always-approve). **Nothing was written.** Grok's `permission_mode` also accepts `auto`, `dontAsk`, and `plan`, which have no row in the mapping table — that is why this stays a suggestion.

## Verification
- `python3 -c "import tomllib…"` — `config.toml` parses after the merge. The file was edited line by line rather than re-serialized, so key order and spacing survived.
- `jq -e . hooks/migrated.json` — valid JSON, top-level key is `hooks`.
- Placeholder present: exactly 1 occurrence of `<REDACTED-REENTER>` in the target. The source held exactly 1 secret-bearing key, so the counts agree.
- Secret-shape scan of the whole target (high-entropy prefix patterns) — no matches.
- Backup: `.migrate/20260823-110003/backup/` holds `AGENTS.md` and `config.toml`, matching `changes.json` `modified` exactly.
- Existing target content preserved: `AGENTS.md` still opens with `# Existing / Keep me.`; `config.toml` kept `model`, `[shell_environment_policy] inherit`, `EXISTING_KEY`, and `Bash(ls:*)` at the head of `[permission] allow`.
- Ledger written with the 6 source files actually read. `.credentials.json` is absent because it was never opened.
