# Migration Report: cursor → claude (20260823-132333)

## Scan summary
| Category | Found | Automatic | Approximate | Suggestion | Skipped | Excluded | Impossible |
|---|---|---|---|---|---|---|---|
| Global rules | 1 | 1 | 0 | 0 | 0 | 0 | 0 |
| Skills | 1 | 1 | 0 | 0 | 0 | 0 | 0 |
| Commands/prompts | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| Subagents | 1 | 0 | 1 | 0 | 0 | 0 | 0 |
| Hooks | 1 | 0 | 1 | 0 | 0 | 0 | 0 |
| Permission rules | 4 | 4 | 0 | 0 | 0 | 0 | 0 |
| Env injection | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| Approval/sandbox policy | 1 | 0 | 0 | 1 | 0 | 0 | 0 |
| Non-migratable items | 1 | 0 | 0 | 0 | 0 | 0 | 1 |

## Migrated (automatic)
- Global rules: AGENTS.md → CLAUDE.md (`## Migrated from cursor (2026-08-23)` section, verbatim, `@~/.agent-rules-fixture.md` import kept unexpanded). There are no `.mdc` files in this source, but `AGENTS.md` is a rule surface Cursor reads natively, so it counts as the rule source rather than as "no rules to migrate"
- Skills: hello → skills/hello/ (SKILL.md and reference/tone.md). Cursor skills have no `$ARGUMENTS` substitution to begin with, so there was nothing to carry into Claude's substitution support — an absence, not a loss
- Permission rules: Shell(git status:*) → `Bash(git status:*)` in settings.json `permissions.allow`. The token had to be renamed: Claude has no `Shell` tool, so `Shell(...)` would have matched nothing. The colon argument syntax was kept as-is
- Permission rules: Shell(npm run build:*) → `Bash(npm run build:*)`
- Permission rules: Shell(npm run test:*) → `Bash(npm run test:*)`
- Permission rules: Shell(rm:*) → `Bash(rm:*)` in `permissions.deny`

## Approximated (review recommended)
- Subagents agents/reviewer.md → agents/reviewer.md: `name` and `description` map directly, and `model: inherit` was carried over as-is — `inherit` is a value both tools share, so that part is lossless. **`readonly: true` was dropped**: Claude's subagent frontmatter has no corresponding field, and inventing one would be a guess. The subagent arrives without its read-only constraint.
- Hooks `preToolUse` matcher `Write` → `PreToolUse` matcher `Edit|Write`: Cursor's single `Write` matcher is what Claude's `Write` and `Edit` collapse into, so the reverse is not unique. It was restored as the alternation `Edit|Write` so both match. Picking just one would have narrowed the hook's scope beyond what the source specified — but the widening is an approximation either way, and if the original hook was only ever meant for new files it now also fires on edits.

## Manual action required
- User Rules: Cursor keeps them in the account rather than on disk, so there is no local file to migrate and nothing was read. Check your Cursor account's User Rules and move anything there into CLAUDE.md by hand.
- Approval policy: source `approvalMode` = `allowlist`, suggested Claude equivalent `permissions.defaultMode` = `default` (procedure.md level 1). Nothing was written. Note that the correspondence between Cursor's modes and Claude's has never been confirmed by research — `allowlist` is deterministic while Claude's `default` simply asks, so treat the suggestion as a starting point rather than an equivalence.

## Not migrated
- Credentials file (`.credentials.json` in the source home): existence confirmed only, per security.md. Never opened, so it is absent from the ledger.
- `skills-cursor/canvas/` in the source: app-managed built-in content, not migratable in either direction. Its contents were never opened, so it is absent from the ledger.
- Env injection: Cursor has no global env surface, so there was no global env block to migrate. Recorded as 0 found rather than left unmentioned.
- Commands/prompts: `.cursor/commands/*.md` is a project-root surface, and this was a home-scope run. None found.
- MCP servers: no `mcp.json` in the source home, so none found. MCP is out of scope for this tool regardless — a definition usually carries its credential inline, and a redacted server would arrive registered and non-functional.

## Verification
- `jq -e . settings.json` — ok.
- `grep -rF '<REDACTED-REENTER>'` outside .migrate/ — 0 hits, and 0 is the right answer here. This source has no env surface and no secret-bearing key was found anywhere in it, so there was nothing to redact.
- `grep -rE 'sk-[A-Za-z0-9_-]{16,}'` outside .migrate/ — 0 hits.
- `grep -rl 'CURSOR-BUILTIN-DECOY'` over the whole target — 0 files. Nothing from the app-managed `skills-cursor/` area reached the target.
- Pre-existing target content survived: `EXISTING_KEY = "keep"` still in `env`, `Bash(ls:*)` still first in `permissions.allow`, the `Read` / `echo existing-pre` hook still first in `PreToolUse` with the migrated entry appended after it, `# Existing` / `Keep me.` still at the top of CLAUDE.md.
- backup/ holds CLAUDE.md and settings.json — exactly the two files in `changes.json`'s `modified`.
