# Migration Report: cursor → claude (20260822-181436)

Source root: `test/fixtures/cursor-home` (test mode)
Target root: `test/tmp/golden-run/cursor-to-claude` (test mode)

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
- Global rules: `AGENTS.md` → `CLAUDE.md` under `## Migrated from cursor (2026-08-22)` / `### AGENTS.md`. Cursor reads `AGENTS.md` natively, so it counts as a rule source even though the home holds no `.mdc` files — concluding "no rules to migrate" from the absence of `.mdc` would have stranded the whole file. The `@~/.agent-rules-fixture.md` import was carried over verbatim and not expanded.
- Skills: `skills/hello/` → `skills/hello/` (SKILL.md and reference/tone.md).
- Permissions: `Shell(git status:*)` → `Bash(git status:*)`. The tool name is renamed because Claude has no `Shell` tool — writing `Shell(...)` would produce a rule that matches nothing. The colon argument syntax is identical and kept as-is.
- Permissions: `Shell(npm run build:*)` → `Bash(npm run build:*)`.
- Permissions: `Shell(npm run test:*)` → `Bash(npm run test:*)`.
- Permissions: `Shell(rm:*)` (deny) → `Bash(rm:*)` (deny).

**All 4 permission rules converted.** Cursor has no `ask` tier, so there was no third array to reconcile — the loss in this direction runs the other way.

## Approximated (review recommended)
- Subagents: `agents/reviewer.md` → `agents/reviewer.md`. `name` and `description` map directly, and **`model: inherit` was carried over as-is** — `inherit` is a value both tools share, so that field is lossless rather than guessed. **`readonly: true` was dropped**: Claude's subagent frontmatter has no such field, and inventing one would produce frontmatter Claude does not read.
- Hooks: `preToolUse` / matcher `Write` → `PreToolUse` / matcher `Edit|Write`. Cursor's single `Write` matcher is what Claude's `Edit` and `Write` merge into, so the reverse is not unique. **Restored as an alternation so both match** — picking one would narrow the scope below what the source specified.

## Manual action required
- **User Rules**: Cursor keeps them in your account rather than on disk, so there is nothing here to read or migrate. Open Cursor's settings, look at User Rules, and move anything there into `CLAUDE.md` yourself. This is an absence rather than a failure — no file was skipped.

## Not migrated
- **MCP servers: 0 found.** MCP is out of scope for this tool regardless — a definition carries its credential inline, and a redacted server arrives registered and broken. There were none here.
- Skills: `skills-cursor/canvas/` — **excluded.** `skills-cursor/` is app-managed built-in content, not user configuration, and the source doc declares it out of scope in both directions. Its contents were never opened, so it is absent from the ledger too.
- Commands: none found. Cursor's command surface (`.cursor/commands/*.md`) is project-scope only, and this was a home-scope run.
- Env injection: none found. Cursor has no global env surface at all, so there was no block to migrate.
- The source home's credential file (86 bytes): never read. security.md forbids opening credential files, hashing included, so it is absent from the ledger.

## Suggestion (nothing was written)
- Approval/sandbox: source `approvalMode = "allowlist"` corresponds to Claude `permissions.defaultMode = "default"`. **Not applied** — `defaultMode` is never set automatically. The target's existing settings were left as they were.

## Verification
- `jq -e . settings.json` — valid.
- `grep -rF 'CURSOR-BUILTIN-DECOY'` over the target excluding `.migrate/` — no match, so the app-managed skill did not leak through.
- Secret-shape scan (`sk-`, `ghp_`, `xoxb-`, `AKIA`) over the target — no match. No `<REDACTED-REENTER>` placeholder either, because Cursor has no env surface and the source carried no in-config secret.
- No credential file, and no trace of one, in the target.
- Backup holds both files listed in `changes.json` `modified`.
