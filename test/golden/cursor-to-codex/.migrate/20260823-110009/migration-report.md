# Migration Report: cursor → codex (20260823-110009)

Source root: `<REPO>/test/fixtures/cursor-home` (test mode — not the real `~/.cursor`)
Target root: `<TARGET>` (test mode — not the real `~/.codex`)
Scope: home. Confirm: approved in full, nothing excluded.

## Scan summary
| Category | Found | Automatic | Approximate | Suggestion | Skipped | Excluded | Impossible |
|---|---|---|---|---|---|---|---|
| Global rules | 1 | 1 | 0 | 0 | 0 | 0 | 0 |
| Skills | 2 | 1 | 0 | 0 | 0 | 0 | 1 |
| Commands/prompts | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| Subagents | 1 | 0 | 1 | 0 | 0 | 0 | 0 |
| Hooks | 1 | 1 | 0 | 0 | 0 | 0 | 0 |
| Permission rules | 4 | 4 | 0 | 0 | 0 | 0 | 0 |
| Env injection | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| Approval/sandbox policy | 1 | 0 | 0 | 1 | 0 | 0 | 0 |
| Non-migratable items | 1 | 0 | 0 | 0 | 0 | 0 | 1 |

Commands is zero because Cursor's command surface (`.cursor/commands/*.md`) is project-scoped and this was a home-scope run. Env injection is zero because **Cursor has no global env surface at all** — there was nothing to find, not something that failed.

## Migrated (automatic)
- Global rules: `AGENTS.md` → `AGENTS.md` (appended `## Migrated from cursor (2026-08-23)` → `### AGENTS.md`, body verbatim, `@~/.agent-rules-fixture.md` carried over unexpanded). The target has no `AGENTS.override.md`, so `AGENTS.md` is the file Codex actually reads and the merge was safe to make.
- Skills: `skills/hello/` (SKILL.md + reference/tone.md) → `skills/hello/`
- Hooks: `preToolUse` matcher `Write` → `hooks.json` PreToolUse matcher `apply_patch`. Both tools have exactly one edit tool, so this mapping is one-to-one and nothing was widened or narrowed. The names were mapped directly, not routed through a third tool's vocabulary.
- Permission rules: `Shell(git status:*)` allow → `rules/migrated.rules` `prefix_rule(pattern=["git", "status"], decision="allow")`
- Permission rules: `Shell(npm run build:*)` allow → `prefix_rule(pattern=["npm", "run", "build"], decision="allow")`
- Permission rules: `Shell(npm run test:*)` allow → `prefix_rule(pattern=["npm", "run", "test"], decision="allow")`
- Permission rules: `Shell(rm:*)` deny → `prefix_rule(pattern=["rm"], decision="forbidden")`

Each rule is on its own line even where two share the `npm run` prefix. The positional union form (`["build", "test"]`) is a read-side convenience and is not used when writing.

There were **no `.mdc` files** in this source. That is not a reason to conclude there were no rules — Cursor reads `AGENTS.md` natively, so it is a rule source in its own right, and it is the one that carried the rules here.

## Approximated (review recommended)
- Subagents `agents/reviewer.md` → `agents/reviewer.toml`. `description` and the body carried over. **Two frontmatter fields were dropped:** `model: inherit` and `readonly: true`. Codex's subagent TOML has neither field, so there was nowhere to put them. The `readonly` loss is the one that changes behavior — the agent is no longer restricted to read-only operation on the target. The `name` was not written as a TOML key; in Codex the filename carries it.

## Not migrated
- Skills `skills-cursor/canvas/` (`skills-cursor/`): app-managed built-in Cursor content, not user configuration. It is not migratable in either direction, and its contents were never opened. Counted under Skills rather than the catch-all category — it is a skill that could not travel.
- Approval policy (`cli-config.json`): `approvalMode = "allowlist"`. Suggestion only, nothing written — see below.
- Credentials (`.credentials.json`): existence confirmed only. Never opened, never hashed, and deliberately absent from the ledger.
- MCP servers: **0 found** — this source has no `mcp.json`. MCP is out of scope for this tool regardless.

`config.toml` was **not modified** by this run. Cursor has no env surface and the approval policy is never applied automatically, so nothing needed to go into it. That is why the backup directory holds only `AGENTS.md`.

## Manual action required
- **User Rules** (no local file): Cursor stores User Rules in the account, cloud-synced, with nothing on disk to read. Nothing could be migrated automatically. Open Cursor's settings, copy your User Rules, and paste them into `AGENTS.md` by hand if you want them on this side.

## Approval/sandbox suggestion (not applied)
Source `approvalMode = "allowlist"` lines up with Codex `approval_policy = "untrusted"` plus `sandbox_mode = "read-only"` (automation level 1 — mostly asks). **Nothing was written.** Treat this one with extra care: Cursor's `allowlist` is deterministic while its `auto-review` routes commands through a sandbox and a classifier, and the correspondence to the other tools' modes has never been confirmed by research.

## Verification
- `jq -e . hooks.json` — valid JSON, top-level key is `hooks` (a wrong top-level key would make Codex ignore the whole file).
- `python3 -c "import tomllib…"` — `config.toml` still parses; this run never touched it.
- No secrets were found in the source, so no placeholder was written and none is expected. Secret-shape scan of the whole target (high-entropy prefix patterns) — no matches.
- Backup: `.migrate/20260823-110009/backup/` holds `AGENTS.md`, matching `changes.json` `modified` exactly.
- Existing target content preserved: `AGENTS.md` still opens with `# Existing / Keep me.`; `config.toml` kept `model` and `[shell_environment_policy.set] EXISTING_KEY` untouched.
- Ledger written with the 6 source files actually read. `.credentials.json` and everything under `skills-cursor/` are absent because none of them was opened.
