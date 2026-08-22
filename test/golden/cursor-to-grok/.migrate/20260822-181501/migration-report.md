# Migration Report: cursor → grok (20260822-181501)

Source root: `test/fixtures/cursor-home` (test mode)
Target root: `test/tmp/golden-run/cursor-to-grok` (test mode)

## Scan summary
| Category | Found | Automatic | Approximate | Suggestion | Skipped | Impossible |
|---|---|---|---|---|---|---|
| Global rules | 1 | 1 | 0 | 0 | 0 | 0 |
| Skills | 1 | 1 | 0 | 0 | 0 | 0 |
| Commands / prompts | 0 | 0 | 0 | 0 | 0 | 0 |
| Subagents | 1 | 0 | 1 | 0 | 0 | 0 |
| Hooks | 1 | 0 | 1 | 0 | 0 | 0 |
| Permission rules | 4 | 4 | 0 | 0 | 0 | 0 |
| Env injection | 0 | 0 | 0 | 0 | 0 | 0 |
| Approval/sandbox policy | 1 | 0 | 0 | 1 | 0 | 0 |
| Non-migratable items | 3 | 0 | 0 | 0 | 0 | 3 |

## Migrated (automatic)
- Global rules: `AGENTS.md` → `AGENTS.md` under `## Migrated from cursor (2026-08-22)` / `### AGENTS.md`. Cursor reads `AGENTS.md` natively, so it counts as a rule source even with no `.mdc` files present. The `@~/.agent-rules-fixture.md` import was carried over verbatim and not expanded. Written to the single `AGENTS.md` rather than `rules/`, which is easier to trace and has identical effect.
- Skills: `skills/hello/` → `skills/hello/` (SKILL.md and reference/tone.md).
- Permissions: `Shell(git status:*)` → `Bash(git status:*)`. The tool token is renamed because Grok uses Claude's permission syntax; the colon argument form is identical and kept as-is.
- Permissions: `Shell(npm run build:*)` → `Bash(npm run build:*)`.
- Permissions: `Shell(npm run test:*)` → `Bash(npm run test:*)`.
- Permissions: `Shell(rm:*)` (deny) → `Bash(rm:*)` (deny).

**All 4 permission rules converted.** Grok has an `ask` tier that Cursor lacks, so this direction gains a tier rather than losing one — the array simply stays empty.

## Approximated (review recommended)
- Subagents: `agents/reviewer.md` → `agents/reviewer.md` with camelCase frontmatter. `name` and `description` carry over unchanged, and **`model: inherit` survives** — Grok has a `model` field and `inherit` is a value both sides share, so that is lossless. **`readonly: true` was dropped**: it is a Cursor-only field with no counterpart in Grok's frontmatter.
- Hooks: `preToolUse` / matcher `Write` → `PreToolUse` / matcher `Edit|Write`. Grok uses Claude's tool names, where `Write` and `Edit` are separate tools, so Cursor's merged `Write` cannot be restored uniquely. **Restored as an alternation so both match** rather than narrowing the scope.

## Manual action required
- **User Rules**: Cursor keeps them in your account rather than on disk, so there is nothing here to read or migrate. Open Cursor's settings, look at User Rules, and move anything there into `AGENTS.md` yourself. This is an absence rather than a failure — no file was skipped.

## Not migrated
- **MCP servers: 0 found.** MCP is out of scope for this tool regardless — a definition carries its credential inline, and a redacted server arrives registered and broken. There were none here.
- Skills: `skills-cursor/canvas/` — **excluded.** `skills-cursor/` is app-managed built-in content, not user configuration, and the source doc declares it out of scope in both directions. Its contents were never opened, so it is absent from the ledger too.
- Commands: none found. Cursor's command surface is project-scope only, and this was a home-scope run.
- Env injection: none found. Cursor has no global env surface at all, so the target's existing `[shell_environment_policy.set]` was left exactly as it was.
- The source home's credential file (86 bytes): never read. security.md forbids opening credential files, hashing included, so it is absent from the ledger.

## Suggestion (nothing was written)
- Approval/sandbox: source `approvalMode = "allowlist"` corresponds to Grok `[ui] permission_mode = "default"` (ask). **Not applied** — no `[ui]` table was created.

## Verification
- TOML parse of `config.toml` after writing — valid. One line was rewritten (the `allow` array) and `deny` added; `[shell_environment_policy]` was not touched, since the source had no env block.
- `jq -e . hooks/migrated.json` — valid, top-level `{"hooks": {...}}`.
- `grep -rF 'CURSOR-BUILTIN-DECOY'` over the target excluding `.migrate/` — no match.
- Secret-shape scan (`sk-`, `ghp_`, `xoxb-`, `AKIA`) over the target — no match. No `<REDACTED-REENTER>` placeholder either, because the source carried no in-config secret.
- No credential file, and no trace of one, in the target.
- Backup holds both files listed in `changes.json` `modified`.
