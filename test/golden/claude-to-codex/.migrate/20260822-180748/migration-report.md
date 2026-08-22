# Migration Report: claude → codex (20260822-180748)

Source root: `test/fixtures/claude-home` (test mode)
Target root: `test/tmp/golden-run/claude-to-codex` (test mode)

## Scan summary
| Category | Found | Automatic | Approximate | Suggestion | Skipped | Impossible |
|---|---|---|---|---|---|---|
| Global rules | 1 | 1 | 0 | 0 | 0 | 0 |
| Skills | 1 | 1 | 0 | 0 | 0 | 0 |
| Commands / prompts | 1 | 1 | 0 | 0 | 0 | 0 |
| Subagents | 1 | 1 | 0 | 0 | 0 | 0 |
| Hooks | 3 | 0 | 1 | 0 | 0 | 2 |
| Permission rules | 5 | 5 | 0 | 0 | 0 | 0 |
| Env injection | 2 | 1 | 1 | 0 | 0 | 0 |
| Approval/sandbox policy | 1 | 0 | 0 | 1 | 0 | 0 |
| Non-migratable items | 2 | 0 | 0 | 0 | 0 | 2 |

## Migrated (automatic)
- Global rules: `CLAUDE.md` → `AGENTS.md` under `## Migrated from claude (2026-08-22)` / `### CLAUDE.md`. The `@~/.agent-rules-fixture.md` import line was carried over verbatim and **not expanded** — the referenced file was never opened. The target has no `AGENTS.override.md`, so the merge was safe; had one existed, `AGENTS.md` would be dead config and the run would have stopped to ask.
- Skills: `skills/hello/` → `skills/hello/` (SKILL.md and reference/tone.md).
- Commands: `commands/greet.md` → `prompts/greet.md`. Codex has a real command surface, so this stays a command rather than becoming a skill, and `$ARGUMENTS` is supported on both sides and kept verbatim — **nothing was lost.** Codex does treat `prompts/` as deprecated and recommends skills, so consider moving it yourself.
- Subagents: `agents/reviewer.md` → `agents/reviewer.toml`. The name lives in the filename, not in a `name` key. The source carried no `tools`, `model`, or `color`, so nothing had to be dropped.
- Permissions: `Bash(git status:*)` → `prefix_rule(pattern=["git", "status"], decision="allow")`.
- Permissions: `Bash(npm run build:*)` and `Bash(npm run test:*)` → one `prefix_rule` line each. The positional union form is a read-side optimization and is not used when writing.
- Permissions: `Bash(git push:*)` (ask) → `decision="prompt"`. **Codex has a prompt tier, so the ask rule survives intact** — the same rule has nowhere to land when the target is Cursor.
- Permissions: `Bash(rm:*)` (deny) → `decision="forbidden"`.
- Env injection: `FIXTURE_FLAG` → `[shell_environment_policy.set]`.

**All 5 permission rules converted.** Every one was a Bash prefix rule, which is the only shape the Starlark DSL can express; a path, domain, or MCP rule would have had to go back verbatim.

## Approximated (review recommended)
- Hooks: `PreToolUse` / `Edit|Write` → matcher `apply_patch`. Codex has one edit tool where Claude has two, so the alternation collapses and both alternatives de-duplicate onto a single name. The reverse direction cannot recover which of `Edit` or `Write` was meant.
- Env injection: `SERVICE_API_KEY` written as `<REDACTED-REENTER>`. See manual action below.

## Manual action required
- `SERVICE_API_KEY` (`settings.json`, `env`): re-enter the value by hand in the target's `[shell_environment_policy.set]`. The value was detected as a secret and is not recorded anywhere in this report.

## Not migrated
- **MCP servers: 0 found** in `settings.json`. MCP is out of scope for this tool regardless — a definition carries its credential inline, and a redacted server arrives registered and broken. There were none here.
- Hooks: `Notification` (command `echo notify`) — **dropped.** Codex has exactly 11 official events and `Notification` is not one of them; Codex silently ignores anything else, so migrating it would have left dead config behind.
- Hooks: `ConfigChange` (command `echo claude-only-event`) — **dropped** for the same reason. It is a Claude extension event with no Codex counterpart.
- `model = "claude-fable-5"` (`settings.json`): model names differ per tool. The target's existing `model = "gpt-5.6-sol"` was left untouched.
- The source home's credential file (91 bytes): never read. security.md forbids opening credential files, hashing included, so it is absent from the ledger too.

## Suggestion (nothing was written)
- Approval/sandbox: source `permissions.defaultMode = "bypassPermissions"` corresponds to Codex `approval_policy = "never"` with `sandbox_mode = "danger-full-access"`. **Not applied** — neither key was written.

## Verification
- TOML parse of `config.toml` after writing — valid. Two keys were inserted inside `[shell_environment_policy.set]`; nothing else was touched.
- `jq -e . hooks.json` — valid, top-level `{"hooks": {...}}`. A wrong top-level key would make Codex ignore the whole file.
- `rules/migrated.rules`: every `decision` value is a double-quoted string. An unquoted `decision=allow` is a Starlark syntax error.
- `grep -rF '<REDACTED-REENTER>'` — 1 placeholder, matching the 1 secret-bearing key found in the source.
- Secret-shape scan (`sk-`, `ghp_`, `xoxb-`, `AKIA`) over the target — no match.
- No credential file, and no trace of one, in the target.
- Backup holds both files listed in `changes.json` `modified`.
