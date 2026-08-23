# Migration Report: cursor → grok (20260823-110010)

Source root: `<REPO>/test/fixtures/cursor-home` (test mode — not the real `~/.cursor`)
Target root: `<TARGET>` (test mode — not the real `~/.grok`)
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

Commands is zero because Cursor's command surface (`.cursor/commands/*.md`) is project-scoped and this was a home-scope run. Env injection is zero because **Cursor has no global env surface at all** — there was nothing to find, not something that failed. The target's own `[shell_environment_policy]` was left exactly as it was.

## Migrated (automatic)
- Global rules: `AGENTS.md` → `AGENTS.md` (appended `## Migrated from cursor (2026-08-23)` → `### AGENTS.md`, body verbatim, `@~/.agent-rules-fixture.md` carried over unexpanded). Written to `AGENTS.md` rather than `rules/`: every `rules/*.md` is loaded anyway, so a single file is easier to trace with identical effect.
- Skills: `skills/hello/` (SKILL.md + reference/tone.md) → `skills/hello/`
- Permission rules: `Shell(git status:*)` allow → `config.toml` `[permission] allow` `Bash(git status:*)`
- Permission rules: `Shell(npm run build:*)` allow → `Bash(npm run build:*)`
- Permission rules: `Shell(npm run test:*)` allow → `Bash(npm run test:*)`
- Permission rules: `Shell(rm:*)` deny → `[permission] deny` `Bash(rm:*)`

The tool name had to be renamed on every one of those: Grok uses Claude's rule syntax and has no `Shell` tool, so a rule left as `Shell(...)` would match nothing. The colon argument syntax (`:*`) is shared and was kept as-is. `[permission]` had no `deny` key before this run, so that line was added inside the existing table block.

There were **no `.mdc` files** in this source. That is not a reason to conclude there were no rules — Cursor reads `AGENTS.md` natively, so it is a rule source in its own right, and it is the one that carried the rules here.

## Approximated (review recommended)
- Subagents `agents/reviewer.md` → `agents/reviewer.md`. `name` and `description` carried over. `model: inherit` was **kept as-is** — `inherit` is a value both tools share, so that part is lossless. `readonly: true` is Cursor-only and has no field of the same name in Grok's frontmatter, so it was **dropped**. The agent is no longer restricted to read-only operation on the target; Grok has `capabilityMode` and `permissionMode` fields, but mapping `readonly` onto either of them is a guess this tool will not make for you.
- Hooks `preToolUse` matcher `Write` → `PreToolUse` matcher `Edit|Write`. Grok uses Claude's tool names, where Cursor's single `Write` matcher corresponds to two tools, so the reverse of that mapping is not unique. Restoring it as an alternation keeps both matching, which is the safe direction — **but it is wider than what the source literally said.** Picking just one would have narrowed the hook below the source's scope, which is why it is not an option.

## Not migrated
- Skills `skills-cursor/canvas/` (`skills-cursor/`): app-managed built-in Cursor content, not user configuration. It is not migratable in either direction, and its contents were never opened. Counted under Skills rather than the catch-all category — it is a skill that could not travel.
- Approval policy (`cli-config.json`): `approvalMode = "allowlist"`. Suggestion only, nothing written — see below.
- Credentials (`.credentials.json`): existence confirmed only. Never opened, never hashed, and deliberately absent from the ledger.
- MCP servers: **0 found** — this source has no `mcp.json`. MCP is out of scope for this tool regardless.

## Manual action required
- **User Rules** (no local file): Cursor stores User Rules in the account, cloud-synced, with nothing on disk to read. Nothing could be migrated automatically. Open Cursor's settings, copy your User Rules, and paste them into `AGENTS.md` by hand if you want them on this side.

## Approval/sandbox suggestion (not applied)
Source `approvalMode = "allowlist"` lines up with Grok's `[ui] permission_mode = "default"` (automation level 1 — mostly asks). **Nothing was written.** Two cautions rather than one here: Cursor's `allowlist` is deterministic while its `auto-review` uses a sandbox and a classifier, and that correspondence has never been confirmed by research; and Grok's `permission_mode` also accepts `auto`, `dontAsk`, and `plan`, which have no row in the mapping table at all.

## Verification
- `python3 -c "import tomllib…"` — `config.toml` parses after the merge. The file was edited line by line rather than re-serialized, so key order and spacing survived.
- `jq -e . hooks/migrated.json` — valid JSON, top-level key is `hooks`.
- No secrets were found in the source, so no placeholder was written and none is expected. Secret-shape scan of the whole target (high-entropy prefix patterns) — no matches.
- Backup: `.migrate/20260823-110010/backup/` holds `AGENTS.md` and `config.toml`, matching `changes.json` `modified` exactly.
- Existing target content preserved: `AGENTS.md` still opens with `# Existing / Keep me.`; `config.toml` kept `model`, `[shell_environment_policy] inherit`, `EXISTING_KEY`, and `Bash(ls:*)` at the head of `[permission] allow`.
- Ledger written with the 6 source files actually read. `.credentials.json` and everything under `skills-cursor/` are absent because none of them was opened.
