# Migration Report: claude → grok (20260823-131644)

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
- Global rules: CLAUDE.md → AGENTS.md (`## Migrated from claude (2026-08-23)` section, verbatim, `@~/.agent-rules-fixture.md` import kept unexpanded). Written to AGENTS.md rather than `rules/`, per grok.md
- Skills: hello → skills/hello/ (SKILL.md and reference/tone.md)
- Subagents: reviewer.md → agents/reviewer.md (`name` and `description` carry over unchanged; the source had no other frontmatter keys)
- Hooks: PreToolUse `Edit|Write` → hooks/migrated.json, unchanged. Grok's hook file has the same shape as Claude's `hooks` object and uses Claude's tool names, so nothing was converted
- Hooks: Notification → hooks/migrated.json, unchanged. `Notification` is one of Grok's 15 events
- Permission rules: Bash(git status:*), Bash(npm run build:*), Bash(npm run test:*) → `[permission] allow` in config.toml, verbatim
- Permission rules: Bash(git push:*) → `[permission] ask`, verbatim. Grok has an `ask` tier, so nothing was lost
- Permission rules: Bash(rm:*) → `[permission] deny`, verbatim
- Env injection: FIXTURE_FLAG → `[shell_environment_policy.set]` in config.toml

## Approximated (review recommended)
- Commands/prompts greet.md → skills/greet/SKILL.md: Grok has no command surface, so the command became a skill with `user-invocable: true` so it stays reachable as a slash command. The source had no `description`, so the body's first sentence was used verbatim rather than invented. The `$ARGUMENTS` token was left exactly as it is.
- Env injection SERVICE_API_KEY (settings.json `env`): the key was written to `[shell_environment_policy.set]`, but its value is a detected secret, so it was replaced with `<REDACTED-REENTER>`. The key arrives; the value does not.

## Manual action required
- SERVICE_API_KEY (settings.json `env` → config.toml `[shell_environment_policy.set]`): re-enter the value by hand. It is present in the target as `<REDACTED-REENTER>`.
- Approval policy: source `permissions.defaultMode` = `bypassPermissions`. The suggested Grok equivalent is `[ui] permission_mode = "bypassPermissions"` (procedure.md level 3). Nothing was written — this tool never sets it.

## Not migrated
- Hooks `ConfigChange` (settings.json `hooks`, command `echo claude-only-event`): not one of Grok's 15 events. Dropped rather than left as config Grok would ignore.
- Model (settings.json `model`): current value `claude-fable-5`. Not migrated — the target's `model` is `grok-5-code` and a Claude model name has no meaning there.
- Credentials file (`.credentials.json` in the source home): existence confirmed only, per security.md. Never opened, so it is absent from the ledger.
- MCP servers: none found in settings.json. MCP is out of scope for this tool regardless — a definition usually carries its credential inline, and a redacted server would arrive registered and non-functional.

## Verification
- `python3 -c "import tomllib..." config.toml` — parses after the edit.
- `jq -e . hooks/migrated.json` — ok.
- `grep -rF '<REDACTED-REENTER>'` outside .migrate/ — 1 hit. The source had exactly 1 secret-bearing key, so the counts match.
- `grep -rE 'sk-[A-Za-z0-9_-]{16,}'` outside .migrate/ — 0 hits. No secret shape reached the target.
- Pre-existing target content survived: `EXISTING_KEY = "keep"` still in `[shell_environment_policy.set]`, `Bash(ls:*)` still first in `[permission] allow`, `inherit = "core"` untouched, `# Existing` / `Keep me.` still at the top of AGENTS.md.
- config.toml was edited line by line rather than reparsed and rewritten, so key order and the existing table layout are unchanged.
- backup/ holds AGENTS.md and config.toml — exactly the two files in `changes.json`'s `modified`.
