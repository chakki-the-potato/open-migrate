# Migration Report: claude → cursor (20260822-180938)

Source root: `test/fixtures/claude-home` (test mode)
Target root: `test/tmp/golden-run/claude-to-cursor` (test mode)
Scope: home only — no project root was given, which is why the global rules below could not be written.

## Scan summary
| Category | Found | Automatic | Approximate | Suggestion | Skipped | Impossible |
|---|---|---|---|---|---|---|
| Global rules | 1 | 0 | 0 | 0 | 0 | 1 |
| Skills | 1 | 1 | 0 | 0 | 0 | 0 |
| Commands / prompts | 1 | 0 | 1 | 0 | 0 | 0 |
| Subagents | 1 | 1 | 0 | 0 | 0 | 0 |
| Hooks | 3 | 0 | 1 | 0 | 0 | 2 |
| Permission rules | 5 | 4 | 0 | 0 | 0 | 1 |
| Env injection | 2 | 0 | 0 | 0 | 0 | 2 |
| Approval/sandbox policy | 1 | 0 | 0 | 1 | 0 | 0 |
| Non-migratable items | 2 | 0 | 0 | 0 | 0 | 2 |

## Migrated (automatic)
- Skills: `skills/hello/` → `skills/hello/` (SKILL.md and reference/tone.md). Written under `skills/`, never `skills-cursor/`, which is app-managed.
- Subagents: `agents/reviewer.md` → `agents/reviewer.md`. Cursor's frontmatter takes `name`/`description`/`model`/`readonly`/`is_background`; the source carried only `name` and `description`, so no `tools` or `color` had to be dropped.
- Permissions: `Bash(git status:*)` → `Shell(git status:*)`. The tool name is renamed because Cursor has no `Bash` tool; the colon argument syntax is identical on both sides and kept as-is.
- Permissions: `Bash(npm run build:*)` → `Shell(npm run build:*)`.
- Permissions: `Bash(npm run test:*)` → `Shell(npm run test:*)`.
- Permissions: `Bash(rm:*)` (deny) → `Shell(rm:*)` (deny).

## Approximated (review recommended)
- Commands: `commands/greet.md` → `skills/greet/SKILL.md`. Cursor has no command surface, so it becomes a skill. Two losses. The source has no `description`, so **the body's first sentence was used verbatim rather than invented** — synthesized, not authored. And **Cursor skills have no `$ARGUMENTS` substitution**, so the token survives as literal text and will never be replaced; the body was not edited.
- Hooks: `PreToolUse` / `Edit|Write` → `preToolUse` matcher `Write`. Cursor has one write matcher where Claude has two, so both alternatives map onto `Write` and de-duplicate to a single token. The reverse cannot recover which was meant and would have to restore `Edit|Write`.

## Manual action required
- **Global rules (`CLAUDE.md`): nothing was written.** Cursor has no global rule file — the equivalent is User Rules, stored in your Cursor account, which cannot be written to disk. Paste this in yourself, or re-run naming a project root so it can go into that project's `AGENTS.md`:

```
# Global Rules

@~/.agent-rules-fixture.md

- Answer in Korean.
- Never commit secrets.
```

  The `@~/.agent-rules-fixture.md` line is an import that was never expanded, so whatever it points at has to come across too.

- Permission rule (`settings.json`, `permissions.ask`): `Bash(git push:*)` — **Cursor has no `ask` tier.** Putting it in `allow` or `deny` would distort what the rule means, so it went into neither. Decide which you want.
- **Env injection: Cursor has no global env surface**, so both keys from `settings.json` `env` are unmigratable. Move them into a shell profile or a per-server `env` yourself:
  - `FIXTURE_FLAG` (`settings.json`) — value `"1"`.
  - `SERVICE_API_KEY` (`settings.json`) — detected as a secret. The value is not recorded anywhere in this report.

**1 of 5 permission rules had no tier to land in.** The other 4 converted by renaming the tool token.

## Not migrated
- **MCP servers: 0 found** in `settings.json`. MCP is out of scope for this tool regardless — a definition carries its credential inline, and a redacted server arrives registered and broken. There were none here.
- Hooks: `Notification` (command `echo notify`) — **dropped.** Cursor has no `Notification` event.
- Hooks: `ConfigChange` (command `echo claude-only-event`) — **dropped.** A Claude extension event with no entry in Cursor's eight camelCase events, and guessing a mapping is forbidden.
- `model = "claude-fable-5"` (`settings.json`): model names differ per tool.
- The source home's credential file (91 bytes): never read. security.md forbids opening credential files, hashing included, so it is absent from the ledger too.

## Suggestion (nothing was written)
- Approval/sandbox: source `permissions.defaultMode = "bypassPermissions"` corresponds to Cursor `approvalMode = "unrestricted"`. **Not applied** — the existing `approvalMode = "allowlist"` was left exactly as it was.

## Verification
- `jq -e .` on `cli-config.json` and `hooks.json` — both valid.
- Secret-shape scan (`sk-`, `ghp_`, `xoxb-`, `AKIA`) over the target — no match. No secret was written, since Cursor has no env surface to write one into, and no `<REDACTED-REENTER>` placeholder exists for the same reason.
- `skills-cursor/` untouched: `APP-MANAGED-DECOY-UNTOUCHED` still present and unmodified.
- No credential file, and no trace of one, in the target.
- Backup holds both files listed in `changes.json` `modified`.
