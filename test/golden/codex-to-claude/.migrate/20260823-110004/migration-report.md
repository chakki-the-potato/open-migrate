# Migration Report: codex → claude (20260823-110004)

Source root: `<REPO>/test/fixtures/codex-home` (test mode — not the real `~/.codex`)
Target root: `<TARGET>` (test mode — not the real `~/.claude`)
Scope: home. Confirm: approved in full, nothing excluded.

## Scan summary
| Category | Found | Automatic | Approximate | Suggestion | Skipped | Excluded | Impossible |
|---|---|---|---|---|---|---|---|
| Global rules | 2 | 1 | 0 | 0 | 0 | 0 | 1 |
| Skills | 1 | 1 | 0 | 0 | 0 | 0 | 0 |
| Commands/prompts | 1 | 1 | 0 | 0 | 0 | 0 | 0 |
| Subagents | 1 | 1 | 0 | 0 | 0 | 0 | 0 |
| Hooks | 5 | 3 | 2 | 0 | 0 | 0 | 0 |
| Permission rules | 7 | 4 | 0 | 0 | 0 | 0 | 3 |
| Env injection | 4 | 2 | 1 | 0 | 0 | 0 | 1 |
| Approval/sandbox policy | 1 | 0 | 0 | 1 | 0 | 0 | 0 |
| Non-migratable items | 4 | 0 | 0 | 0 | 0 | 0 | 4 |

## Migrated (automatic)
- Global rules: `AGENTS.override.md` → `CLAUDE.md` (appended `## Migrated from codex (2026-08-23)` → `### AGENTS.override.md`, body verbatim, `@~/.agent-rules-fixture.md` carried over unexpanded)
- Skills: `skills/hello/` (SKILL.md + reference/tone.md) → `skills/hello/`
- Commands/prompts: `prompts/greet.md` → `commands/greet.md` (`$ARGUMENTS` kept verbatim; Claude supports substitution, so nothing was lost)
- Subagents: `agents/reviewer.toml` → `agents/reviewer.md` (frontmatter `name: reviewer`, `description`; body from `developer_instructions`)
- Hooks: PreToolUse `read_file` → `settings.json` hooks.PreToolUse matcher `Read`
- Hooks: `Notification` → `settings.json` hooks.Notification. It is unofficial in Codex and official in Claude, so it migrates rather than being dropped.
- Hooks: `SessionStart` → `settings.json` hooks.SessionStart
- Permission rules: `prefix_rule(pattern=["git","status"], decision="allow")` → `permissions.allow` `Bash(git status:*)`
- Permission rules: `prefix_rule(pattern=["git","push"], decision="prompt")` → `permissions.ask` `Bash(git push:*)`
- Permission rules: `prefix_rule(pattern=["npm","run",["build","test"]], decision="allow")` → `permissions.allow` `Bash(npm run build:*)` and `Bash(npm run test:*)` (positional union expanded)
- Permission rules: `prefix_rule(pattern=["rm"], decision="forbidden")` → `permissions.deny` `Bash(rm:*)`
- Env injection: `FIXTURE_FLAG` → `settings.json` env
- Env injection: `TRUSTED_CLIENT_SHA256S` → `settings.json` env, value carried over as-is. It is a 64-character hex value under a key naming the digest algorithm, so security.md's digest exception applies: it is a public identifier, not a credential, and redacting it would break the setting for no gain.

