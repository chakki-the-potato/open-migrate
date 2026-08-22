# Migration Report: grok → claude (20260822-181726)

Source root: `test/fixtures/grok-home` (test mode)
Target root: `test/tmp/golden-run/grok-to-claude` (test mode)

## Scan summary
| Category | Found | Automatic | Approximate | Suggestion | Skipped | Impossible |
|---|---|---|---|---|---|---|
| Global rules | 1 | 1 | 0 | 0 | 0 | 0 |
| Skills | 1 | 0 | 1 | 0 | 0 | 0 |
| Commands / prompts | 0 | 0 | 0 | 0 | 0 | 0 |
| Subagents | 1 | 0 | 1 | 0 | 0 | 0 |
| Hooks | 2 | 2 | 0 | 0 | 0 | 0 |
| Permission rules | 5 | 5 | 0 | 0 | 0 | 0 |
| Env injection | 2 | 1 | 1 | 0 | 0 | 0 |
| Approval/sandbox policy | 2 | 0 | 0 | 1 | 0 | 1 |
| Non-migratable items | 3 | 0 | 0 | 0 | 0 | 3 |

## Migrated (automatic)
- Global rules: `rules/global.md` → `CLAUDE.md` under `## Migrated from grok (2026-08-22)` / `### global.md`. Grok loads every `rules/*.md` alphabetically; this home holds one. The `@~/.agent-rules-fixture.md` import was carried over verbatim and not expanded.
- Hooks: `PreToolUse` / `Edit|Write` → **carried without conversion.** Grok's hook file has the same shape as Claude's `hooks` object, the same PascalCase event names, and the same tool names, so the alternation survives intact rather than collapsing.
- Hooks: `Notification` → carried unchanged. The source entry has no `matcher` key at all; an empty matcher was written explicitly so the intent (match everything) is stated rather than implied.
- Permissions: all five rule strings appended **verbatim**. Grok uses Claude's permission syntax and has the same three tiers, so `Bash(git push:*)` lands in `ask` and `Bash(rm:*)` in `deny` with nothing lost.
- Env injection: `FIXTURE_FLAG` → `env.FIXTURE_FLAG` in `settings.json`.

**All 5 permission rules converted losslessly.** Claude and Grok are the closest pair in this matrix — same syntax, same tiers, same tool names.

## Approximated (review recommended)
- Skills: `skills/hello/` → `skills/hello/`, with **`user-invocable: true` dropped from the frontmatter.** That key is Grok-only; Claude does not read it. Only the key was removed — the rest of the frontmatter and the whole body are unchanged, and `reference/tone.md` came across untouched. This is the case where a specific rule beats the general "copy the whole directory".
- Subagents: `agents/reviewer.md` → `agents/reviewer.md`. `name` and `description` map directly. **Four Grok-only fields were dropped**: `promptMode: extend`, `capabilityMode: read-only`, `effort: high`, and `maxTurns: 5`. Claude's subagent frontmatter has no field of any of those names, and writing them would produce frontmatter Claude ignores.
- Env injection: `SERVICE_API_KEY` written as `<REDACTED-REENTER>`. See manual action below.

## Manual action required
- `SERVICE_API_KEY` (`config.toml`, `[shell_environment_policy.set]`): re-enter the value by hand in `settings.json` → `env.SERVICE_API_KEY`. The value was detected as a secret and is not recorded anywhere in this report.
- Subagent behavior: the four dropped fields above changed what `reviewer` does on Grok — `capabilityMode: read-only` in particular constrained it. Claude expresses that through the `tools` field instead, which cannot be derived from `capabilityMode` without guessing. Set it yourself if the constraint mattered.

## Not migrated
- **MCP servers: 0 found** in `config.toml`. MCP is out of scope for this tool regardless — a definition carries its credential inline, and a redacted server arrives registered and broken. There were none here.
- Global rules: `GROK.md` — **not a migration target.** Grok does not read that filename, so it is dead config on the source rather than a rule file. Its contents were neither migrated nor quoted, and it is absent from the ledger.
- Commands: none found. Grok has no command surface at all — slash commands are built as skills there.
- `[sandbox] profile = "off"` (`config.toml`): OS-level isolation whose meaning differs per tool. No equivalent mapping exists, so the value is quoted here and nothing was applied.
- `model = "grok-5-code"` (`config.toml`): model names differ per tool. The target's existing `model` was left untouched.
- `auth.json`: never read. security.md forbids opening credential files, hashing included, so it is absent from the ledger too.

## Suggestion (nothing was written)
- Approval policy: source `[ui] permission_mode = "bypassPermissions"` corresponds to Claude `permissions.defaultMode = "bypassPermissions"`. **Not applied** — `defaultMode` is never set automatically.

## Verification
- `jq -e . settings.json` — valid.
- `grep -rF '<REDACTED-REENTER>'` — 1 placeholder, matching the 1 secret-bearing key found in the source.
- Secret-shape scan (`sk-`, `ghp_`, `xoxb-`, `AKIA`) over the target — no match.
- `grep -rF 'OVERRIDDEN-DECOY'` over the target excluding `.migrate/` — no match, so `GROK.md` did not leak through.
- `grep -rF 'user-invocable'` over the target — no match, so the Grok-only key was dropped everywhere it appeared.
- No trace of `auth.json` in the target.
- Backup holds both files listed in `changes.json` `modified`.
