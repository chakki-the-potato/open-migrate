# Migration Report: cursor → codex (20260823-132430)

## Scan summary
| Category | Found | Automatic | Approximate | Suggestion | Skipped | Excluded | Impossible |
|---|---|---|---|---|---|---|---|
| Global rules | 1 | 1 | 0 | 0 | 0 | 0 | 0 |
| Skills | 1 | 1 | 0 | 0 | 0 | 0 | 0 |
| Commands/prompts | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| Subagents | 1 | 0 | 1 | 0 | 0 | 0 | 0 |
| Hooks | 1 | 1 | 0 | 0 | 0 | 0 | 0 |
| Permission rules | 4 | 4 | 0 | 0 | 0 | 0 | 0 |
| Env injection | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| Approval/sandbox policy | 1 | 0 | 0 | 1 | 0 | 0 | 0 |
| Non-migratable items | 1 | 0 | 0 | 0 | 0 | 0 | 1 |

## Migrated (automatic)
- Global rules: AGENTS.md → AGENTS.md (`## Migrated from cursor (2026-08-23)` section, verbatim, `@~/.agent-rules-fixture.md` import kept unexpanded). There are no `.mdc` files in this source, but `AGENTS.md` is a rule surface Cursor reads natively, so it counts as the rule source rather than as "no rules to migrate". The target has no `AGENTS.override.md`, so the merge went ahead
- Skills: hello → skills/hello/ (SKILL.md and reference/tone.md). Cursor skills have no `$ARGUMENTS` substitution to begin with, so there was nothing to carry into Codex's substitution support — an absence, not a loss
- Hooks: `preToolUse` matcher `Write` → hooks.json PreToolUse matcher `apply_patch`. The mapping is direct in this direction; the file was created with the required `{"hooks": {...}}` top-level structure
- Permission rules: Shell(git status:*) → rules/migrated.rules `prefix_rule(pattern=["git", "status"], decision="allow")`. Tokens split on whitespace and the trailing `:*` discarded
- Permission rules: Shell(npm run build:*) → `prefix_rule(pattern=["npm", "run", "build"], decision="allow")`
- Permission rules: Shell(npm run test:*) → `prefix_rule(pattern=["npm", "run", "test"], decision="allow")`
- Permission rules: Shell(rm:*) (deny) → `prefix_rule(pattern=["rm"], decision="forbidden")`

## Approximated (review recommended)
- Subagents agents/reviewer.md → agents/reviewer.toml: `description` and the body carried over, and the source filename supplied the name — Codex takes the name from the filename, so no `name` key was written inside the TOML. **Two fields were dropped.** `model: inherit` has no corresponding key in Codex's subagent format, which holds only `description` and `developer_instructions`; `readonly: true` has none either. The subagent arrives without its model preference and without its read-only constraint.

## Manual action required
- User Rules: Cursor keeps them in the account rather than on disk, so there is no local file to migrate and nothing was read. Check your Cursor account's User Rules and move anything there into AGENTS.md by hand.
- Approval policy: source `approvalMode` = `allowlist`, suggested Codex equivalent `approval_policy` = `untrusted` with `sandbox_mode` = `read-only` (procedure.md level 1). Nothing was written. Note that the correspondence between Cursor's modes and the others has never been confirmed by research — `allowlist` is deterministic, so treat the suggestion as a starting point rather than an equivalence.

## Not migrated
- Credentials file (`.credentials.json` in the source home): existence confirmed only, per security.md. Never opened, so it is absent from the ledger.
- `skills-cursor/canvas/` in the source: app-managed built-in content, not migratable in either direction. Its contents were never opened, so it is absent from the ledger.
- Env injection: Cursor has no global env surface, so there was no global env block to migrate. Recorded as 0 found rather than left unmentioned. The target's own `[shell_environment_policy.set] EXISTING_KEY` was therefore never touched, and config.toml was not modified at all.
- Commands/prompts: `.cursor/commands/*.md` is a project-root surface, and this was a home-scope run. None found.
- MCP servers: no `mcp.json` in the source home, so none found. MCP is out of scope for this tool regardless — a definition usually carries its credential inline, and a redacted server would arrive registered and non-functional.

## Verification
- `jq -e . hooks.json` — ok.
- `python3 -c "import tomllib..." agents/reviewer.toml` — parses.
- `python3 -c "import tomllib..." config.toml` — parses. It was not modified by this run; there was no env block to merge and Codex's approval policy is never set automatically.
- `grep -rE 'sk-[A-Za-z0-9_-]{16,}'` outside .migrate/ — 0 hits. This source has no env surface and no secret-bearing key was found anywhere in it, so no placeholder was needed either.
- `grep -rl 'CURSOR-BUILTIN-DECOY'` over the whole target — 0 files. Nothing from the app-managed `skills-cursor/` area reached the target.
- Pre-existing target content survived: `model = "gpt-5.6-sol"` and `EXISTING_KEY = "keep"` still in config.toml, `# Existing` / `Keep me.` still at the top of AGENTS.md.
- backup/ holds AGENTS.md alone — exactly the one file in `changes.json`'s `modified`.
