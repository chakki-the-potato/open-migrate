# Migration Report: claude → codex (20260823-110001)

Source root: `<REPO>/test/fixtures/claude-home` (test mode — not the real `~/.claude`)
Target root: `<TARGET>` (test mode — not the real `~/.codex`)
Scope: home. Confirm: approved in full, nothing excluded.

## Scan summary
| Category | Found | Automatic | Approximate | Suggestion | Skipped | Excluded | Impossible |
|---|---|---|---|---|---|---|---|
| Global rules | 1 | 1 | 0 | 0 | 0 | 0 | 0 |
| Skills | 1 | 1 | 0 | 0 | 0 | 0 | 0 |
| Commands/prompts | 1 | 1 | 0 | 0 | 0 | 0 | 0 |
| Subagents | 1 | 1 | 0 | 0 | 0 | 0 | 0 |
| Hooks | 3 | 1 | 0 | 0 | 0 | 0 | 2 |
| Permission rules | 5 | 5 | 0 | 0 | 0 | 0 | 0 |
| Env injection | 2 | 1 | 1 | 0 | 0 | 0 | 0 |
| Approval/sandbox policy | 1 | 0 | 0 | 1 | 0 | 0 | 0 |
| Non-migratable items | 2 | 0 | 0 | 0 | 0 | 0 | 2 |

## Migrated (automatic)
- Global rules: `CLAUDE.md` → `AGENTS.md` (appended `## Migrated from claude (2026-08-23)` → `### CLAUDE.md`, body verbatim, `@~/.agent-rules-fixture.md` carried over unexpanded)
- Skills: `skills/hello/` (SKILL.md + reference/tone.md) → `skills/hello/`
- Commands/prompts: `commands/greet.md` → `prompts/greet.md` (`$ARGUMENTS` kept verbatim; Codex supports substitution here)
- Subagents: `agents/reviewer.md` → `agents/reviewer.toml` (`description` key, `developer_instructions` from the body; the name lives in the filename, not in a TOML key)
- Hooks: PreToolUse `Edit|Write` → `hooks.json` PreToolUse matcher `apply_patch` (Codex has one edit tool, so the two alternatives collapse onto it — a merge the mapping defines, not a loss)
- Permission rules: `Bash(git status:*)` allow → `rules/migrated.rules` `prefix_rule(pattern=["git", "status"], decision="allow")`
- Permission rules: `Bash(npm run build:*)` allow → `prefix_rule(pattern=["npm", "run", "build"], decision="allow")`
- Permission rules: `Bash(npm run test:*)` allow → `prefix_rule(pattern=["npm", "run", "test"], decision="allow")`
- Permission rules: `Bash(git push:*)` ask → `prefix_rule(pattern=["git", "push"], decision="prompt")`
- Permission rules: `Bash(rm:*)` deny → `prefix_rule(pattern=["rm"], decision="forbidden")`
- Env injection: `FIXTURE_FLAG` → `config.toml` `[shell_environment_policy.set]`

## Approximated (review recommended)
- Env injection `SERVICE_API_KEY`: the key was migrated, the value was not. `config.toml` holds `<REDACTED-REENTER>`; see manual action.

## Manual action required
- `SERVICE_API_KEY` (`settings.json`, `env`): re-enter the value by hand at `config.toml` → `[shell_environment_policy.set]`, which currently holds `<REDACTED-REENTER>`.
- Consider moving `prompts/greet.md` to a skill. Codex treats `prompts/` as deprecated and recommends skills instead; the file was migrated to the deprecated surface because that is where the source's command belongs today.

## Not migrated
- Hook event `Notification` (`settings.json`, hooks): outside Codex's 11 official events. Codex ignores unknown events silently, so migrating it would leave dead config behind. Command was `echo notify`.
- Hook event `ConfigChange` (`settings.json`, hooks): same reason — a Claude extension event with no Codex equivalent. Command was `echo claude-only-event`.
- Model (`settings.json`): `model = "claude-fable-5"` — not migrated. The target's existing `model` (`gpt-5.6-sol`) was left untouched.
- Approval policy (`settings.json`): `permissions.defaultMode = "bypassPermissions"`. Suggestion only, nothing written — see below.
- Credentials (`.credentials.json`): existence confirmed only. Never opened, never hashed, and deliberately absent from the ledger.
- MCP servers: **0 found** in `settings.json`. MCP is out of scope for this tool regardless — a definition usually carries its credential inline, and a redacted server would arrive registered and non-functional.

## Approval/sandbox suggestion (not applied)
Source `permissions.defaultMode = "bypassPermissions"` lines up with Codex `approval_policy = "never"` plus `sandbox_mode = "danger-full-access"` (automation level 3). **Nothing was written.** Set it yourself if you want it — the table lines the tools' automation levels up in the same order and does not claim the behaviors are identical.

## Verification
- `python3 -c "import tomllib…"` — `config.toml` parses after the merge.
- `jq -e . hooks.json` — valid JSON, top-level key is `hooks` (a wrong top-level key would make Codex ignore the whole file).
- Placeholder present: exactly 1 occurrence of `<REDACTED-REENTER>` in the target. The source held exactly 1 secret-bearing key, so the counts agree.
- Secret-shape scan of the whole target (`sk-`, `ghp_`, `xoxb-`, `AKIA` patterns) — no matches.
- Backup: `.migrate/20260823-110001/backup/` holds `AGENTS.md` and `config.toml`, matching `changes.json` `modified` exactly.
- Existing target content preserved: `AGENTS.md` still opens with `# Existing / Keep me.`; `config.toml` kept `model` and `[shell_environment_policy.set] EXISTING_KEY`.
- Ledger written with the 6 source files actually read. `.credentials.json` is absent because it was never opened.
