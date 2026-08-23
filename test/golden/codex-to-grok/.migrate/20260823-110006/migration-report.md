# Migration Report: codex → grok (20260823-110006)

Source root: `<REPO>/test/fixtures/codex-home` (test mode — not the real `~/.codex`)
Target root: `<TARGET>` (test mode — not the real `~/.grok`)
Scope: home. Confirm: approved in full, nothing excluded.

## Scan summary
| Category | Found | Automatic | Approximate | Suggestion | Skipped | Excluded | Impossible |
|---|---|---|---|---|---|---|---|
| Global rules | 2 | 1 | 0 | 0 | 0 | 0 | 1 |
| Skills | 1 | 1 | 0 | 0 | 0 | 0 | 0 |
| Commands/prompts | 1 | 0 | 1 | 0 | 0 | 0 | 0 |
| Subagents | 1 | 1 | 0 | 0 | 0 | 0 | 0 |
| Hooks | 5 | 3 | 2 | 0 | 0 | 0 | 0 |
| Permission rules | 7 | 4 | 0 | 0 | 0 | 0 | 3 |
| Env injection | 4 | 2 | 1 | 0 | 0 | 0 | 1 |
| Approval/sandbox policy | 1 | 0 | 0 | 1 | 0 | 0 | 0 |
| Non-migratable items | 4 | 0 | 0 | 0 | 0 | 0 | 4 |

## Migrated (automatic)
- Global rules: `AGENTS.override.md` → `AGENTS.md` (appended `## Migrated from codex (2026-08-23)` → `### AGENTS.override.md`, body verbatim, `@~/.agent-rules-fixture.md` carried over unexpanded). Written to `AGENTS.md` rather than `rules/`: every `rules/*.md` is loaded anyway, so a single file is easier to trace with identical effect.
- Skills: `skills/hello/` (SKILL.md + reference/tone.md) → `skills/hello/`
- Subagents: `agents/reviewer.toml` → `agents/reviewer.md` (`name` from the filename, `description` from the TOML key, body from `developer_instructions`; camelCase frontmatter, though this source had no multi-word keys to convert)
- Hooks: PreToolUse `read_file` → `hooks/migrated.json` PreToolUse matcher `Read`
- Hooks: `Notification` → `hooks/migrated.json`. It is one of Grok's 15 events, so unlike a migration to Codex or Cursor this one survives.
- Hooks: `SessionStart` → `hooks/migrated.json`
- Permission rules: `prefix_rule(pattern=["git","status"], decision="allow")` → `config.toml` `[permission] allow` `Bash(git status:*)`
- Permission rules: `prefix_rule(pattern=["git","push"], decision="prompt")` → `[permission] ask` `Bash(git push:*)`. **Grok has an `ask` tier**, so this rule survives here where it would be lost going to Cursor.
- Permission rules: `prefix_rule(pattern=["npm","run",["build","test"]], decision="allow")` → `Bash(npm run build:*)` and `Bash(npm run test:*)` (positional union expanded)
- Permission rules: `prefix_rule(pattern=["rm"], decision="forbidden")` → `[permission] deny` `Bash(rm:*)`
- Env injection: `FIXTURE_FLAG` → `config.toml` `[shell_environment_policy.set]`
- Env injection: `TRUSTED_CLIENT_SHA256S` → `config.toml` `[shell_environment_policy.set]`, value carried over as-is. It is a 64-character hex value under a key naming the digest algorithm, so security.md's digest exception applies: it is a public identifier, not a credential, and redacting it would break the setting for no gain.

Grok's env table has the same name and structure as Codex's, so the values moved without conversion.

## Approximated (review recommended)
- Hook PreToolUse `apply_patch`: matcher converted to `Edit|Write` (Grok uses Claude's tool names, which split Codex's single edit tool). The entry also carried `statusMessage = "Checking the patch before it lands"`, which is outside the hook structure Grok shares with Claude — the field was dropped. The hook itself runs unchanged.
- Hook PostToolUse matcher `shell|local_shell|apply_patch|CascadeEdit|Grep|mcp__.*` → `Bash|Edit|Write|Grep|mcp__.*`. `shell` and `local_shell` both map to `Bash` and were de-duplicated; `apply_patch` expanded to `Edit|Write`; `Grep` passed through unchanged; `mcp__.*` carried over verbatim. **`CascadeEdit` was dropped** — it belongs to no vocabulary in this migration, and guessing would silently rescope the hook.
- Commands/prompts `prompts/greet.md` → `skills/greet/SKILL.md`. Grok has no command surface, so the target doc converts commands into skills. The source command had no `description`, so the body's first sentence was used verbatim rather than invented — **the description is synthesized, and that is worth a look.** `user-invocable: true` was added so it stays reachable as a slash command, which is what it was in Codex. The `$ARGUMENTS` token was left exactly as it stands, per the target doc; whether Grok skills interpolate it is not documented in this repository, so verify before relying on it.
- Env injection `SERVICE_API_KEY`: the key was migrated, the value was not. `config.toml` holds `<REDACTED-REENTER>`; see manual action.

