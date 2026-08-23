# Migration Report: codex → cursor (20260823-132056)

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
| Approval/sandbox policy | 2 | 0 | 0 | 2 | 0 | 0 | 0 |
| Non-migratable items | 4 | 0 | 0 | 0 | 0 | 0 | 4 |

## Migrated (automatic)
- Skills: hello → skills/hello/ (SKILL.md and reference/tone.md)
- Subagents: agents/reviewer.toml → agents/reviewer.md (`description` became the frontmatter `description`, `developer_instructions` became the body, and the filename supplied `name`)
- Hooks: SessionStart → hooks.json `sessionStart`, appended after the target's existing entry
- Permission rules: `prefix_rule(pattern=["git", "status"], decision="allow")` → `Shell(git status:*)` in cli-config.json `permissions.allow`
- Permission rules: `prefix_rule(pattern=["npm", "run", ["build", "test"]], decision="allow")` → `Shell(npm run build:*)` and `Shell(npm run test:*)`, the positional union expanded into both combinations
- Permission rules: `prefix_rule(pattern=["rm"], decision="forbidden")` → `Shell(rm:*)` in `permissions.deny`

## Approximated (review recommended)
- Commands/prompts prompts/greet.md → skills/greet/SKILL.md: Cursor's command surface is deprecated as a write destination, so the prompt was wrapped as a skill. Two losses. The source had no `description`, so the body's first sentence was used verbatim rather than invented. And `$ARGUMENTS` has no equivalent in a Cursor skill — the token stays in the body as literal text and will never be substituted.
- Hooks PreToolUse `apply_patch` → `preToolUse` with matcher `Write`: the mapping is direct, but the hook entry also carried a `statusMessage` field with the value `Checking the patch before it lands`. Cursor's hook objects have no such field, so it was dropped. The value is quoted here so nothing is silently lost.
- Hooks PostToolUse `shell|local_shell|apply_patch|CascadeEdit|Grep|mcp__.*` → `Shell|Write|Grep|mcp__.*`: `shell` and `local_shell` are the Codex shell family and both became `Shell`, de-duplicated to one; `apply_patch` became `Write`; `Grep` is already a Cursor matcher name and passed through; `mcp__.*` is a regex rather than a tool name and was carried verbatim, since MCP tool names are identical on every target. **`CascadeEdit` was dropped** — it belongs to neither tool's vocabulary, and guessing a mapping would silently scope the hook to the wrong tool.

## Manual action required
- Global rules (AGENTS.override.md): Cursor has no global rule file. The equivalent is User Rules, which lives in the Cursor account and cannot be written to disk, and no project root was given for this run. Nothing was written. Paste the text below into Cursor's User Rules by hand. The `@~/.agent-rules-fixture.md` import line was not expanded, so whatever it points at has to be brought over separately.

```markdown
# Global Rules

@~/.agent-rules-fixture.md

- Answer in Korean.
- Never commit secrets.
```
- Env injection FIXTURE_FLAG (config.toml `[shell_environment_policy.set]`, current value `1`): Cursor has no global env surface. Move it into a per-server `env` block or your shell profile.
- Env injection TRUSTED_CLIENT_SHA256S (config.toml `[shell_environment_policy.set]`, current value `02aa45f33f6384022cfc3e1045ad58ac1af9db9b095d259367f3a3fb6aaf33a7`): same — no global env surface in Cursor. The value is a digest, not a credential, so it is quoted here in full; you would otherwise have to dig it up again to restore a working setting.
- Env injection SERVICE_API_KEY (config.toml `[shell_environment_policy.set]`): same — no global env surface in Cursor. The value is a detected secret and is not reproduced here; take it from the source config.toml yourself.
- Permission rules: **4 of 7 rules could not be expressed as target permissions.** The four are listed individually below with the reason each one failed. Three are shape failures — an argv-prefix rule is a list of exact literals, while a Cursor permission string is a pattern with its own syntax, so a rule survives only when joining its tokens with spaces produces something Cursor can actually match. The fourth failed for a different reason: Cursor has no `ask` tier to put it in.
- Permission rule (rules/default.rules): `prefix_rule(pattern=["git", "push"], decision="prompt")` — Cursor has no `ask`/`prompt` tier. Putting it in `allow` or `deny` would distort what it meant, so it was left out of both.
- Permission rule (rules/default.rules): `prefix_rule(pattern=["node", "-e", "console.log(require(\"os\").platform())"], decision="allow")` — a token contains quotes and parentheses. `Shell(...)` ends at the first `)`, so converting it would produce a truncated pattern that matches nothing.
- Permission rule (rules/default.rules): `prefix_rule(pattern=["/bin/zsh", "-lc", "git status --short"], decision="allow")` — a token contains whitespace. Joining on spaces makes the boundary between tokens indistinguishable from the space inside one.
- Permission rule (rules/default.rules): `prefix_rule(pattern=["bash", "/Users/dev/workspace/monorepo/packages/internal-tooling/scripts/release/pipelines/nightly/steps/verify-and-publish-every-package-with-provenance-and-signed-changelog-attestation-LONGRULE-TAILMARKER-9f2c.sh"], decision="allow")` — the joined string is 210 characters, past the ~200 limit. A prefix that long is a full command line and will never match anything but itself.
- Hook command dependency: the migrated `sessionStart` hook runs `/Users/dev/.codex/hooks/notify.sh session-start`, which lives inside the Codex home. Cursor's hooks.json now depends on the Codex installation — uninstall Codex and this hook breaks. The path was left exactly as it was, because whether that script is safe to relocate is not something this tool can know.
- Approval policy: source `approval_policy` = `never`, suggested Cursor equivalent `approvalMode` = `unrestricted` (procedure.md level 3). The target's existing `approvalMode` is `allowlist` and was left untouched — this tool never sets it.
- Sandbox policy: source `sandbox_mode` = `danger-full-access`, which sits on the same level-3 row. Cursor expresses both through the one `approvalMode` key, so the suggestion above covers it. Nothing was written.
- Project trust: `[projects."/tmp/some-project"]` with `trust_level = "trusted"` in config.toml. Trust is a Codex concept and a security decision; recreate it yourself if the equivalent matters to you.

