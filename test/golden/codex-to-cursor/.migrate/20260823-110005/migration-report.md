# Migration Report: codex → cursor (20260823-110005)

Source root: `<REPO>/test/fixtures/codex-home` (test mode — not the real `~/.codex`)
Target root: `<TARGET>` (test mode — not the real `~/.cursor`)
Scope: home. Confirm: approved in full, nothing excluded.

## Scan summary
| Category | Found | Automatic | Approximate | Suggestion | Skipped | Excluded | Impossible |
|---|---|---|---|---|---|---|---|
| Global rules | 2 | 0 | 0 | 0 | 0 | 0 | 2 |
| Skills | 1 | 1 | 0 | 0 | 0 | 0 | 0 |
| Commands/prompts | 1 | 0 | 1 | 0 | 0 | 0 | 0 |
| Subagents | 1 | 1 | 0 | 0 | 0 | 0 | 0 |
| Hooks | 5 | 1 | 2 | 0 | 0 | 0 | 2 |
| Permission rules | 7 | 3 | 0 | 0 | 0 | 0 | 4 |
| Env injection | 4 | 0 | 0 | 0 | 0 | 0 | 4 |
| Approval/sandbox policy | 1 | 0 | 0 | 1 | 0 | 0 | 0 |
| Non-migratable items | 4 | 0 | 0 | 0 | 0 | 0 | 4 |

## Migrated (automatic)
- Skills: `skills/hello/` (SKILL.md + reference/tone.md) → `skills/hello/`
- Subagents: `agents/reviewer.toml` → `agents/reviewer.md` (`name` from the filename, `description` from the TOML key, body from `developer_instructions`)
- Hooks: `SessionStart` → `hooks.json` `sessionStart`, appended beside the target's existing entry
- Permission rules: `prefix_rule(pattern=["git","status"], decision="allow")` → `cli-config.json` `permissions.allow` `Shell(git status:*)`
- Permission rules: `prefix_rule(pattern=["npm","run",["build","test"]], decision="allow")` → `Shell(npm run build:*)` and `Shell(npm run test:*)` (positional union expanded)
- Permission rules: `prefix_rule(pattern=["rm"], decision="forbidden")` → `permissions.deny` `Shell(rm:*)`

The rules were converted straight from the Starlark DSL to Cursor's token syntax — joined on spaces, `:*` appended, wrapped in `Shell(...)`. They were not routed through Claude's names on the way.

## Approximated (review recommended)
- Hook PreToolUse `apply_patch` → `preToolUse` matcher `Write`. The entry also carried `statusMessage = "Checking the patch before it lands"`, which is not part of Cursor's hook object and was dropped. The hook itself runs unchanged.
- Hook PostToolUse matcher `shell|local_shell|apply_patch|CascadeEdit|Grep|mcp__.*` → `Shell|Write|Grep|mcp__.*`. `shell` and `local_shell` both map to `Shell` and were de-duplicated; `apply_patch` became `Write`; `Grep` is already a Cursor matcher and passed through; `mcp__.*` carried over verbatim. **`CascadeEdit` was dropped** — it belongs to no vocabulary in this migration, and guessing would silently rescope the hook.
- Commands/prompts `prompts/greet.md` → `skills/greet/SKILL.md`. Cursor's command surface is deprecated, so the target doc sends commands to skills. The source command had no `description`, so the body's first sentence was used verbatim rather than invented. And Cursor skills have no `$1`-`$9` / `$ARGUMENTS` substitution — the token survives as literal text, so the skill now says the word `$ARGUMENTS` instead of interpolating an argument. **That is a real loss, not a formatting detail.**

## Manual action required
- Global rules (`AGENTS.override.md`): Cursor has no global rule file. Its equivalent, User Rules, lives in the Cursor account and cannot be written to disk, and no project root was given for this run, so **nothing was written**. Paste this into Cursor's User Rules by hand:

```
# Global Rules

@~/.agent-rules-fixture.md

- Answer in Korean.
- Never commit secrets.
```

- Permission rule `prefix_rule(pattern=["git","push"], decision="prompt")` (`rules/default.rules`): **Cursor has no `ask` tier.** Putting it in `allow` would grant what the source wanted to prompt for, and `deny` would forbid what the source allowed with a prompt — both distort the original. It was left out entirely.
- Permission rule (`rules/default.rules`) not expressible — a token contains quotes and parentheses, so `Shell(...)` would truncate at the first `)` and match nothing:
  `prefix_rule(pattern=["node", "-e", "console.log(require(\"os\").platform())"], decision="allow")`
- Permission rule (`rules/default.rules`) not expressible — a token contains whitespace (`git status --short`), so joining on spaces no longer describes the same command:
  `prefix_rule(pattern=["/bin/zsh", "-lc", "git status --short"], decision="allow")`
