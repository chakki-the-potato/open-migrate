# Migration Report: claude → cursor (20260823-110002)

Source root: `<REPO>/test/fixtures/claude-home` (test mode — not the real `~/.claude`)
Target root: `<TARGET>` (test mode — not the real `~/.cursor`)
Scope: home. Confirm: approved in full, nothing excluded.

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
- Skills: `skills/hello/` (SKILL.md + reference/tone.md) → `skills/hello/`
- Subagents: `agents/reviewer.md` → `agents/reviewer.md` (`name` and `description` only; the source had no `tools`, `model`, or `color` to drop)
- Hooks: PreToolUse `Edit|Write` → `hooks.json` `preToolUse`, matcher `Write` (Cursor has a single `Write` matcher, so the two alternatives collapse onto it)
- Permission rules: `Bash(git status:*)` allow → `cli-config.json` `permissions.allow` `Shell(git status:*)`
- Permission rules: `Bash(npm run build:*)` allow → `Shell(npm run build:*)`
- Permission rules: `Bash(npm run test:*)` allow → `Shell(npm run test:*)`
- Permission rules: `Bash(rm:*)` deny → `permissions.deny` `Shell(rm:*)`

The tool name is renamed on every one of those: Cursor has no `Bash` tool, so a rule left as `Bash(...)` would match nothing. The colon argument syntax (`:*`) is Cursor's too and was kept as-is.

## Approximated (review recommended)
- Commands/prompts `commands/greet.md` → `skills/greet/SKILL.md`. Cursor's command surface is deprecated, so the target doc sends commands to skills instead. Two things happened to it. The source command had no `description`, so the body's first sentence was used verbatim rather than invented. And Cursor skills have no `$1`-`$9` / `$ARGUMENTS` substitution — the token survives as literal text in the body, so the skill now says the word `$ARGUMENTS` instead of interpolating an argument. **This is a real loss, not a formatting detail.**

## Manual action required
- Global rules (`CLAUDE.md`): Cursor has no global rule file. Its equivalent, User Rules, lives in the Cursor account and cannot be written to disk, and no project root was given for this run, so **nothing was written**. Paste this into Cursor's User Rules by hand:

```
# Global Rules

@~/.agent-rules-fixture.md

- Answer in Korean.
- Never commit secrets.
```

- Permission rule `Bash(git push:*)` (`settings.json`, `permissions.ask`): **Cursor has no `ask` tier.** Putting it in `allow` would grant what the source wanted to prompt for, and putting it in `deny` would forbid what the source allowed with a prompt — both distort the original. It was left out entirely; recreate the intent by hand if you need it.
- Env injection `FIXTURE_FLAG = "1"` (`settings.json`, `env`): Cursor has no global env surface. Move it into a per-server `env` block or your shell profile.
- Env injection `SERVICE_API_KEY` (`settings.json`, `env`): same — no global env surface. The value was never written anywhere, and it is not recorded here; re-enter it by hand wherever you move it.

## Not migrated
- Hook event `Notification` (`settings.json`, hooks): Cursor has no corresponding event. Command was `echo notify`.
- Hook event `ConfigChange` (`settings.json`, hooks): outside Cursor's eight mapped events and not one of the two known-unsupported ones. Guessing a mapping is forbidden, so it was dropped for manual review. Command was `echo claude-only-event`.
- Model (`settings.json`): `model = "claude-fable-5"` — not migrated.
- Approval policy (`settings.json`): `permissions.defaultMode = "bypassPermissions"`. Suggestion only, nothing written — see below. The target's existing `approvalMode` (`allowlist`) was left untouched.
- Credentials (`.credentials.json`): existence confirmed only. Never opened, never hashed, and deliberately absent from the ledger.
- MCP servers: **0 found** in `settings.json`. MCP is out of scope for this tool regardless.

## Possible duplication (Cursor reads some of this natively)
Cursor loads parts of other tools' configuration without conversion — `~/.claude/skills/`, `~/.claude/agents/`, and, with third-party hook support enabled, `~/.claude/settings.json` hooks. Those paths can be switched off in settings, so the safe move under a blanket approval is to migrate rather than skip. **The consequence is that the skill, the subagent, and the migrated hook may now be visible to Cursor twice.** Nothing was deleted from the source. If Cursor was already reading the Claude home, remove one copy.

## Approval/sandbox suggestion (not applied)
Source `permissions.defaultMode = "bypassPermissions"` lines up with Cursor's `approvalMode = "unrestricted"` (automation level 3). **Nothing was written**, and `approvalMode` is never changed automatically even when it already holds a value. Note also that Cursor's modes differ from Claude's in whether a classifier is involved, and that correspondence has never been confirmed by research — treat this as a starting point, not a translation.

## Verification
- `jq -e . hooks.json` and `jq -e . cli-config.json` — both valid after the merge.
- Placeholder count: **0**, and that is correct here. Cursor has no env surface, so nothing was written for the one secret-bearing source key; it appears by name only under manual action.
- Secret-shape scan of the whole target (high-entropy prefix patterns) — no matches.
- `skills-cursor/canvas/SKILL.md` still reads `APP-MANAGED-DECOY-UNTOUCHED`. That directory is app-managed and was never a write destination.
- Backup: `.migrate/20260823-110002/backup/` holds `hooks.json` and `cli-config.json`, matching `changes.json` `modified` exactly.
- Existing target content preserved: the `sessionStart` hook, `approvalMode`, and `Shell(ls)` in `permissions.allow` all survived.
- Ledger written with the 6 source files actually read. `.credentials.json` is absent because it was never opened.