## Manual action required
- `SERVICE_API_KEY` (`config.toml`, `[shell_environment_policy.set]`): re-enter the value by hand at the target's `config.toml` → `[shell_environment_policy.set]`, which currently holds `<REDACTED-REENTER>`.
- Permission rule (`rules/default.rules`) not expressible as a Grok permission — a token contains quotes and parentheses, so `Bash(...)` would truncate at the first `)` and match nothing:
  `prefix_rule(pattern=["node", "-e", "console.log(require(\"os\").platform())"], decision="allow")`
- Permission rule (`rules/default.rules`) not expressible — a token contains whitespace (`git status --short`), so joining on spaces no longer describes the same command:
  `prefix_rule(pattern=["/bin/zsh", "-lc", "git status --short"], decision="allow")`
- Permission rule (`rules/default.rules`) not expressible — the joined prefix is 210 characters, past the ~200 limit; it could never match anything but itself:
  `prefix_rule(pattern=["bash", "/Users/dev/workspace/monorepo/packages/internal-tooling/scripts/release/pipelines/nightly/steps/verify-and-publish-every-package-with-provenance-and-signed-changelog-attestation-LONGRULE-TAILMARKER-9f2c.sh"], decision="allow")`
- Hook SessionStart (`hooks.json`): the migrated command is `/Users/dev/.codex/hooks/notify.sh session-start`, an absolute path inside the **source** tool's home. The path was not rewritten. As it stands, the Grok configuration now depends on the Codex directory, and uninstalling Codex breaks this hook.

3 of 7 permission rules could not be expressed as Grok permissions.

## Not migrated
- Global rules `AGENTS.md` (`AGENTS.md`): `AGENTS.override.md` exists, and Codex ignores `AGENTS.md` entirely when it does. Its contents were never read, so nothing from it was carried over or quoted here. Counted under Global rules rather than the catch-all category — it is a global rule that could not travel.
- Env injection `inherit` (`config.toml`, `[shell_environment_policy]`): `inherit = "core"` is inheritance policy rather than value injection. Grok reuses the table name, but those are policy fields there too, so there is nothing to migrate into. The target's own `inherit = "core"` was left untouched. Counted under Env injection.
- Model (`config.toml`): `model = "gpt-5.6-sol"` — not migrated. The target's existing `model` (`grok-5-code`) was left untouched.
- Approval/sandbox policy (`config.toml`): `approval_policy = "never"`, `sandbox_mode = "danger-full-access"`. Suggestion only, nothing written — see below.
- Project trust (`config.toml`): `[projects."/tmp/some-project"] trust_level = "trusted"` — not migratable, recorded for reference.
- Keybindings (`keybindings.json`): `[{ "command": "realtimeVoice", "key": "Alt+V" }]` — command systems differ between the tools.
- Credentials (`auth.json`): existence confirmed only (91 bytes). Never opened, never hashed, and deliberately absent from the ledger.
- MCP servers: **0 found** in `config.toml`. MCP is out of scope for this tool regardless.
- Plugins / marketplaces: none present in `config.toml`, so no item is plugin-owned.

## Approval/sandbox suggestion (not applied)
Source `approval_policy = "never"` + `sandbox_mode = "danger-full-access"` lines up with Grok's `[ui] permission_mode = "bypassPermissions"` (automation level 3; Grok's product name for it is always-approve). **Nothing was written.** Grok's `permission_mode` also accepts `auto`, `dontAsk`, and `plan`, which have no row in the mapping table — that is why this stays a suggestion.

## Verification
- `python3 -c "import tomllib…"` — `config.toml` parses after the merge. The file was edited line by line rather than re-serialized, so key order and spacing survived.
- `jq -e . hooks/migrated.json` — valid JSON, top-level key is `hooks`.
- Placeholder present: exactly 1 occurrence of `<REDACTED-REENTER>` in the target. The source held exactly 1 secret-bearing key, so the counts agree.
- Secret-shape scan of the whole target (high-entropy prefix patterns) — no matches. The digest under `TRUSTED_CLIENT_SHA256S` is present by design and is not a credential.
- Backup: `.migrate/20260823-110006/backup/` holds `AGENTS.md` and `config.toml`, matching `changes.json` `modified` exactly.
- Existing target content preserved: `AGENTS.md` still opens with `# Existing / Keep me.`; `config.toml` kept `model`, `[shell_environment_policy] inherit`, `EXISTING_KEY`, and `Bash(ls:*)` at the head of `[permission] allow`.
- Ledger written with the 9 source files actually read. `auth.json` and the ignored `AGENTS.md` are absent because neither was opened.
