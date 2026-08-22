# Migration Report: codex → claude (20260822-174841)

Source root: `test/fixtures/codex-home` (test mode)
Target root: `test/tmp/golden-run/codex-to-claude` (test mode)

## Scan summary
| Category | Found | Automatic | Approximate | Suggestion | Skipped | Impossible |
|---|---|---|---|---|---|---|
| Global rules | 1 | 1 | 0 | 0 | 0 | 0 |
| Skills | 1 | 1 | 0 | 0 | 0 | 0 |
| Commands / prompts | 1 | 1 | 0 | 0 | 0 | 0 |
| Subagents | 1 | 1 | 0 | 0 | 0 | 0 |
| Hooks | 5 | 3 | 2 | 0 | 0 | 0 |
| Permission rules | 7 | 4 | 0 | 0 | 0 | 3 |
| Env injection | 3 | 2 | 1 | 0 | 0 | 0 |
| Approval/sandbox policy | 1 | 0 | 0 | 1 | 0 | 0 |
| Non-migratable items | 6 | 0 | 0 | 0 | 0 | 6 |

## Migrated (automatic)
- Global rules: `AGENTS.override.md` → `CLAUDE.md` under `## Migrated from codex (2026-08-22)` / `### AGENTS.override.md`. The `@~/.agent-rules-fixture.md` import line was carried over verbatim and not expanded.
- Skills: `skills/hello/` → `skills/hello/` (SKILL.md and reference/tone.md).
- Commands: `prompts/greet.md` → `commands/greet.md`. The `$ARGUMENTS` token is kept verbatim; Claude supports substitution, so nothing was lost.
- Subagents: `agents/reviewer.toml` → `agents/reviewer.md` (frontmatter `name`/`description`, `developer_instructions` as the body).
- Hooks: `PreToolUse` / `read_file` → matcher `Read`.
- Hooks: `Notification` → migrated unchanged. The event is unofficial in Codex but is a real Claude event, so it becomes live config on the target rather than the dead entry it was.
- Hooks: `SessionStart` → migrated unchanged.
- Permissions: `["git","status"]` allow → `Bash(git status:*)` (allow).
- Permissions: `["git","push"]` prompt → `Bash(git push:*)` (ask).
- Permissions: `["npm","run",["build","test"]]` allow → `Bash(npm run build:*)` and `Bash(npm run test:*)` (allow) — the positional union expands to one entry per combination.
- Permissions: `["rm"]` forbidden → `Bash(rm:*)` (deny).
- Env injection: `FIXTURE_FLAG` → `env.FIXTURE_FLAG`.
- Env injection: `TRUSTED_CLIENT_SHA256S` → `env.TRUSTED_CLIENT_SHA256S`, **carried verbatim rather than redacted.** The value is 64 hex characters and the key names the algorithm, so it is a digest — a public identifier, not a credential. Redacting it would have broken a working setting the user then has to reconstruct.

## Approximated (review recommended)
- Hooks: `PreToolUse` / `apply_patch` → matcher `Edit|Write`. Claude splits the edit tool in two, so one Codex matcher becomes an alternation; the reverse direction cannot recover which of the two was meant. The entry also carried `statusMessage: "Checking the patch before it lands"`, a field outside Claude's hook structure — **dropped**, because an unrecognized key risks a `settings.json` the tool rejects.
- Hooks: `PostToolUse` (command `echo post-tool`, timeout 8) / `shell|local_shell|apply_patch|CascadeEdit|Grep|mcp__.*` → `Bash|Edit|Write|Grep|mcp__.*`. `shell` and `local_shell` both map to `Bash` and were de-duplicated; `apply_patch` expanded to `Edit|Write`; `Grep` is already Claude's own name and passed through; `mcp__.*` is a pattern, not a tool name, and was carried verbatim. **`CascadeEdit` was dropped** — it belongs to no vocabulary on either side, and guessing a mapping would silently scope the hook to the wrong tool.
- Env injection: `SERVICE_API_KEY` written as `<REDACTED-REENTER>`. See manual action below.

## Manual action required
- `SERVICE_API_KEY` (`config.toml`, `[shell_environment_policy.set]`): re-enter the value by hand in `settings.json` → `env.SERVICE_API_KEY`. The value was detected as a secret and is not recorded anywhere in this report.
- Permission rule (`rules/default.rules`): `prefix_rule(pattern=["node", "-e", "console.log(require(\"os\").platform())"], decision="allow")` — a token contains quotes and parentheses. `Bash(...)` ends at the first `)`, so converting it would produce a truncated pattern that matches nothing. Reproduced here verbatim instead.
- Permission rule (`rules/default.rules`): `prefix_rule(pattern=["/bin/zsh", "-lc", "git status --short"], decision="allow")` — a token contains whitespace, so joining on spaces no longer describes the same command.
- Permission rule (`rules/default.rules`): `prefix_rule(pattern=["bash", "/Users/dev/workspace/monorepo/packages/internal-tooling/scripts/release/pipelines/nightly/steps/verify-and-publish-every-package-with-provenance-and-signed-changelog-attestation-LONGRULE-TAILMARKER-9f2c.sh"], decision="allow")` — the joined form is 216 characters, past the ~200 limit. A prefix that long matches nothing but itself.
- Hook `SessionStart` command references the source tool's home: `/Users/dev/.codex/hooks/notify.sh session-start`. The hook was migrated unchanged and works today, but `~/.claude` now depends on `~/.codex` staying installed. The path was not rewritten — whether the script is safe to relocate is your call.

**3 of 7 permission rules could not be expressed as Claude permissions.** The 4 that converted produced 5 entries (one rule expands to two).

## Not migrated
- **MCP servers: 0 found** in `config.toml`. MCP is out of scope for this tool regardless — a definition carries its credential inline, and a redacted server arrives registered and broken. There were none here.
- `model = "gpt-5.6-sol"` (`config.toml`): model names differ per tool. The target's existing `model` value was left untouched.
- `keybindings.json`: `[{ "command": "realtimeVoice", "key": "Alt+V" }]` — command systems differ, no equivalent surface.
- `[projects."/tmp/some-project"]` `trust_level = "trusted"` (`config.toml`): Codex project trust has no Claude equivalent.
- `auth.json` (91 bytes): never read. security.md forbids opening credential files, hashing included, so it is absent from the ledger too.
- `AGENTS.md` (`AGENTS.md`): ignored because `AGENTS.override.md` exists. Codex reads only the override, so `AGENTS.md` is dead config on the source; its contents were neither migrated nor quoted.
- `[shell_environment_policy].inherit = "core"` (`config.toml`): inheritance policy, not value injection. No target has a corresponding concept.

## Suggestion (nothing was written)
- Approval/sandbox: source `approval_policy = "never"` and `sandbox_mode = "danger-full-access"` correspond to Claude `permissions.defaultMode = "bypassPermissions"`. **Not applied** — automation level is never set automatically. Set it yourself if that is what you want.

## Verification
- `jq -e . settings.json` — valid.
- `grep -rF '<REDACTED-REENTER>' <target>` — 1 placeholder present, matching the 1 secret-bearing key found in the source.
- Secret-shape scan (`sk-`, `ghp_`, `xoxb-`, `AKIA`) over the target — no match.
- `grep -rF 'OVERRIDDEN-DECOY'` over the target excluding `.migrate/` — no match, so the ignored `AGENTS.md` did not leak through.
- No trace of `auth.json` in the target.
- Backup holds both files listed in `changes.json` `modified`.
