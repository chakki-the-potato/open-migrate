# Migration Report: grok → cursor (20260823-134728)

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

## Migrated (automatic)
- Hooks: PreToolUse `Edit|Write` → hooks.json `preToolUse` with matcher `Write`. Grok uses Claude's tool names, and Cursor has one write matcher where Grok has two, so both alternatives map onto `Write` and were de-duplicated to one
- Permission rules: Bash(git status:*) → cli-config.json `permissions.allow` `Shell(git status:*)`. The token had to be renamed: Cursor has no `Bash` tool. The colon argument syntax was kept as-is
- Permission rules: Bash(npm run build:*) → `Shell(npm run build:*)`
- Permission rules: Bash(npm run test:*) → `Shell(npm run test:*)`
- Permission rules: Bash(rm:*) → `permissions.deny` `Shell(rm:*)`

4 of 5 permission rules converted. The one that did not is listed under manual action below.

## Approximated (review recommended)
- Skills hello → skills/hello/: the directory copied over with its supporting file, but the frontmatter key `user-invocable: true` was dropped. It is Grok-specific, and Cursor does not use it. Only that key was removed — the rest of the frontmatter and the whole body are unchanged. In Grok this skill was reachable as a slash command; in Cursor that exposure is not carried by the same key.
- Subagents agents/reviewer.md → agents/reviewer.md: `name` and `description` map directly. **Four Grok-only frontmatter keys were dropped**, because Cursor's subagent frontmatter holds only `name`, `description`, `model`, `readonly`, and `is_background`: `promptMode: extend`, `capabilityMode: read-only`, `effort: high`, `maxTurns: 5`. The subagent arrives without its prompt mode, its read-only capability constraint, its effort setting, and its turn limit. Note that Cursor has a `readonly` field of its own — but the source's `capabilityMode: read-only` is a different key with a different value space, and mapping one onto the other without confirmation would be a guess, so it was dropped like the rest.

## Manual action required
- Global rules (rules/global.md): Cursor has no global rule file. The equivalent is User Rules, which lives in the Cursor account and cannot be written to disk, and no project root was given for this run. Nothing was written. Paste the text below into Cursor's User Rules by hand. The `@~/.agent-rules-fixture.md` import line was not expanded, so whatever it points at has to be brought over separately.

```markdown
# Global Rules

@~/.agent-rules-fixture.md

- Answer in Korean.
- Never commit secrets.
```

- Env injection FIXTURE_FLAG (config.toml `[shell_environment_policy.set]`, current value `1`): Cursor has no global env surface. Move it into a per-server `env` block or your shell profile.
- Env injection SERVICE_API_KEY (config.toml `[shell_environment_policy.set]`): same — no global env surface in Cursor. The value is a detected secret and is not reproduced here; take it from the source config.toml yourself.
- Env injection `inherit` (config.toml `[shell_environment_policy]`, current value `core`): not migratable for two separate reasons, and both hold. It is inheritance policy rather than value injection, so no target has a concept to receive it; and Cursor has no env surface at all. The value is quoted so you can reproduce the setting if your shell needs the equivalent.
- Permission rule Bash(git push:*) (config.toml `[permission] ask`): Cursor has no `ask`/`prompt` tier. Putting it in `allow` or `deny` would distort what it meant, so it was left out of both. The original rule string is `Bash(git push:*)`.
- Hooks `Notification` (hooks/migrated.json, command `echo notify`): Cursor has no corresponding event. Dropped — rebuild it by hand if you need it.
- Approval policy: source `[ui] permission_mode` = `bypassPermissions`, suggested Cursor equivalent `approvalMode` = `unrestricted` (procedure.md level 3). The target's existing `approvalMode` is `allowlist` and was left untouched — this tool never sets it.

## Not migrated
- Global rules GROK.md: Grok does not read a file by that name. It was configuration the source tool was already ignoring, so it is not a migration target. Its contents were never opened and it is absent from the ledger.
- Sandbox (config.toml `[sandbox] profile`): current value `off`. Not migrated — this is OS-level isolation whose meaning differs per tool, so no equivalent mapping exists and no value is suggested for it. Counted under Approval/sandbox policy.
- Credentials (auth.json): existence confirmed only, per security.md. Never opened, so it is absent from the ledger.
- Model (config.toml `model`): current value `grok-5-code`. Cursor's cli-config.json has no equivalent key that would accept it.
- Commands/prompts: Grok has no command surface, so there was nothing to find. Recorded as 0 rather than left unmentioned.
- Sessions and memory (`sessions/`, `memory/`): neither is present in this source. `memory/` is excluded by default in any case — it is conversation content rather than configuration.
- MCP servers: none found in config.toml. MCP is out of scope for this tool regardless — a definition usually carries its credential inline, and a redacted server would arrive registered and non-functional.
- `skills-cursor/canvas/` in the target is app-managed built-in content. Nothing was written there and nothing was read from it.

## Verification
- `jq -e . hooks.json` — ok. `jq -e . cli-config.json` — ok.
- `grep -rF '<REDACTED-REENTER>'` outside .migrate/ — 0 hits, and 0 is the right answer here. The source's one secret-bearing key belongs to a category Cursor cannot receive at all, so no placeholder was written; the key is in the manual-action list instead.
- `grep -rE 'sk-[A-Za-z0-9_-]{16,}'` outside .migrate/ — 0 hits. No secret shape reached the target.
- `grep -rl 'OVERRIDDEN-DECOY'` over the whole target — 0 files. Nothing from GROK.md reached the target.
- `grep -rl 'user-invocable'` outside .migrate/ — 0 files. The Grok-only frontmatter key was dropped rather than carried into a target that does not read it.
- Pre-existing target content survived: `Shell(ls)` still first in `permissions.allow`, `echo existing-session` still in `hooks.sessionStart`, `approvalMode` still `allowlist`.
- `skills-cursor/canvas/SKILL.md` still carries its untouched marker — the app-managed area was not written to.
- backup/ holds hooks.json and cli-config.json — exactly the two files in `changes.json`'s `modified`.
