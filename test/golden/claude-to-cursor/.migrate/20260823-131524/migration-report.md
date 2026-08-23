# Migration Report: claude → cursor (20260823-131524)

## Scan summary
| Category | Found | Automatic | Approximate | Suggestion | Skipped | Excluded | Impossible |
|---|---|---|---|---|---|---|---|
| Global rules | 1 | 0 | 0 | 0 | 0 | 0 | 1 |
| Skills | 1 | 1 | 0 | 0 | 0 | 0 | 0 |
| Commands/prompts | 1 | 0 | 1 | 0 | 0 | 0 | 0 |
| Subagents | 1 | 1 | 0 | 0 | 0 | 0 | 0 |
| Hooks | 3 | 1 | 0 | 0 | 0 | 0 | 2 |
| Permission rules | 5 | 4 | 0 | 0 | 0 | 0 | 1 |
| Env injection | 2 | 0 | 0 | 0 | 0 | 0 | 2 |
| Approval/sandbox policy | 1 | 0 | 0 | 1 | 0 | 0 | 0 |
| Non-migratable items | 2 | 0 | 0 | 0 | 0 | 0 | 2 |

## Migrated (automatic)
- Skills: hello → skills/hello/ (SKILL.md and reference/tone.md)
- Subagents: reviewer.md → agents/reviewer.md (`name` and `description` carried over; the source had no `tools`, `model`, or `color`, so nothing was dropped)
- Permission rules: Bash(git status:*) → cli-config.json `permissions.allow` `Shell(git status:*)`
- Permission rules: Bash(npm run build:*) → `Shell(npm run build:*)`
- Permission rules: Bash(npm run test:*) → `Shell(npm run test:*)`
- Permission rules: Bash(rm:*) → `permissions.deny` `Shell(rm:*)`
- Hooks: PreToolUse `Edit|Write` → hooks.json `preToolUse` with matcher `Write` (Claude's `Edit` and `Write` both map to Cursor's `Write`, de-duplicated to one)

## Approximated (review recommended)
- Commands/prompts greet.md → skills/greet/SKILL.md: Cursor has no command surface, so the command was wrapped as a skill. Two losses. The source had no `description`, so the body's first sentence was used verbatim rather than inventing one. And `$ARGUMENTS` has no equivalent in a Cursor skill — the token stays in the body as literal text and will never be substituted.

## Manual action required
- Global rules (CLAUDE.md): Cursor has no global rule file. The equivalent is User Rules, which lives in the Cursor account and cannot be written to disk, and no project root was given for this run. Nothing was written. Paste the text below into Cursor's User Rules by hand. The `@~/.agent-rules-fixture.md` import line was not expanded, so whatever it points at has to be brought over separately.

```markdown
# Global Rules

@~/.agent-rules-fixture.md

- Answer in Korean.
- Never commit secrets.
```
- Env injection FIXTURE_FLAG (settings.json `env`, current value `1`): Cursor has no global env surface. Move it into a per-server `env` block or your shell profile.
- Env injection SERVICE_API_KEY (settings.json `env`): same — no global env surface in Cursor. The value is a detected secret and is not reproduced here; take it from the source `settings.json` yourself.
- Permission rules Bash(git push:*) (settings.json `permissions.ask`): Cursor has no `ask`/`prompt` tier. Putting it in `allow` or `deny` would distort what it meant, so it was left out of both. The original rule string is `Bash(git push:*)`.
- Hooks `ConfigChange` (settings.json `hooks`, command `echo claude-only-event`): no event of that name in Cursor's mapping table, and guessing one is forbidden. Rebuild it by hand if you need it.
- Approval policy: source `permissions.defaultMode` = `bypassPermissions`. The suggested Cursor equivalent is `approvalMode = "unrestricted"` (procedure.md level 3). The target's existing `approvalMode` is `allowlist` and was left untouched — this tool never sets it.

## Not migrated
- Hooks `Notification` (settings.json `hooks`, command `echo notify`): Cursor has no corresponding event. Dropped.
- Model (settings.json `model`): current value `claude-fable-5`. Cursor's config has no equivalent key that would accept it.
- Credentials file (`.credentials.json` in the source home): existence confirmed only, per security.md. Never opened, so it is absent from the ledger.
- MCP servers: none found in settings.json. MCP is out of scope for this tool regardless — a definition usually carries its credential inline, and a redacted server would arrive registered and non-functional.
- `skills-cursor/canvas/` in the target is app-managed built-in content. Nothing was written there and nothing was read from it.

## Verification
- `jq -e . hooks.json` — ok. `jq -e . cli-config.json` — ok.
- `grep -rF '<REDACTED-REENTER>'` outside .migrate/ — 0 hits, and 0 is the right answer here. The source's one secret-bearing key belongs to a category Cursor cannot receive at all, so no placeholder was written; the key is in the manual-action list instead.
- `grep -rE 'sk-[A-Za-z0-9_-]{16,}'` outside .migrate/ — 0 hits. No secret shape reached the target.
- Pre-existing target content survived: `Shell(ls)` still first in `permissions.allow`, `echo existing-session` still in `hooks.sessionStart`, `approvalMode` still `allowlist`.
- `skills-cursor/canvas/SKILL.md` still carries its untouched marker — the app-managed area was not written to.
- backup/ holds hooks.json and cli-config.json — exactly the two files in `changes.json`'s `modified`.

## Note on Cursor's compatibility loading
Cursor can read `~/.claude/skills/` and `~/.claude/agents/` directly, so the hello skill and the reviewer subagent may have been visible to Cursor already. Confirming that requires asking, and this run was a blanket approval, so they were migrated rather than skipped — the documented choice in that situation. If your Cursor settings have those compatibility paths enabled, you now have each of them in two places.
