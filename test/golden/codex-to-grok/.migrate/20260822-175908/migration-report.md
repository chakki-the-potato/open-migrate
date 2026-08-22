# Migration Report: codex → grok (20260822-175908)

Source root: `test/fixtures/codex-home` (test mode)
Target root: `test/tmp/golden-run/codex-to-grok` (test mode)

## Scan summary
| Category | Found | Automatic | Approximate | Suggestion | Skipped | Impossible |
|---|---|---|---|---|---|---|
| Global rules | 1 | 1 | 0 | 0 | 0 | 0 |
| Skills | 1 | 1 | 0 | 0 | 0 | 0 |
| Commands / prompts | 1 | 0 | 1 | 0 | 0 | 0 |
| Subagents | 1 | 1 | 0 | 0 | 0 | 0 |
| Hooks | 5 | 3 | 2 | 0 | 0 | 0 |
| Permission rules | 7 | 4 | 0 | 0 | 0 | 3 |
| Env injection | 3 | 2 | 1 | 0 | 0 | 0 |
| Approval/sandbox policy | 1 | 0 | 0 | 1 | 0 | 0 |
| Non-migratable items | 6 | 0 | 0 | 0 | 0 | 6 |

## Migrated (automatic)
- Global rules: `AGENTS.override.md` → `AGENTS.md` under `## Migrated from codex (2026-08-22)` / `### AGENTS.override.md`. The `@~/.agent-rules-fixture.md` import line was carried over verbatim. Written to the single `AGENTS.md` rather than `rules/`, which is easier to trace and has identical effect.
- Skills: `skills/hello/` → `skills/hello/`.
- Subagents: `agents/reviewer.toml` → `agents/reviewer.md` with camelCase frontmatter. The source had only `description` and `developer_instructions`, so no key needed case conversion.
- Hooks: `PreToolUse` / `read_file` → matcher `Read`. Grok uses Claude's tool names.
- Hooks: `Notification` → migrated unchanged. It is unofficial in Codex but one of Grok's 15 events, so it becomes live config rather than the dead entry it was.
- Hooks: `SessionStart` → migrated unchanged.
- Permissions: `["git","status"]` allow → `Bash(git status:*)`. The DSL is reversed by joining tokens with spaces and appending `:*`.
- Permissions: `["git","push"]` prompt → `Bash(git push:*)` in `ask`. **Grok has an `ask` tier, so nothing was lost here** — the same rule has to be handed back manually when the target is Cursor.
- Permissions: `["npm","run",["build","test"]]` allow → `Bash(npm run build:*)` and `Bash(npm run test:*)`.
- Permissions: `["rm"]` forbidden → `Bash(rm:*)` (deny).
- Env injection: `FIXTURE_FLAG` → `[shell_environment_policy.set]`. Same table name and shape on both sides.
- Env injection: `TRUSTED_CLIENT_SHA256S` → `[shell_environment_policy.set]`, **carried verbatim rather than redacted.** 64 hex characters under a key naming the algorithm is a digest — a public identifier, not a credential. Redacting it would break a working setting.

## Approximated (review recommended)
- Commands: `prompts/greet.md` → `skills/greet/SKILL.md` with `user-invocable: true`. Grok has no command surface, so it becomes a skill. The source has no `description`, so **the body's first sentence was used verbatim rather than invented** — synthesized, not authored. The `$ARGUMENTS` token was left exactly as it is, which Grok supports, so nothing was lost there.
- Hooks: `PreToolUse` / `apply_patch` → matcher `Edit|Write`. Grok splits the edit tool in two like Claude, so one Codex matcher becomes an alternation and the reverse cannot recover which was meant. The entry also carried `statusMessage: "Checking the patch before it lands"`, a field outside the hook structure Grok shares with Claude — **dropped**.
- Hooks: `PostToolUse` (command `echo post-tool`, timeout 8) / `shell|local_shell|apply_patch|CascadeEdit|Grep|mcp__.*` → `Bash|Edit|Write|Grep|mcp__.*`. `shell` and `local_shell` both map to `Bash` and were de-duplicated; `apply_patch` expanded to `Edit|Write`; `Grep` is already Grok's name; `mcp__.*` is a pattern carried verbatim. **`CascadeEdit` was dropped** — no vocabulary on either side defines it.
- Env injection: `SERVICE_API_KEY` written as `<REDACTED-REENTER>`. See manual action below.

