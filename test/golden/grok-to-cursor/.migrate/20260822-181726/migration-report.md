# Migration Report: grok → cursor (20260822-181726)

Source root: `test/fixtures/grok-home` (test mode)
Target root: `test/tmp/golden-run/grok-to-cursor` (test mode)
Scope: home only — no project root was given, which is why the global rules below could not be written.

## Scan summary
| Category | Found | Automatic | Approximate | Suggestion | Skipped | Impossible |
|---|---|---|---|---|---|---|
| Global rules | 1 | 0 | 0 | 0 | 0 | 1 |
| Skills | 1 | 0 | 1 | 0 | 0 | 0 |
| Commands / prompts | 0 | 0 | 0 | 0 | 0 | 0 |
| Subagents | 1 | 0 | 1 | 0 | 0 | 0 |
| Hooks | 2 | 0 | 1 | 0 | 0 | 1 |
| Permission rules | 5 | 4 | 0 | 0 | 0 | 1 |
| Env injection | 2 | 0 | 0 | 0 | 0 | 2 |
| Approval/sandbox policy | 2 | 0 | 0 | 1 | 0 | 1 |
| Non-migratable items | 3 | 0 | 0 | 0 | 0 | 3 |

## Migrated (automatic)
- Permissions: `Bash(git status:*)` → `Shell(git status:*)`. Grok uses Claude's syntax, so the tool token is renamed to Cursor's; the colon argument form is identical and kept as-is.
- Permissions: `Bash(npm run build:*)` → `Shell(npm run build:*)`.
- Permissions: `Bash(npm run test:*)` → `Shell(npm run test:*)`.
- Permissions: `Bash(rm:*)` (deny) → `Shell(rm:*)` (deny).

## Approximated (review recommended)
- Skills: `skills/hello/` → `skills/hello/`, with **`user-invocable: true` dropped from the frontmatter.** That key is Grok-only; Cursor does not read it. Only the key was removed — the rest of the frontmatter and the whole body are unchanged, and `reference/tone.md` came across untouched. Written under `skills/`, never `skills-cursor/`, which is app-managed.
- Subagents: `agents/reviewer.md` → `agents/reviewer.md`. `name` and `description` map directly. **Four Grok-only fields were dropped**: `promptMode: extend`, `capabilityMode: read-only`, `effort: high`, `maxTurns: 5`. Cursor's frontmatter has `model`, `readonly`, and `is_background`, none of which is the same field as any of these — `capabilityMode: read-only` and Cursor's `readonly` look alike but are not documented as equivalent, and guessing would be inventing a value.
- Hooks: `PreToolUse` / `Edit|Write` → `preToolUse` matcher `Write`. Cursor has one write matcher where Grok has two tools, so both alternatives map onto `Write` and de-duplicate to a single token.

## Manual action required
- **Global rules (`rules/global.md`): nothing was written.** Cursor has no global rule file — the equivalent is User Rules, stored in your Cursor account, which cannot be written to disk. Paste this in yourself, or re-run naming a project root so it can go into that project's `AGENTS.md`:

```
# Global Rules

@~/.agent-rules-fixture.md

- Answer in Korean.
- Never commit secrets.
```

  The `@~/.agent-rules-fixture.md` line is an import that was never expanded, so whatever it points at has to come across too.

- Permission rule (`config.toml`, `[permission] ask`): `Bash(git push:*)` — **Cursor has no `ask` tier.** Putting it in `allow` or `deny` would distort what the rule means, so it went into neither. Decide which you want.
- **Env injection: Cursor has no global env surface**, so both keys from `config.toml` `[shell_environment_policy.set]` are unmigratable. Move them into a shell profile or a per-server `env` yourself:
  - `FIXTURE_FLAG` (`config.toml`) — value `"1"`.
  - `SERVICE_API_KEY` (`config.toml`) — detected as a secret. The value is not recorded anywhere in this report.
- Subagent behavior: the four dropped fields above changed what `reviewer` does on Grok. Rebuild the constraint yourself if it mattered.

**1 of 5 permission rules had no tier to land in.** The other 4 converted by renaming the tool token.

## Not migrated
- **MCP servers: 0 found** in `config.toml`. MCP is out of scope for this tool regardless — a definition carries its credential inline, and a redacted server arrives registered and broken. There were none here.
- Global rules: `GROK.md` — **not a migration target.** Grok does not read that filename, so it is dead config on the source rather than a rule file. Its contents were neither migrated nor quoted, and it is absent from the ledger.
- Hooks: `Notification` (command `echo notify`) — **dropped.** Cursor has no `Notification` event.
- Commands: none found. Grok has no command surface at all.
- `[sandbox] profile = "off"` (`config.toml`): OS-level isolation whose meaning differs per tool. No equivalent mapping exists.
- `model = "grok-5-code"` (`config.toml`): model names differ per tool.
- `auth.json`: never read. security.md forbids opening credential files, hashing included, so it is absent from the ledger too.

## Suggestion (nothing was written)
- Approval policy: source `[ui] permission_mode = "bypassPermissions"` corresponds to Cursor `approvalMode = "unrestricted"`. **Not applied** — the existing `approvalMode = "allowlist"` was left exactly as it was.

## Verification
- `jq -e .` on `cli-config.json` and `hooks.json` — both valid.
- Secret-shape scan (`sk-`, `ghp_`, `xoxb-`, `AKIA`) over the target — no match. No `<REDACTED-REENTER>` placeholder either: Cursor has no env surface, so the secret was reported rather than written in any form.
- `grep -rF 'OVERRIDDEN-DECOY'` excluding `.migrate/` — no match.
- `grep -rF 'user-invocable'` over the target — no match.
- `skills-cursor/` untouched: `APP-MANAGED-DECOY-UNTOUCHED` still present and unmodified.
- No trace of `auth.json` in the target.
- Backup holds both files listed in `changes.json` `modified`.
