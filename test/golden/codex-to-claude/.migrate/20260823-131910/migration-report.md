# Migration Report: codex → claude (20260823-131910)

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
| Approval/sandbox policy | 2 | 0 | 0 | 2 | 0 | 0 | 0 |
| Non-migratable items | 4 | 0 | 0 | 0 | 0 | 0 | 4 |

## Migrated (automatic)
- Global rules: AGENTS.override.md → CLAUDE.md (`## Migrated from codex (2026-08-23)` section, verbatim, `@~/.agent-rules-fixture.md` import kept unexpanded)
- Skills: hello → skills/hello/ (SKILL.md and reference/tone.md)
- Commands/prompts: prompts/greet.md → commands/greet.md. `$ARGUMENTS` is supported on both sides and was kept verbatim, so nothing was lost
- Subagents: agents/reviewer.toml → agents/reviewer.md (`description` became the frontmatter `description`, `developer_instructions` became the body, and the filename supplied `name`)
- Hooks: PreToolUse `read_file` → settings.json PreToolUse matcher `Read`
- Hooks: Notification → settings.json Notification, unchanged. `Notification` is unofficial in Codex but is a real Claude event, so it migrates rather than being dropped
- Hooks: SessionStart → settings.json SessionStart, unchanged
- Env injection: FIXTURE_FLAG → settings.json `env`
- Env injection: TRUSTED_CLIENT_SHA256S → settings.json `env`, value carried over as-is. It is 64 hexadecimal characters and its key names the algorithm, so it is a digest rather than a credential. Redacting it would have broken a working setting for no gain — recorded here so the judgment is visible
- Permission rules: `prefix_rule(pattern=["git", "status"], decision="allow")` → `Bash(git status:*)` in `permissions.allow`
- Permission rules: `prefix_rule(pattern=["npm", "run", ["build", "test"]], decision="allow")` → `Bash(npm run build:*)` and `Bash(npm run test:*)`, the positional union expanded into both combinations
- Permission rules: `prefix_rule(pattern=["git", "push"], decision="prompt")` → `Bash(git push:*)` in `permissions.ask`
- Permission rules: `prefix_rule(pattern=["rm"], decision="forbidden")` → `Bash(rm:*)` in `permissions.deny`

## Approximated (review recommended)
- Hooks PreToolUse `apply_patch` → matcher `Edit|Write`: Claude splits Codex's single edit tool into two, so the matcher was expanded to a regex alternation covering both. The hook entry also carried a `statusMessage` field with the value `Checking the patch before it lands`. Claude's hook structure has no such field, so it was dropped — carrying an unrecognized key into settings.json risks a config the tool rejects. The value is quoted here so nothing is silently lost.
- Hooks PostToolUse `shell|local_shell|apply_patch|CascadeEdit|Grep|mcp__.*` → `Bash|Edit|Write|Grep|mcp__.*`: `shell` and `local_shell` both became `Bash` and were de-duplicated to one; `apply_patch` expanded to `Edit|Write`; `Grep` is already Claude's own name and passed through; `mcp__.*` is a regex rather than a tool name and was carried verbatim, since MCP tool names are identical on every target. **`CascadeEdit` was dropped** — it is not a Codex tool name and not a Claude one, and guessing a mapping would silently scope the hook to the wrong tool.
- Env injection SERVICE_API_KEY (config.toml `[shell_environment_policy.set]`): the key was written to settings.json `env`, but its value is a detected secret, so it was replaced with `<REDACTED-REENTER>`. The key arrives; the value does not.

