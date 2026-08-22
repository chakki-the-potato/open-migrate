# Migration Report: grok → codex (20260822-181726)

Source root: `test/fixtures/grok-home` (test mode)
Target root: `test/tmp/golden-run/grok-to-codex` (test mode)

## Scan summary
| Category | Found | Automatic | Approximate | Suggestion | Skipped | Impossible |
|---|---|---|---|---|---|---|
| Global rules | 1 | 1 | 0 | 0 | 0 | 0 |
| Skills | 1 | 0 | 1 | 0 | 0 | 0 |
| Commands / prompts | 0 | 0 | 0 | 0 | 0 | 0 |
| Subagents | 1 | 0 | 1 | 0 | 0 | 0 |
| Hooks | 2 | 0 | 1 | 0 | 0 | 1 |
| Permission rules | 5 | 5 | 0 | 0 | 0 | 0 |
| Env injection | 2 | 1 | 1 | 0 | 0 | 0 |
| Approval/sandbox policy | 2 | 0 | 0 | 1 | 0 | 1 |
| Non-migratable items | 3 | 0 | 0 | 0 | 0 | 3 |

## Migrated (automatic)
- Global rules: `rules/global.md` → `AGENTS.md` under `## Migrated from grok (2026-08-22)` / `### global.md`. Grok loads every `rules/*.md` alphabetically; this home holds one. The `@~/.agent-rules-fixture.md` import was carried over verbatim and not expanded. The target has no `AGENTS.override.md`, so the merge was safe.
- Permissions: `Bash(git status:*)` → `prefix_rule(pattern=["git", "status"], decision="allow")`. Tokens are split on whitespace and the trailing `:*` is dropped.
- Permissions: `Bash(npm run build:*)` and `Bash(npm run test:*)` → one `prefix_rule` line each.
- Permissions: `Bash(git push:*)` (ask) → `decision="prompt"`. Codex has a prompt tier, so the ask rule survives.
- Permissions: `Bash(rm:*)` (deny) → `decision="forbidden"`.
- Env injection: `FIXTURE_FLAG` → `[shell_environment_policy.set]`. Grok and Codex share the table name and structure, so this is a straight merge.

**All 5 permission rules converted.** Every one was a Bash prefix rule, the only shape the Starlark DSL can express.

## Approximated (review recommended)
- Skills: `skills/hello/` → `skills/hello/`, with **`user-invocable: true` dropped from the frontmatter.** That key is Grok-only; Codex does not read it. Only the key was removed — the rest of the frontmatter and the whole body are unchanged, and `reference/tone.md` came across untouched.
- Subagents: `agents/reviewer.md` → `agents/reviewer.toml`. `description` maps directly and the body becomes `developer_instructions`; the name lives in the filename. **Four Grok-only fields were dropped**: `promptMode: extend`, `capabilityMode: read-only`, `effort: high`, `maxTurns: 5`. Codex subagents have only `description` and `developer_instructions`, so there was nowhere to put any of them.
- Hooks: `PreToolUse` / `Edit|Write` → matcher `apply_patch`. Codex has one edit tool where Grok has two, so both alternatives de-duplicate onto a single name and the reverse cannot recover which was meant.
- Env injection: `SERVICE_API_KEY` written as `<REDACTED-REENTER>`. See manual action below.

## Manual action required
- `SERVICE_API_KEY` (`config.toml`, `[shell_environment_policy.set]`): re-enter the value by hand in the target's `[shell_environment_policy.set]`. The value was detected as a secret and is not recorded anywhere in this report.
- Subagent behavior: the four dropped fields above changed what `reviewer` does on Grok — `capabilityMode: read-only` in particular constrained it, and Codex has no field expressing that. Rebuild the constraint yourself if it mattered.

## Not migrated
- **MCP servers: 0 found** in `config.toml`. MCP is out of scope for this tool regardless — a definition carries its credential inline, and a redacted server arrives registered and broken. There were none here.
- Global rules: `GROK.md` — **not a migration target.** Grok does not read that filename, so it is dead config on the source rather than a rule file. Its contents were neither migrated nor quoted, and it is absent from the ledger.
- Hooks: `Notification` (command `echo notify`) — **dropped.** Codex has exactly 11 official events and `Notification` is not one of them; it would have been dead config on arrival.
- Commands: none found. Grok has no command surface at all.
- `[sandbox] profile = "off"` (`config.toml`): OS-level isolation whose meaning differs per tool. No equivalent mapping exists.
- `model = "grok-5-code"` (`config.toml`): model names differ per tool. The target's existing `model = "gpt-5.6-sol"` was left untouched.
- `auth.json`: never read. security.md forbids opening credential files, hashing included, so it is absent from the ledger too.

## Suggestion (nothing was written)
- Approval policy: source `[ui] permission_mode = "bypassPermissions"` corresponds to Codex `approval_policy = "never"` with `sandbox_mode = "danger-full-access"`. **Not applied** — neither key was written.

## Verification
- `jq -e . hooks.json` — valid, top-level `{"hooks": {...}}`.
- `rules/migrated.rules`: every `decision` value is a double-quoted string.
- TOML parse of `config.toml` after writing — valid. Two keys were inserted inside `[shell_environment_policy.set]`; nothing else was touched.
- `grep -rF '<REDACTED-REENTER>'` — 1 placeholder, matching the 1 secret-bearing key found in the source.
- Secret-shape scan (`sk-`, `ghp_`, `xoxb-`, `AKIA`) over the target — no match.
- `grep -rF 'OVERRIDDEN-DECOY'` excluding `.migrate/` — no match.
- `grep -rF 'user-invocable'` over the target — no match.
- No trace of `auth.json` in the target.
- Backup holds both files listed in `changes.json` `modified`.
