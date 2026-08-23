# Migration Report: claude → codex (20260823-131255)

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
- Global rules: CLAUDE.md → AGENTS.md (`## Migrated from claude (2026-08-23)` section, verbatim, `@~/.agent-rules-fixture.md` import kept unexpanded)
- Skills: hello → skills/hello/ (SKILL.md and reference/tone.md)
- Commands/prompts: greet.md → prompts/greet.md (`$ARGUMENTS` kept verbatim)
- Subagents: reviewer.md → agents/reviewer.toml (description + developer_instructions; no `name` key inside the TOML)
- Hooks: PreToolUse `Edit|Write` → hooks.json PreToolUse `apply_patch` (both Claude names map to the one Codex name, de-duplicated)
- Permission rules: Bash(git status:*) → rules/migrated.rules `prefix_rule(pattern=["git", "status"], decision="allow")`
- Permission rules: Bash(npm run build:*) → `prefix_rule(pattern=["npm", "run", "build"], decision="allow")`
- Permission rules: Bash(npm run test:*) → `prefix_rule(pattern=["npm", "run", "test"], decision="allow")`
- Permission rules: Bash(git push:*) (ask) → `prefix_rule(pattern=["git", "push"], decision="prompt")`
- Permission rules: Bash(rm:*) (deny) → `prefix_rule(pattern=["rm"], decision="forbidden")`
- Env injection: FIXTURE_FLAG → `[shell_environment_policy.set]` in config.toml

## Approximated (review recommended)
- Env injection SERVICE_API_KEY (settings.json `env`): the key was written to `[shell_environment_policy.set]`, but its value is a detected secret, so it was replaced with `<REDACTED-REENTER>`. The key arrives; the value does not.

## Manual action required
- SERVICE_API_KEY (settings.json `env` → config.toml `[shell_environment_policy.set]`): re-enter the value by hand. It is present in the target as `<REDACTED-REENTER>`.
- Approval policy: source `permissions.defaultMode` = `bypassPermissions`. The suggested Codex equivalent is `approval_policy = "never"` with `sandbox_mode = "danger-full-access"` (procedure.md level 3). Nothing was written — apply it yourself if you want it.
- Commands/prompts: Codex treats `prompts/` as deprecated and recommends skills. Consider moving greet.md to a skill.

## Not migrated
- Hooks `Notification` (settings.json `hooks`, command `echo notify`): outside Codex's 11 official events. Codex silently ignores it, so it was dropped rather than left behind as dead config.
- Hooks `ConfigChange` (settings.json `hooks`, command `echo claude-only-event`): outside Codex's 11 official events. Same reason.
- Model (settings.json `model`): current value `claude-fable-5`. Not migrated — a Claude model name has no meaning in Codex's `model` key, and the target already carries `gpt-5.6-sol`.
- Credentials file (`.credentials.json` in the source home): existence confirmed only, per security.md. Never opened, so it is absent from the ledger.
- MCP servers: none found in settings.json. MCP is out of scope for this tool in any case — a server definition usually carries its credential inline, and a redacted server would arrive registered and non-functional.

## Verification
- `jq -e . hooks.json` — ok.
- `python3 -c "import tomllib..." config.toml` — parses.
- `grep -rF '<REDACTED-REENTER>'` outside .migrate/ — 1 hit. The source had exactly 1 secret-bearing key, so the counts match.
- `grep -rE 'sk-[A-Za-z0-9_-]{16,}'` outside .migrate/ — 0 hits. No secret shape reached the target.
- Pre-existing target content survived: `EXISTING_KEY = "keep"` still in config.toml, `# Existing` / `Keep me.` still at the top of AGENTS.md.
- backup/ holds AGENTS.md and config.toml — exactly the two files in `changes.json`'s `modified`, and nothing else.
