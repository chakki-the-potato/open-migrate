# Migration Report: cursor → claude (20260823-110008)

Source root: `<REPO>/test/fixtures/cursor-home` (test mode — not the real `~/.cursor`)
Target root: `<TARGET>` (test mode — not the real `~/.claude`)
Scope: home. Confirm: approved in full, nothing excluded.

## Scan summary
| Category | Found | Automatic | Approximate | Suggestion | Skipped | Excluded | Impossible |
|---|---|---|---|---|---|---|---|
| Global rules | 1 | 1 | 0 | 0 | 0 | 0 | 0 |
| Skills | 2 | 1 | 0 | 0 | 0 | 0 | 1 |
| Commands/prompts | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| Subagents | 1 | 0 | 1 | 0 | 0 | 0 | 0 |
| Hooks | 1 | 0 | 1 | 0 | 0 | 0 | 0 |
| Permission rules | 4 | 4 | 0 | 0 | 0 | 0 | 0 |
| Env injection | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| Approval/sandbox policy | 1 | 0 | 0 | 1 | 0 | 0 | 0 |
| Non-migratable items | 1 | 0 | 0 | 0 | 0 | 0 | 1 |

Commands is zero because Cursor's command surface (`.cursor/commands/*.md`) is project-scoped and this was a home-scope run. Env injection is zero because **Cursor has no global env surface at all** — there was nothing to find, not something that failed.

## Migrated (automatic)
- Global rules: `AGENTS.md` → `CLAUDE.md` (appended `## Migrated from cursor (2026-08-23)` → `### AGENTS.md`, body verbatim, `@~/.agent-rules-fixture.md` carried over unexpanded)
- Skills: `skills/hello/` (SKILL.md + reference/tone.md) → `skills/hello/`
- Permission rules: `Shell(git status:*)` allow → `settings.json` `permissions.allow` `Bash(git status:*)`
- Permission rules: `Shell(npm run build:*)` allow → `Bash(npm run build:*)`
- Permission rules: `Shell(npm run test:*)` allow → `Bash(npm run test:*)`
- Permission rules: `Shell(rm:*)` deny → `permissions.deny` `Bash(rm:*)`

The tool name had to be renamed on every one of those: Claude has no `Shell` tool, so a rule left as `Shell(...)` would match nothing. The colon argument syntax (`:*`) is shared and was kept as-is.

There were **no `.mdc` files** in this source. That is not a reason to conclude there were no rules — Cursor reads `AGENTS.md` natively, so it is a rule source in its own right, and it is the one that carried the rules here.

## Approximated (review recommended)
- Subagents `agents/reviewer.md` → `agents/reviewer.md`. `name` and `description` map directly. `model: inherit` was **carried over as-is** — `inherit` is a value both tools share, so that part is lossless. `readonly: true` has no corresponding field in Claude's subagent frontmatter and was **dropped**. The agent will no longer be restricted to read-only operation on the target; if that mattered, express it through the `tools` field by hand.
- Hooks `preToolUse` matcher `Write` → `PreToolUse` matcher `Edit|Write`. Cursor has one `Write` matcher where Claude has two tools, so the reverse of that mapping is not unique. Restoring it as an alternation keeps both matching, which is the safe direction — **but it is wider than what the source literally said.** Picking just one would have narrowed the hook below the source's scope, which is why it is not an option.

## Manual action required
- **User Rules** (no local file): Cursor stores User Rules in the account, cloud-synced, with nothing on disk to read. Nothing could be migrated automatically. Open Cursor's settings, copy your User Rules, and paste them into `CLAUDE.md` by hand if you want them on this side.

## Not migrated
- Skills `skills-cursor/canvas/` (`skills-cursor/`): app-managed built-in Cursor content, not user configuration. It is not migratable in either direction, and its contents were never opened. Counted under Skills rather than the catch-all category — it is a skill that could not travel.
- Approval policy (`cli-config.json`): `approvalMode = "allowlist"`. Suggestion only, nothing written — see below.
- Credentials (`.credentials.json`): existence confirmed only. Never opened, never hashed, and deliberately absent from the ledger.
- MCP servers: **0 found** — this source has no `mcp.json`. MCP is out of scope for this tool regardless.

## Approval/sandbox suggestion (not applied)
Source `approvalMode = "allowlist"` lines up with Claude's `permissions.defaultMode = "default"` (automation level 1 — mostly asks). **Nothing was written.** Treat this one with extra care: Cursor's `allowlist` is deterministic while its `auto-review` routes commands through a sandbox and a classifier, and the correspondence to Claude's modes has never been confirmed by research. The table lines the levels up in order; it does not claim the behaviors match.

## Verification
- `jq -e . settings.json` — valid JSON after the merge.
- No secrets were found in the source, so no placeholder was written and none is expected. Secret-shape scan of the whole target (high-entropy prefix patterns) — no matches.
- Backup: `.migrate/20260823-110008/backup/` holds `settings.json` and `CLAUDE.md`, matching `changes.json` `modified` exactly.
- Existing target content preserved: `CLAUDE.md` still opens with `# Existing / Keep me.`; `settings.json` kept `model`, `env.EXISTING_KEY`, `permissions.allow[Bash(ls:*)]`, and its existing PreToolUse hook on `Read`.
- Ledger written with the 6 source files actually read. `.credentials.json` and everything under `skills-cursor/` are absent because none of them was opened.
