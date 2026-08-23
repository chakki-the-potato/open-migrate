# Migration Report: grok → codex (20260823-134627)

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

## Migrated (automatic)
- Global rules: rules/global.md → AGENTS.md (`## Migrated from grok (2026-08-23)` section, verbatim, `@~/.agent-rules-fixture.md` import kept unexpanded). It is the only rule file Grok loads here — there is no `~/.grok/AGENTS.md` in this source — but it still gets its own `### global.md` subheading, so the rule stays traceable to its file. The target has no `AGENTS.override.md`, so the merge went ahead
- Hooks: PreToolUse `Edit|Write` → hooks.json PreToolUse matcher `apply_patch`. Grok uses Claude's tool names and Codex has one edit tool where Grok has two, so both alternatives map onto `apply_patch` and were de-duplicated to one. The file was created with the required `{"hooks": {...}}` top-level structure
- Permission rules: Bash(git status:*) → rules/migrated.rules `prefix_rule(pattern=["git", "status"], decision="allow")`. Tokens split on whitespace and the trailing `:*` discarded
- Permission rules: Bash(npm run build:*) → `prefix_rule(pattern=["npm", "run", "build"], decision="allow")`
- Permission rules: Bash(npm run test:*) → `prefix_rule(pattern=["npm", "run", "test"], decision="allow")`
- Permission rules: Bash(git push:*) (ask) → `prefix_rule(pattern=["git", "push"], decision="prompt")`
- Permission rules: Bash(rm:*) (deny) → `prefix_rule(pattern=["rm"], decision="forbidden")`
- Env injection: FIXTURE_FLAG → `[shell_environment_policy.set]` in config.toml. Grok and Codex use the same table name and structure, so nothing was converted

All 5 permission rules converted; none were dropped. Every one is a Bash prefix rule whose tokens join into a pattern Codex's DSL can express — no quotes, no embedded whitespace, nothing near the length limit.

## Approximated (review recommended)
- Skills hello → skills/hello/: the directory copied over with its supporting file, but the frontmatter key `user-invocable: true` was dropped. It is Grok-specific, and Codex does not use it. Only that key was removed — the rest of the frontmatter and the whole body are unchanged. In Grok this skill was reachable as a slash command; in Codex that exposure is not carried by the same key.
- Subagents agents/reviewer.md → agents/reviewer.toml: `description` became the `description` key and the body became `developer_instructions`; the source's `name` supplied the filename, so no `name` key was written inside the TOML. **Four Grok-only frontmatter keys were dropped**, because Codex's subagent format holds only `description` and `developer_instructions`: `promptMode: extend`, `capabilityMode: read-only`, `effort: high`, `maxTurns: 5`. The subagent arrives without its prompt mode, its read-only capability constraint, its effort setting, and its turn limit.
- Env injection SERVICE_API_KEY (config.toml `[shell_environment_policy.set]` on both sides): the key was written to the target's `[shell_environment_policy.set]`, but its value is a detected secret, so it was replaced with `<REDACTED-REENTER>`. The key arrives; the value does not.

## Manual action required
- SERVICE_API_KEY (config.toml `[shell_environment_policy.set]` on both sides): re-enter the value by hand. It is present in the target as `<REDACTED-REENTER>`.
- Approval policy: source `[ui] permission_mode` = `bypassPermissions`, suggested Codex equivalent `approval_policy` = `never` with `sandbox_mode` = `danger-full-access` (procedure.md level 3). Nothing was written — this tool never sets either key.

## Not migrated
- Global rules GROK.md: Grok does not read a file by that name. It was configuration the source tool was already ignoring, so it is not a migration target. Its contents were never opened and it is absent from the ledger.
- Hooks `Notification` (hooks/migrated.json, command `echo notify`): outside Codex's 11 official events. Codex silently ignores it, so it was dropped rather than left behind as dead config.
- Env injection `inherit = "core"` (config.toml `[shell_environment_policy]`): inheritance policy rather than value injection. Codex has the same table and the same field, but it is policy there too, so there is no value-injection concept to migrate it into. The target's config.toml has no `[shell_environment_policy]` `inherit` key and none was added. Counted under Env injection rather than as a homeless item, because that is the category it belongs to.
- Sandbox (config.toml `[sandbox] profile`): current value `off`. Not migrated — this is OS-level isolation whose meaning differs per tool, so no equivalent mapping exists and no value is suggested for it. Counted under Approval/sandbox policy.
- Credentials (auth.json): existence confirmed only, per security.md. Never opened, so it is absent from the ledger.
- Model (config.toml `model`): current value `grok-5-code`. Not migrated — the target's `model` is `gpt-5.6-sol` and an xAI model name has no meaning there.
- Sessions and memory (`sessions/`, `memory/`): neither is present in this source. `memory/` is excluded by default in any case — it is conversation content rather than configuration.
- MCP servers: none found in config.toml. MCP is out of scope for this tool regardless — a definition usually carries its credential inline, and a redacted server would arrive registered and non-functional.

## Verification
- `python3 -c "import tomllib..." config.toml` — parses after the edit.
- `python3 -c "import tomllib..." agents/reviewer.toml` — parses.
- `jq -e . hooks.json` — ok.
- `grep -rF '<REDACTED-REENTER>'` outside .migrate/ — 1 hit. The source had exactly 1 secret-bearing key, so the counts match.
- `grep -rE 'sk-[A-Za-z0-9_-]{16,}'` outside .migrate/ — 0 hits. No secret shape reached the target.
- `grep -rl 'OVERRIDDEN-DECOY'` over the whole target — 0 files. Nothing from GROK.md reached the target.
- `grep -rl 'user-invocable'` outside .migrate/ — 0 files. The Grok-only frontmatter key was dropped rather than carried into a target that does not read it.
- Pre-existing target content survived: `model = "gpt-5.6-sol"` and `EXISTING_KEY = "keep"` still in config.toml, `# Existing` / `Keep me.` still at the top of AGENTS.md.
- The new env keys were appended inside the existing `[shell_environment_policy.set]` block rather than the file being reparsed and rewritten, so key order and table layout are unchanged.
- backup/ holds AGENTS.md and config.toml — exactly the two files in `changes.json`'s `modified`.
