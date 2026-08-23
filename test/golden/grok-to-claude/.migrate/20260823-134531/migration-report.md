# Migration Report: grok → claude (20260823-134531)

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

## Migrated (automatic)
- Global rules: rules/global.md → CLAUDE.md (`## Migrated from grok (2026-08-23)` section, verbatim, `@~/.agent-rules-fixture.md` import kept unexpanded). It is the only rule file Grok loads here — there is no `~/.grok/AGENTS.md` in this source — but it still gets its own `### global.md` subheading, so the rule stays traceable to its file
- Hooks: PreToolUse `Edit|Write` → settings.json PreToolUse, unchanged. Grok's hook file has the same shape as Claude's `hooks` object and uses Claude's tool names, so nothing was converted
- Hooks: Notification → settings.json Notification, unchanged. Both tools have the event. The source entry carries no `matcher` key and was merged as-is rather than having one invented for it
- Permission rules: Bash(git status:*), Bash(npm run build:*), Bash(npm run test:*) → `permissions.allow`, verbatim. Grok's compact string form already uses Claude's syntax
- Permission rules: Bash(git push:*) → `permissions.ask`, verbatim. The `ask` tier exists on both sides, so nothing was lost
- Permission rules: Bash(rm:*) → `permissions.deny`, verbatim
- Env injection: FIXTURE_FLAG → settings.json `env`

## Approximated (review recommended)
- Skills hello → skills/hello/: the directory copied over with its supporting file, but the frontmatter key `user-invocable: true` was dropped. It is Grok-specific, and Claude does not use it. Only that key was removed — the rest of the frontmatter and the whole body are unchanged. In Grok this skill was reachable as a slash command; in Claude that exposure is not carried by the same key.
- Subagents agents/reviewer.md → agents/reviewer.md: `name` and `description` map directly. **Four Grok-only frontmatter keys were dropped**, because Claude has no field of the same name for any of them: `promptMode: extend`, `capabilityMode: read-only`, `effort: high`, `maxTurns: 5`. The subagent arrives without its prompt mode, its read-only capability constraint, its effort setting, and its turn limit.
- Env injection SERVICE_API_KEY (config.toml `[shell_environment_policy.set]`): the key was written to settings.json `env`, but its value is a detected secret, so it was replaced with `<REDACTED-REENTER>`. The key arrives; the value does not.

## Manual action required
- SERVICE_API_KEY (config.toml `[shell_environment_policy.set]` → settings.json `env`): re-enter the value by hand. It is present in the target as `<REDACTED-REENTER>`.
- Approval policy: source `[ui] permission_mode` = `bypassPermissions`, suggested Claude equivalent `permissions.defaultMode` = `bypassPermissions` (procedure.md level 3). Nothing was written — this tool never sets it.

## Not migrated
- Global rules GROK.md: Grok does not read a file by that name. It was configuration the source tool was already ignoring, so it is not a migration target. Its contents were never opened and it is absent from the ledger.
- Env injection `inherit = "core"` (config.toml `[shell_environment_policy]`): inheritance policy rather than value injection. Claude's `env` object injects values and has no inheritance switch, so there is no target concept to migrate it into. Counted under Env injection rather than as a homeless item, because that is the category it belongs to.
- Sandbox (config.toml `[sandbox] profile`): current value `off`. Not migrated — this is OS-level isolation whose meaning differs per tool, so no equivalent mapping exists and no value is suggested for it. Counted under Approval/sandbox policy.
- Credentials (auth.json): existence confirmed only, per security.md. Never opened, so it is absent from the ledger.
- Model (config.toml `model`): current value `grok-5-code`. Not migrated — the target's `model` is `claude-fable-5` and an xAI model name has no meaning there.
- Sessions and memory (`sessions/`, `memory/`): neither is present in this source. `memory/` is excluded by default in any case — it is conversation content rather than configuration.
- MCP servers: none found in config.toml. MCP is out of scope for this tool regardless — a definition usually carries its credential inline, and a redacted server would arrive registered and non-functional.

## Verification
- `jq -e . settings.json` — ok.
- `grep -rF '<REDACTED-REENTER>'` outside .migrate/ — 1 hit. The source had exactly 1 secret-bearing key, so the counts match.
- `grep -rE 'sk-[A-Za-z0-9_-]{16,}'` outside .migrate/ — 0 hits. No secret shape reached the target.
- `grep -rl 'OVERRIDDEN-DECOY'` over the whole target — 0 files. Nothing from GROK.md reached the target.
- `grep -rl 'user-invocable'` outside .migrate/ — 0 files. The Grok-only frontmatter key was dropped rather than carried into a target that does not read it.
- Pre-existing target content survived: `EXISTING_KEY = "keep"` still in `env`, `Bash(ls:*)` still first in `permissions.allow`, the `Read` / `echo existing-pre` hook still first in `PreToolUse` with the migrated entry appended after it, `# Existing` / `Keep me.` still at the top of CLAUDE.md.
- backup/ holds CLAUDE.md and settings.json — exactly the two files in `changes.json`'s `modified`.
