# Migration Report: codex → grok (20260823-132223)

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
| Approval/sandbox policy | 2 | 0 | 0 | 2 | 0 | 0 | 0 |
| Non-migratable items | 4 | 0 | 0 | 0 | 0 | 0 | 4 |

## Migrated (automatic)
- Global rules: AGENTS.override.md → AGENTS.md (`## Migrated from codex (2026-08-23)` section, verbatim, `@~/.agent-rules-fixture.md` import kept unexpanded). Written to AGENTS.md rather than `rules/`, per grok.md
- Skills: hello → skills/hello/ (SKILL.md and reference/tone.md)
- Subagents: agents/reviewer.toml → agents/reviewer.md (`description` became the frontmatter `description`, `developer_instructions` became the body, and the filename supplied `name`; no source key needed camelCasing)
- Hooks: PreToolUse `read_file` → hooks/migrated.json PreToolUse matcher `Read`. Grok uses Claude's tool names, so only the Codex-side name needed mapping
- Hooks: Notification → hooks/migrated.json, unchanged. `Notification` is unofficial in Codex but is one of Grok's 15 events, so it migrates rather than being dropped
- Hooks: SessionStart → hooks/migrated.json, unchanged
- Env injection: FIXTURE_FLAG → `[shell_environment_policy.set]` in config.toml
- Env injection: TRUSTED_CLIENT_SHA256S → `[shell_environment_policy.set]`, value carried over as-is. It is 64 hexadecimal characters and its key names the algorithm, so it is a digest rather than a credential. Redacting it would have broken a working setting for no gain — recorded here so the judgment is visible
- Permission rules: `prefix_rule(pattern=["git", "status"], decision="allow")` → `Bash(git status:*)` in `[permission] allow`
- Permission rules: `prefix_rule(pattern=["npm", "run", ["build", "test"]], decision="allow")` → `Bash(npm run build:*)` and `Bash(npm run test:*)`, the positional union expanded into both combinations
- Permission rules: `prefix_rule(pattern=["git", "push"], decision="prompt")` → `Bash(git push:*)` in `[permission] ask`. Grok has an `ask` tier, so nothing was lost
- Permission rules: `prefix_rule(pattern=["rm"], decision="forbidden")` → `Bash(rm:*)` in `[permission] deny`

## Approximated (review recommended)
- Commands/prompts prompts/greet.md → skills/greet/SKILL.md: Grok has no command surface, so the prompt became a skill with `user-invocable: true` so it stays reachable as a slash command. The source had no `description`, so the body's first sentence was used verbatim rather than invented. The `$ARGUMENTS` token was left exactly as it is.
- Hooks PreToolUse `apply_patch` → matcher `Edit|Write`: Grok splits Codex's single edit tool into two, so the matcher was expanded to a regex alternation covering both. The hook entry also carried a `statusMessage` field with the value `Checking the patch before it lands`, which has no equivalent in Grok's hook structure and was dropped. The value is quoted here so nothing is silently lost.
- Hooks PostToolUse `shell|local_shell|apply_patch|CascadeEdit|Grep|mcp__.*` → `Bash|Edit|Write|Grep|mcp__.*`: `shell` and `local_shell` both became `Bash` and were de-duplicated to one; `apply_patch` expanded to `Edit|Write`; `Grep` is already Grok's own name and passed through; `mcp__.*` is a regex rather than a tool name and was carried verbatim, since MCP tool names are identical on every target. **`CascadeEdit` was dropped** — it belongs to neither tool's vocabulary, and guessing a mapping would silently scope the hook to the wrong tool.
- Env injection SERVICE_API_KEY (config.toml `[shell_environment_policy.set]`): the key was written to the target's `[shell_environment_policy.set]`, but its value is a detected secret, so it was replaced with `<REDACTED-REENTER>`. The key arrives; the value does not.

