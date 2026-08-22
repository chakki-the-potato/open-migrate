# Migration Report: claude → grok (20260822-181038)

Source root: `test/fixtures/claude-home` (test mode)
Target root: `test/tmp/golden-run/claude-to-grok` (test mode)

## Scan summary
| Category | Found | Automatic | Approximate | Suggestion | Skipped | Impossible |
|---|---|---|---|---|---|---|
| Global rules | 1 | 1 | 0 | 0 | 0 | 0 |
| Skills | 1 | 1 | 0 | 0 | 0 | 0 |
| Commands / prompts | 1 | 0 | 1 | 0 | 0 | 0 |
| Subagents | 1 | 1 | 0 | 0 | 0 | 0 |
| Hooks | 3 | 2 | 0 | 0 | 0 | 1 |
| Permission rules | 5 | 5 | 0 | 0 | 0 | 0 |
| Env injection | 2 | 1 | 1 | 0 | 0 | 0 |
| Approval/sandbox policy | 1 | 0 | 0 | 1 | 0 | 0 |
| Non-migratable items | 2 | 0 | 0 | 0 | 0 | 2 |

## Migrated (automatic)
- Global rules: `CLAUDE.md` → `AGENTS.md` under `## Migrated from claude (2026-08-22)` / `### CLAUDE.md`. The `@~/.agent-rules-fixture.md` import line was carried over verbatim and **not expanded**. Written to the single `AGENTS.md` rather than `rules/`, which is easier to trace and has identical effect since every `rules/*.md` is loaded anyway.
- Skills: `skills/hello/` → `skills/hello/` (SKILL.md and reference/tone.md).
- Subagents: `agents/reviewer.md` → `agents/reviewer.md`. Grok's frontmatter is camelCase; the source keys `name` and `description` are already single words, so nothing needed converting. Grok also has a `color` field, so had the source carried one it would have survived — unlike Cursor, where it is dropped.
- Hooks: `PreToolUse` / `Edit|Write` → **carried without conversion.** Grok's hook file has the same shape as Claude's `hooks` object and uses the same PascalCase event names and the same tool names, so the matcher survives as `Edit|Write` rather than collapsing. This is the one target where that alternation is not an approximation.
- Hooks: `Notification` → carried unchanged. It is one of Grok's 15 events.
- Permissions: all five rule strings appended **verbatim** to `[permission]`. Grok uses Claude's permission syntax, and it has an `ask` tier, so `Bash(git push:*)` lands in `ask` rather than becoming a manual action the way it does on Cursor. `Bash(rm:*)` lands in `deny`.
- Env injection: `FIXTURE_FLAG` → `[shell_environment_policy.set]`. Grok reuses Codex's table name and structure.

**All 5 permission rules converted losslessly.** Grok is the only target in this set where that is true — the syntax and all three tiers match Claude exactly.

## Approximated (review recommended)
- Commands: `commands/greet.md` → `skills/greet/SKILL.md` with `user-invocable: true`. Grok has no command surface, so it becomes a skill. The source has no `description`, so **the body's first sentence was used verbatim rather than invented** — synthesized, not authored. The `$ARGUMENTS` token was left exactly as it is, which Grok supports, so nothing was lost there.
- Env injection: `SERVICE_API_KEY` written as `<REDACTED-REENTER>`. See manual action below.

## Manual action required
- `SERVICE_API_KEY` (`settings.json`, `env`): re-enter the value by hand in the target's `[shell_environment_policy.set]`. The value was detected as a secret and is not recorded anywhere in this report.

## Not migrated
- **MCP servers: 0 found** in `settings.json`. MCP is out of scope for this tool regardless — a definition carries its credential inline, and a redacted server arrives registered and broken. There were none here.
- Hooks: `ConfigChange` (command `echo claude-only-event`) — **dropped.** Grok has 15 events and `ConfigChange` is not among them; guessing a mapping is forbidden.
- `model = "claude-fable-5"` (`settings.json`): model names differ per tool. The target's existing `model = "grok-5-code"` was left untouched.
- The source home's credential file (91 bytes): never read. security.md forbids opening credential files, hashing included, so it is absent from the ledger too.

## Suggestion (nothing was written)
- Approval/sandbox: source `permissions.defaultMode = "bypassPermissions"` corresponds to Grok `[ui] permission_mode = "bypassPermissions"` (the product calls it always-approve). **Not applied** — no `[ui]` table was created.

## Verification
- TOML parse of `config.toml` after writing — valid. Edits were line-level: two keys appended inside `[shell_environment_policy.set]`, the `allow` array line rewritten, `ask` and `deny` added. Comments and key order elsewhere untouched.
- `jq -e . hooks/migrated.json` — valid, top-level `{"hooks": {...}}`.
- `grep -rF '<REDACTED-REENTER>'` — 1 placeholder, matching the 1 secret-bearing key found in the source.
- Secret-shape scan (`sk-`, `ghp_`, `xoxb-`, `AKIA`) over the target — no match.
- No credential file, and no trace of one, in the target.
- Backup holds both files listed in `changes.json` `modified`.