## Not migrated
- Global rules AGENTS.md: `AGENTS.override.md` exists, and Codex reads only the override when it does. AGENTS.md is therefore configuration the source tool was already ignoring. Its contents were never opened, never merged, and are not quoted here, so it is also absent from the ledger.
- Hooks PreToolUse `read_file`: Cursor has no matcher corresponding to Codex's `read_file`. That was the entry's only matcher, so the alternation emptied and the whole hook was dropped rather than left with an empty matcher. Its command was `echo pre-read` with a 5-second timeout.
- Hooks `Notification` (hooks.json, command `echo notify`): Cursor has no corresponding event. Dropped.
- Env injection `inherit = "core"` (config.toml `[shell_environment_policy]`): inheritance policy rather than value injection, and Cursor has no env surface at all. Counted under Env injection rather than as a homeless item, because that is the category it belongs to.
- Keybindings (keybindings.json): command systems differ between the two tools, so there is nothing to convert. Existence noted only.
- Credentials (auth.json): existence confirmed only, per security.md. Never opened, so it is absent from the ledger.
- Model (config.toml `model`): current value `gpt-5.6-sol`. Cursor's cli-config.json has no equivalent key that would accept it.
- Project trust (config.toml `[projects."/tmp/some-project"]`): `trust_level = "trusted"`. Not migratable; see the manual-action list.
- MCP servers: none found in config.toml. MCP is out of scope for this tool regardless — a definition usually carries its credential inline, and a redacted server would arrive registered and non-functional.
- Plugins and marketplaces: none found in config.toml, so no skill, subagent, or hook in this run is plugin-owned.
- `skills-cursor/canvas/` in the target is app-managed built-in content. Nothing was written there and nothing was read from it.

## Verification
- `jq -e . hooks.json` — ok. `jq -e . cli-config.json` — ok.
- `grep -rF '<REDACTED-REENTER>'` outside .migrate/ — 0 hits, and 0 is the right answer here. The source's one secret-bearing key belongs to a category Cursor cannot receive at all, so no placeholder was written; the key is in the manual-action list instead.
- `grep -rE 'sk-[A-Za-z0-9_-]{16,}'` outside .migrate/ — 0 hits. No secret shape reached the target.
- `grep -rl 'OVERRIDDEN-DECOY'` over the whole target — 0 files. Nothing from the ignored AGENTS.md reached the target.
- Pre-existing target content survived: `Shell(ls)` still first in `permissions.allow`, `echo existing-session` still first in `hooks.sessionStart`, `approvalMode` still `allowlist`.
- `skills-cursor/canvas/SKILL.md` still carries its untouched marker — the app-managed area was not written to.
- backup/ holds hooks.json and cli-config.json — exactly the two files in `changes.json`'s `modified`.

## Note on Cursor's compatibility loading
Cursor can read `~/.codex/skills/` and `~/.codex/agents/` directly, so the hello skill and the reviewer subagent may have been visible to Cursor already. Confirming that requires asking, and this run was a blanket approval, so they were migrated rather than skipped — the documented choice in that situation. If your Cursor settings have those compatibility paths enabled, you now have each of them in two places.