## Manual action required
- SERVICE_API_KEY (config.toml `[shell_environment_policy.set]` → settings.json `env`): re-enter the value by hand. It is present in the target as `<REDACTED-REENTER>`.
- Permission rules: **3 of 7 rules could not be expressed as target permissions.** The three are listed individually below with the reason each one failed. An argv-prefix rule is a list of exact literals, while a Claude permission string is a pattern with its own syntax, so a rule survives only when joining its tokens with spaces produces something Claude can actually match.
- Permission rule (rules/default.rules): `prefix_rule(pattern=["node", "-e", "console.log(require(\"os\").platform())"], decision="allow")` — a token contains quotes and parentheses. `Bash(...)` ends at the first `)`, so converting it would produce a truncated pattern that matches nothing. Recreate it by hand if you need it.
- Permission rule (rules/default.rules): `prefix_rule(pattern=["/bin/zsh", "-lc", "git status --short"], decision="allow")` — a token contains whitespace. Joining on spaces makes the boundary between tokens indistinguishable from the space inside one, so the result would no longer describe the same command.
- Permission rule (rules/default.rules): `prefix_rule(pattern=["bash", "/Users/dev/workspace/monorepo/packages/internal-tooling/scripts/release/pipelines/nightly/steps/verify-and-publish-every-package-with-provenance-and-signed-changelog-attestation-LONGRULE-TAILMARKER-9f2c.sh"], decision="allow")` — the joined string is 210 characters, past the ~200 limit. A prefix that long is a full command line and will never match anything but itself.
- Hook command dependency: the migrated SessionStart hook runs `/Users/dev/.codex/hooks/notify.sh session-start`, which lives inside the Codex home. Claude's settings.json now depends on the Codex installation — uninstall Codex and this hook breaks. The path was left exactly as it was, because whether that script is safe to relocate is not something this tool can know. Copy it somewhere neutral and update the command if you want the two independent.
- Approval policy: source `approval_policy` = `never`, suggested Claude equivalent `permissions.defaultMode` = `bypassPermissions` (procedure.md level 3). Nothing was written.
- Sandbox policy: source `sandbox_mode` = `danger-full-access`, which sits on the same level-3 row. Claude expresses both through the one `defaultMode` key, so the suggestion above covers it. Nothing was written.
- Project trust: `[projects."/tmp/some-project"]` with `trust_level = "trusted"` in config.toml. Trust is a Codex concept and a security decision; recreate it yourself if the equivalent matters to you.

## Not migrated
- Global rules AGENTS.md: `AGENTS.override.md` exists, and Codex reads only the override when it does. AGENTS.md is therefore configuration the source tool was already ignoring. Its contents were never opened, never merged, and are not quoted here, so it is also absent from the ledger.
- Env injection `inherit = "core"` (config.toml `[shell_environment_policy]`): inheritance policy rather than value injection. No target has a corresponding concept — Claude's `env` object injects values and has no inheritance switch. Counted under Env injection rather than as a homeless item, because that is the category it belongs to.
- Keybindings (keybindings.json): command systems differ between the two tools, so there is nothing to convert. Existence noted only.
- Credentials (auth.json): existence confirmed only, per security.md. Never opened, so it is absent from the ledger.
- Model (config.toml `model`): current value `gpt-5.6-sol`. Not migrated — the target's `model` is `claude-fable-5` and an OpenAI model name has no meaning there.
- Project trust (config.toml `[projects."/tmp/some-project"]`): `trust_level = "trusted"`. Not migratable; see the manual-action list.
- MCP servers: none found in config.toml. MCP is out of scope for this tool regardless — a definition usually carries its credential inline, and a redacted server would arrive registered and non-functional.
- Plugins and marketplaces: none found in config.toml, so no skill, subagent, or hook in this run is plugin-owned.

## Verification
- `jq -e . settings.json` — ok.
- `grep -rF '<REDACTED-REENTER>'` outside .migrate/ — 1 hit. The source had exactly 1 secret-bearing key, so the counts match. TRUSTED_CLIENT_SHA256S is deliberately not among them.
- `grep -rE 'sk-[A-Za-z0-9_-]{16,}'` outside .migrate/ — 0 hits. No secret shape reached the target.
- `grep -rl 'OVERRIDDEN-DECOY'` over the whole target — 0 files. Nothing from the ignored AGENTS.md reached the target.
- Pre-existing target content survived: `EXISTING_KEY = "keep"` still in `env`, `Bash(ls:*)` still first in `permissions.allow`, the `Read` / `echo existing-pre` hook still first in `PreToolUse`, `# Existing` / `Keep me.` still at the top of CLAUDE.md.
- backup/ holds CLAUDE.md and settings.json — exactly the two files in `changes.json`'s `modified`.