## Manual action required
- SERVICE_API_KEY (config.toml `[shell_environment_policy.set]` on both sides): re-enter the value by hand. It is present in the target as `<REDACTED-REENTER>`.
- Permission rules: **3 of 7 rules could not be expressed as target permissions.** The three are listed individually below with the reason each one failed. An argv-prefix rule is a list of exact literals, while a Grok permission string is a pattern with its own syntax, so a rule survives only when joining its tokens with spaces produces something Grok can actually match.
- Permission rule (rules/default.rules): `prefix_rule(pattern=["node", "-e", "console.log(require(\"os\").platform())"], decision="allow")` — a token contains quotes and parentheses. `Bash(...)` ends at the first `)`, so converting it would produce a truncated pattern that matches nothing.
- Permission rule (rules/default.rules): `prefix_rule(pattern=["/bin/zsh", "-lc", "git status --short"], decision="allow")` — a token contains whitespace. Joining on spaces makes the boundary between tokens indistinguishable from the space inside one.
- Permission rule (rules/default.rules): `prefix_rule(pattern=["bash", "/Users/dev/workspace/monorepo/packages/internal-tooling/scripts/release/pipelines/nightly/steps/verify-and-publish-every-package-with-provenance-and-signed-changelog-attestation-LONGRULE-TAILMARKER-9f2c.sh"], decision="allow")` — the joined string is 210 characters, past the ~200 limit. A prefix that long is a full command line and will never match anything but itself.
- Hook command dependency: the migrated SessionStart hook runs `/Users/dev/.codex/hooks/notify.sh session-start`, which lives inside the Codex home. Grok's hook file now depends on the Codex installation — uninstall Codex and this hook breaks. The path was left exactly as it was, because whether that script is safe to relocate is not something this tool can know.
- Approval policy: source `approval_policy` = `never`, suggested Grok equivalent `[ui] permission_mode` = `bypassPermissions` (procedure.md level 3). Nothing was written.
- Sandbox policy: source `sandbox_mode` = `danger-full-access`, which sits on the same level-3 row. Grok's `[sandbox] profile` is OS-level isolation whose meaning differs per tool, so no value is suggested for it. Nothing was written.
- Project trust: `[projects."/tmp/some-project"]` with `trust_level = "trusted"` in config.toml. Trust is a Codex concept and a security decision; recreate it yourself if the equivalent matters to you.

## Not migrated
- Global rules AGENTS.md: `AGENTS.override.md` exists, and Codex reads only the override when it does. AGENTS.md is therefore configuration the source tool was already ignoring. Its contents were never opened, never merged, and are not quoted here, so it is also absent from the ledger.
- Env injection `inherit = "core"` (config.toml `[shell_environment_policy]`): inheritance policy rather than value injection. Grok reuses Codex's table name, but `inherit` is a policy field there too, so there is no target concept to migrate it into. The target's own `[shell_environment_policy] inherit` was left untouched at its existing value `core`. Counted under Env injection rather than as a homeless item, because that is the category it belongs to.
- Keybindings (keybindings.json): command systems differ between the two tools, so there is nothing to convert. Existence noted only.
- Credentials (auth.json): existence confirmed only, per security.md. Never opened, so it is absent from the ledger.
- Model (config.toml `model`): current value `gpt-5.6-sol`. Not migrated — the target's `model` is `grok-5-code` and an OpenAI model name has no meaning there.
- Project trust (config.toml `[projects."/tmp/some-project"]`): `trust_level = "trusted"`. Not migratable; see the manual-action list.
- MCP servers: none found in config.toml. MCP is out of scope for this tool regardless — a definition usually carries its credential inline, and a redacted server would arrive registered and non-functional.
- Plugins and marketplaces: none found in config.toml, so no skill, subagent, or hook in this run is plugin-owned.

## Verification
- `python3 -c "import tomllib..." config.toml` — parses after the edit.
- `jq -e . hooks/migrated.json` — ok.
- `grep -rF '<REDACTED-REENTER>'` outside .migrate/ — 1 hit. The source had exactly 1 secret-bearing key, so the counts match. TRUSTED_CLIENT_SHA256S is deliberately not among them.
- `grep -rE 'sk-[A-Za-z0-9_-]{16,}'` outside .migrate/ — 0 hits. No secret shape reached the target.
- `grep -rl 'OVERRIDDEN-DECOY'` over the whole target — 0 files. Nothing from the ignored AGENTS.md reached the target.
- Pre-existing target content survived: `EXISTING_KEY = "keep"` still in `[shell_environment_policy.set]`, `Bash(ls:*)` still first in `[permission] allow`, `inherit = "core"` untouched, `# Existing` / `Keep me.` still at the top of AGENTS.md.
- config.toml was edited line by line rather than reparsed and rewritten, so key order and the existing table layout are unchanged.
- backup/ holds AGENTS.md and config.toml — exactly the two files in `changes.json`'s `modified`.
