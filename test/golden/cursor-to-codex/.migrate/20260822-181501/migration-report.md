# Migration Report: cursor → codex (20260822-181501)

Source root: `test/fixtures/cursor-home` (test mode)
Target root: `test/tmp/golden-run/cursor-to-codex` (test mode)

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
- Global rules: `AGENTS.md` → `AGENTS.md` under `## Migrated from cursor (2026-08-22)` / `### AGENTS.md`. Cursor reads `AGENTS.md` natively, so it counts as a rule source even with no `.mdc` files present. The `@~/.agent-rules-fixture.md` import was carried over verbatim and not expanded. The target has no `AGENTS.override.md`, so the merge was safe; had one existed, `AGENTS.md` would be dead config and the run would have stopped to ask.
- Skills: `skills/hello/` → `skills/hello/` (SKILL.md and reference/tone.md).
- Permissions: `Shell(git status:*)` → `prefix_rule(pattern=["git", "status"], decision="allow")`. Cursor's colon argument syntax is dropped and the tokens are split on whitespace, which is what the Starlark DSL takes.
- Permissions: `Shell(npm run build:*)` → `prefix_rule(pattern=["npm", "run", "build"], decision="allow")`.
- Permissions: `Shell(npm run test:*)` → `prefix_rule(pattern=["npm", "run", "test"], decision="allow")`.
- Permissions: `Shell(rm:*)` (deny) → `prefix_rule(pattern=["rm"], decision="forbidden")`.

**All 4 permission rules converted.** Every one was a shell rule, which is the only shape the Starlark DSL can express — a `Read(glob)`, `Write(glob)`, `WebFetch(domain)`, or `Mcp(server:tool)` token would have gone back verbatim under manual action instead.

## Approximated (review recommended)
- Subagents: `agents/reviewer.md` → `agents/reviewer.toml`. `description` maps directly and the body becomes `developer_instructions`; the name lives in the filename rather than a `name` key. **Two fields were dropped.** `model: inherit` has no Codex subagent field, and `readonly: true` has none either — both were dropped rather than approximated, because Codex would not read an invented key.
- Hooks: `preToolUse` / matcher `Write` → `PreToolUse` / matcher `apply_patch`. Codex names its edit tool `apply_patch`. The mapping was applied directly from Cursor's names, **not routed through Claude's** — a two-step conversion invents losses at the points where a mapping is many-to-one.

## Manual action required
- **User Rules**: Cursor keeps them in your account rather than on disk, so there is nothing here to read or migrate. Open Cursor's settings, look at User Rules, and move anything there into `AGENTS.md` yourself. This is an absence rather than a failure — no file was skipped.

## Not migrated
- **MCP servers: 0 found.** MCP is out of scope for this tool regardless — a definition carries its credential inline, and a redacted server arrives registered and broken. There were none here.
- Skills: `skills-cursor/canvas/` — **excluded.** `skills-cursor/` is app-managed built-in content, not user configuration, and the source doc declares it out of scope in both directions. Its contents were never opened, so it is absent from the ledger too.
- Commands: none found. Cursor's command surface is project-scope only, and this was a home-scope run.
- Env injection: none found. Cursor has no global env surface at all, so there was no block to migrate.
- The source home's credential file (86 bytes): never read. security.md forbids opening credential files, hashing included, so it is absent from the ledger.

## Suggestion (nothing was written)
- Approval/sandbox: source `approvalMode = "allowlist"` corresponds to Codex `approval_policy = "untrusted"` with `sandbox_mode = "read-only"`. **Not applied** — neither key was written. Note that Cursor's `allowlist` is deterministic while Codex's pairing is not an exact behavioral match; the table lines the levels up, it does not claim they are identical.

## Verification
- `jq -e . hooks.json` — valid, top-level `{"hooks": {...}}`. A wrong top-level key would make Codex ignore the whole file.
- `rules/migrated.rules`: every `decision` value is a double-quoted string. An unquoted `decision=allow` is a Starlark syntax error.
- TOML parse of `config.toml` — valid, and untouched apart from being backed up; the source had no env block to merge.
- `grep -rF 'CURSOR-BUILTIN-DECOY'` over the target excluding `.migrate/` — no match.
- Secret-shape scan (`sk-`, `ghp_`, `xoxb-`, `AKIA`) over the target — no match.
- No credential file, and no trace of one, in the target.
- Backup holds both files listed in `changes.json` `modified`.