## Approximated (review recommended)
- Hook PreToolUse `apply_patch`: matcher converted to `Edit|Write` (Claude splits Codex's single edit tool). The entry also carried `statusMessage = "Checking the patch before it lands"`, which is outside Claude's hook structure — the field was dropped. The hook itself runs unchanged.
- Hook PostToolUse matcher `shell|local_shell|apply_patch|CascadeEdit|Grep|mcp__.*` → `Bash|Edit|Write|Grep|mcp__.*`. `shell` and `local_shell` both map to `Bash` and were de-duplicated; `apply_patch` expanded to `Edit|Write`; `Grep` passed through unchanged; `mcp__.*` carried over verbatim. **`CascadeEdit` was dropped** — it belongs to no vocabulary in this migration and guessing a mapping would silently rescope the hook. The hook now fires on one fewer tool than it did in Codex.
- Env injection `SERVICE_API_KEY`: the key was migrated, the value was not. `settings.json` holds `<REDACTED-REENTER>`; see manual action.

## Manual action required
- `SERVICE_API_KEY` (`config.toml`, `[shell_environment_policy.set]`): re-enter the value by hand at `settings.json` → `env.SERVICE_API_KEY`, which currently holds `<REDACTED-REENTER>`.
- Permission rule (`rules/default.rules`) not expressible as a Claude permission — a token contains quotes and parentheses, so `Bash(...)` would truncate at the first `)` and match nothing. Recreate it by hand if you need it:
  `prefix_rule(pattern=["node", "-e", "console.log(require(\"os\").platform())"], decision="allow")`
- Permission rule (`rules/default.rules`) not expressible — a token contains whitespace (`git status --short`), so joining on spaces no longer describes the same command:
  `prefix_rule(pattern=["/bin/zsh", "-lc", "git status --short"], decision="allow")`
- Permission rule (`rules/default.rules`) not expressible — the joined prefix is 210 characters, past the ~200 limit; a prefix that long is a full command line and can never match anything but itself:
  `prefix_rule(pattern=["bash", "/Users/dev/workspace/monorepo/packages/internal-tooling/scripts/release/pipelines/nightly/steps/verify-and-publish-every-package-with-provenance-and-signed-changelog-attestation-LONGRULE-TAILMARKER-9f2c.sh"], decision="allow")`
- Hook SessionStart (`hooks.json`): the migrated command is `/Users/dev/.codex/hooks/notify.sh session-start`, an absolute path inside the **source** tool's home. The path was not rewritten — where that script can safely live is your call. As it stands, the Claude configuration now depends on the Codex directory, and uninstalling Codex breaks this hook.

3 of 7 permission rules could not be expressed as Claude permissions.

## Not migrated
- Global rules `AGENTS.md` (`AGENTS.md`): `AGENTS.override.md` exists, and Codex ignores `AGENTS.md` entirely when it does. Its contents were never read, so nothing from it was carried over or quoted here. Counted under Global rules, not under Non-migratable items — it is a global rule that could not travel, and burying it in the catch-all category would empty that column of the fact.
- Env injection `inherit` (`config.toml`, `[shell_environment_policy]`): `inherit = "core"` is inheritance policy rather than value injection, and no target has a corresponding concept. Counted under Env injection for the same reason as above.
- Model (`config.toml`): `model = "gpt-5.6-sol"` — not migrated. The target's existing `model` (`claude-fable-5`) was left untouched.
- Approval/sandbox policy (`config.toml`): `approval_policy = "never"`, `sandbox_mode = "danger-full-access"`. Suggestion only, nothing written — see below.
- Project trust (`config.toml`): `[projects."/tmp/some-project"] trust_level = "trusted"` — not migratable, recorded for reference.
- Keybindings (`keybindings.json`): `[{ "command": "realtimeVoice", "key": "Alt+V" }]` — command systems differ between the tools.
- Credentials (`auth.json`): existence confirmed only (91 bytes). Never opened, never hashed, and deliberately absent from the ledger.
- Hook field `statusMessage = "Checking the patch before it lands"` (`hooks.json`, PreToolUse/`apply_patch`): dropped, no place for it in Claude's hook structure.
- Hook matcher alternative `CascadeEdit` (`hooks.json`, PostToolUse): dropped rather than guessed at.
- MCP servers: **0 found** in `config.toml`. MCP is out of scope for this tool regardless — a server definition usually carries its credential inline, and a redacted server would arrive registered and non-functional.
- Plugins / marketplaces: none present in `config.toml`, so no item is plugin-owned.

## Approval/sandbox suggestion (not applied)
Source `approval_policy = "never"` + `sandbox_mode = "danger-full-access"` lines up with Claude's `permissions.defaultMode = "bypassPermissions"` (automation level 3). **Nothing was written.** Set it yourself if you want it — the mapping lines the tools' automation levels up in the same order and does not claim the behaviors are identical.

## Judgment calls worth seeing
- The target already had a PreToolUse hook on `Read` (`echo existing-pre`); the migrated one is `echo pre-read`. They invoke the same binary with different arguments, but they are two unrelated commands rather than one script reached by different notation, so this was treated as an append, not a near-duplicate skip. Both now run on `Read`.

## Verification
- `jq -e . settings.json` — valid JSON after the merge.
- Placeholder present: exactly 1 occurrence of `<REDACTED-REENTER>` in the target. The source held exactly 1 secret-bearing key, so the counts agree.
- Secret-shape scan of the whole target (high-entropy prefix patterns) — no matches. No literal secret was ever placed on a command line.
- Backup: `.migrate/20260823-110004/backup/` holds `settings.json` and `CLAUDE.md`, matching `changes.json` `modified` exactly.
- `changes.json` records 2 modified, 4 created, 5 created directories, with the sha256 of each file as this run left it.
- Existing target content preserved: `CLAUDE.md` still opens with `# Existing / Keep me.`; `settings.json` kept `model`, `env.EXISTING_KEY`, `permissions.allow[Bash(ls:*)]`, and its existing PreToolUse hook.
- Ledger written with the 9 source files actually read. `auth.json` and the ignored `AGENTS.md` are absent because neither was opened.