## Manual action required
- `SERVICE_API_KEY` (`config.toml`, `[shell_environment_policy.set]`): re-enter the value by hand in the target's `[shell_environment_policy.set]`. The value was detected as a secret and is not recorded anywhere in this report.
- Permission rule (`rules/default.rules`): `prefix_rule(pattern=["node", "-e", "console.log(require(\"os\").platform())"], decision="allow")` — a token contains quotes and parentheses, so `Bash(...)` would truncate at the first `)`.
- Permission rule (`rules/default.rules`): `prefix_rule(pattern=["/bin/zsh", "-lc", "git status --short"], decision="allow")` — a token contains whitespace.
- Permission rule (`rules/default.rules`): `prefix_rule(pattern=["bash", "/Users/dev/workspace/monorepo/packages/internal-tooling/scripts/release/pipelines/nightly/steps/verify-and-publish-every-package-with-provenance-and-signed-changelog-attestation-LONGRULE-TAILMARKER-9f2c.sh"], decision="allow")` — the joined form is 216 characters, past the ~200 limit.
- Hook `SessionStart` command references the source tool's home: `/Users/dev/.codex/hooks/notify.sh session-start`. Migrated unchanged and working, but `~/.grok` now depends on `~/.codex` staying installed. The path was not rewritten.

**3 of 7 permission rules could not be expressed as Grok permissions.** The 4 that converted produced 5 entries.

## Not migrated
- **MCP servers: 0 found** in `config.toml`. MCP is out of scope for this tool regardless — a definition carries its credential inline, and a redacted server arrives registered and broken. There were none here.
- `model = "gpt-5.6-sol"` (`config.toml`): model names differ per tool. The target's existing `model = "grok-5-code"` was left untouched.
- `keybindings.json`: `[{ "command": "realtimeVoice", "key": "Alt+V" }]` — command systems differ.
- `[projects."/tmp/some-project"]` `trust_level = "trusted"` (`config.toml`): no Grok equivalent.
- `auth.json` (91 bytes): never read. Absent from the ledger for the same reason.
- `AGENTS.md` (`AGENTS.md`): ignored because `AGENTS.override.md` exists. Contents neither migrated nor quoted.
- `[shell_environment_policy].inherit = "core"` (`config.toml`): inheritance policy, not value injection. The target already had its own `inherit = "core"`, which was left alone.

## Suggestion (nothing was written)
- Approval/sandbox: source `approval_policy = "never"` and `sandbox_mode = "danger-full-access"` correspond to Grok `[ui] permission_mode = "bypassPermissions"`. **Not applied** — no `[ui]` table was created.

## Verification
- TOML parse of `config.toml` after writing — valid. Edits were line-level: three keys appended inside `[shell_environment_policy.set]`, the `allow` array line rewritten, `ask` and `deny` added. Comments and key order elsewhere untouched.
- `jq -e . hooks/migrated.json` — valid, top-level `{"hooks": {...}}`.
- `grep -rF '<REDACTED-REENTER>'` — 1 placeholder, matching the 1 secret-bearing key found in the source.
- Secret-shape scan (`sk-`, `ghp_`, `xoxb-`, `AKIA`) over the target — no match.
- `grep -rF 'OVERRIDDEN-DECOY'` excluding `.migrate/` — no match.
- No trace of `auth.json` in the target.
- Backup holds both files listed in `changes.json` `modified`.