- Permission rule (`rules/default.rules`) not expressible — the joined prefix is 210 characters, past the ~200 limit; it could never match anything but itself:
  `prefix_rule(pattern=["bash", "/Users/dev/workspace/monorepo/packages/internal-tooling/scripts/release/pipelines/nightly/steps/verify-and-publish-every-package-with-provenance-and-signed-changelog-attestation-LONGRULE-TAILMARKER-9f2c.sh"], decision="allow")`
- Env injection `FIXTURE_FLAG = "1"` (`config.toml`, `[shell_environment_policy.set]`): Cursor has no global env surface. Move it into a per-server `env` block or your shell profile.
- Env injection `TRUSTED_CLIENT_SHA256S = "02aa45f33f6384022cfc3e1045ad58ac1af9db9b095d259367f3a3fb6aaf33a7"` (`config.toml`, `[shell_environment_policy.set]`): same — no global env surface. The value is quoted here in full **because it is a digest, not a credential**: 64 hexadecimal characters under a key naming the algorithm. Redacting it would leave you to dig the value up again for no gain.
- Env injection `SERVICE_API_KEY` (`config.toml`, `[shell_environment_policy.set]`): same — no global env surface. The value was never written anywhere and is not recorded here; re-enter it by hand wherever you move it.
- Hook SessionStart (`hooks.json`): the migrated command is `/Users/dev/.codex/hooks/notify.sh session-start`, an absolute path inside the **source** tool's home. The path was not rewritten. As it stands, the Cursor configuration now depends on the Codex directory, and uninstalling Codex breaks this hook.

4 of 7 permission rules could not be expressed as Cursor permissions.

## Not migrated
- Global rules `AGENTS.md` (`AGENTS.md`): `AGENTS.override.md` exists, and Codex ignores `AGENTS.md` entirely when it does. Its contents were never read, so nothing from it was carried over or quoted here. Counted under Global rules rather than the catch-all category — it is a global rule that could not travel.
- Hook PreToolUse `read_file` (`hooks.json`): Cursor has no matcher corresponding to Codex's `read_file`, and a matcher that empties out does not match nothing on the target — it would widen the hook. The whole entry was dropped. Command was `echo pre-read`.
- Hook event `Notification` (`hooks.json`): Cursor has no corresponding event. Command was `echo notify`.
- Env injection `inherit` (`config.toml`, `[shell_environment_policy]`): `inherit = "core"` is inheritance policy rather than value injection, and Cursor has no env surface at all. Counted under Env injection.
- Model (`config.toml`): `model = "gpt-5.6-sol"` — not migrated.
- Approval/sandbox policy (`config.toml`): `approval_policy = "never"`, `sandbox_mode = "danger-full-access"`. Suggestion only, nothing written — see below. The target's existing `approvalMode` (`allowlist`) was left untouched.
- Project trust (`config.toml`): `[projects."/tmp/some-project"] trust_level = "trusted"` — not migratable, recorded for reference.
- Keybindings (`keybindings.json`): `[{ "command": "realtimeVoice", "key": "Alt+V" }]` — command systems differ between the tools.
- Credentials (`auth.json`): existence confirmed only (91 bytes). Never opened, never hashed, and deliberately absent from the ledger.
- MCP servers: **0 found** in `config.toml`. MCP is out of scope for this tool regardless.
- Plugins / marketplaces: none present in `config.toml`, so no item is plugin-owned.

## Possible duplication (Cursor reads some of this natively)
Cursor loads parts of other tools' configuration without conversion — `~/.codex/skills/` and `~/.codex/agents/` among them. Those paths can be switched off in settings, so the safe move under a blanket approval is to migrate rather than skip. **The consequence is that the skill and the subagent may now be visible to Cursor twice.** Nothing was deleted from the source. If Cursor was already reading the Codex home, remove one copy.

## Approval/sandbox suggestion (not applied)
Source `approval_policy = "never"` + `sandbox_mode = "danger-full-access"` lines up with Cursor's `approvalMode = "unrestricted"` (automation level 3). **Nothing was written**, and `approvalMode` is never changed automatically even when it already holds a value. Cursor's modes differ from the others in whether a classifier is involved, and that correspondence has never been confirmed by research — treat this as a starting point, not a translation.

## Verification
- `jq -e . hooks.json` and `jq -e . cli-config.json` — both valid after the merge.
- Placeholder count: **0**, and that is correct here. Cursor has no env surface, so nothing was written for the one secret-bearing source key; it appears by name only under manual action.
- Secret-shape scan of the whole target (high-entropy prefix patterns) — no matches.
- `skills-cursor/canvas/SKILL.md` still reads `APP-MANAGED-DECOY-UNTOUCHED`. That directory is app-managed and was never a write destination.
- Backup: `.migrate/20260823-110005/backup/` holds `hooks.json` and `cli-config.json`, matching `changes.json` `modified` exactly.
- Existing target content preserved: the `sessionStart` entry `echo existing-session`, `approvalMode`, and `Shell(ls)` in `permissions.allow` all survived.
- Ledger written with the 9 source files actually read. `auth.json` and the ignored `AGENTS.md` are absent because neither was opened.
