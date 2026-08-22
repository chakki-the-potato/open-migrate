# Migration Report: codex → cursor (20260822-175743)

Source root: `test/fixtures/codex-home` (test mode)
Target root: `test/tmp/golden-run/codex-to-cursor` (test mode)
Scope: home only — no project root was given, which is why the global rules below could not be written.

## Scan summary
| Category | Found | Automatic | Approximate | Suggestion | Skipped | Impossible |
|---|---|---|---|---|---|---|
| Global rules | 1 | 0 | 0 | 0 | 0 | 1 |
| Skills | 1 | 1 | 0 | 0 | 0 | 0 |
| Commands / prompts | 1 | 0 | 1 | 0 | 0 | 0 |
| Subagents | 1 | 1 | 0 | 0 | 0 | 0 |
| Hooks | 5 | 1 | 2 | 0 | 0 | 2 |
| Permission rules | 7 | 4 | 0 | 0 | 0 | 3 |
| Env injection | 3 | 0 | 0 | 0 | 0 | 3 |
| Approval/sandbox policy | 1 | 0 | 0 | 1 | 0 | 0 |
| Non-migratable items | 6 | 0 | 0 | 0 | 0 | 6 |

## Migrated (automatic)
- Skills: `skills/hello/` → `skills/hello/` (SKILL.md and reference/tone.md). Written under `skills/`, never `skills-cursor/`, which is app-managed.
- Subagents: `agents/reviewer.toml` → `agents/reviewer.md`. Cursor's frontmatter takes `name`/`description`/`model`/`readonly`/`is_background`; the source had only the first two, so nothing was dropped.
- Hooks: `SessionStart` → `sessionStart`, appended alongside the existing `echo existing-session`.
- Permissions: `["git","status"]` allow → `Shell(git status:*)`. The token is renamed from Codex's argv form to Cursor's `Shell(...)`; the colon argument syntax is Cursor's own.
- Permissions: `["npm","run",["build","test"]]` allow → `Shell(npm run build:*)` and `Shell(npm run test:*)`.
- Permissions: `["rm"]` forbidden → `Shell(rm:*)` (deny).

## Approximated (review recommended)
- Commands: `prompts/greet.md` → `skills/greet/SKILL.md`. Cursor has no command surface, so it becomes a skill. Two losses. The source has no `description`, so **the body's first sentence was used verbatim rather than invented** — synthesized, not authored. And **Cursor skills have no `$ARGUMENTS` substitution**, so the token survives as literal text and will never be replaced; the body was not edited.
- Hooks: `PreToolUse` / `apply_patch` → `preToolUse` matcher `Write`. Cursor has a single `Write` matcher where Codex had `apply_patch`. The entry also carried `statusMessage: "Checking the patch before it lands"`, which is not a Cursor hook field — **dropped**.
- Hooks: `PostToolUse` (command `echo post-tool`, timeout 8) / `shell|local_shell|apply_patch|CascadeEdit|Grep|mcp__.*` → `postToolUse` matcher `Shell|Write|Grep|mcp__.*`. `shell` and `local_shell` both become `Shell` and were de-duplicated; `apply_patch` became `Write`; `Grep` is already Cursor's own name; `mcp__.*` is a pattern and was carried verbatim. **`CascadeEdit` was dropped** — no vocabulary on either side defines it.

## Manual action required
- **Global rules (`AGENTS.override.md`): nothing was written.** Cursor has no global rule file — the equivalent is User Rules, stored in your Cursor account, which cannot be written to disk. Paste this in yourself, or re-run naming a project root so it can go into that project's `AGENTS.md`:

```
# Global Rules

@~/.agent-rules-fixture.md

- Answer in Korean.
- Never commit secrets.
```

- Permission rule (`rules/default.rules`): `prefix_rule(pattern=["git", "push"], decision="prompt")` — **Cursor has no `ask` tier.** Putting it in `allow` or `deny` would distort what the rule means, so it went into neither. Decide which you want.
- Permission rule (`rules/default.rules`): `prefix_rule(pattern=["node", "-e", "console.log(require(\"os\").platform())"], decision="allow")` — a token contains quotes and parentheses, which the target's pattern syntax cannot express.
- Permission rule (`rules/default.rules`): `prefix_rule(pattern=["/bin/zsh", "-lc", "git status --short"], decision="allow")` — a token contains whitespace.
- Permission rule (`rules/default.rules`): `prefix_rule(pattern=["bash", "/Users/dev/workspace/monorepo/packages/internal-tooling/scripts/release/pipelines/nightly/steps/verify-and-publish-every-package-with-provenance-and-signed-changelog-attestation-LONGRULE-TAILMARKER-9f2c.sh"], decision="allow")` — the joined form is 216 characters, past the ~200 limit.
- **Env injection: Cursor has no global env surface**, so all three keys from `config.toml` `[shell_environment_policy.set]` are unmigratable. Move them into a shell profile or a per-server `env` yourself:
  - `FIXTURE_FLAG` (`config.toml`) — value `"1"`.
  - `SERVICE_API_KEY` (`config.toml`) — detected as a secret. The value is not recorded anywhere in this report.
  - `TRUSTED_CLIENT_SHA256S` (`config.toml`) — a digest, not a credential, so the value is safe to carry: `02aa45f33f6384022cfc3e1045ad58ac1af9db9b095d259367f3a3fb6aaf33a7`.
- Hook `sessionStart` command references the source tool's home: `/Users/dev/.codex/hooks/notify.sh session-start`. Migrated unchanged and working, but `~/.cursor` now depends on `~/.codex` staying installed. The path was not rewritten.

**3 of 7 permission rules could not be expressed as Cursor permissions**, and a fourth (`git push`) had no tier to land in. The 4 that converted produced 5 entries.

## Not migrated
- **MCP servers: 0 found** in `config.toml`. MCP is out of scope for this tool regardless — a definition carries its credential inline, and a redacted server arrives registered and broken. There were none here.
- Hooks: `PreToolUse` / `read_file` (command `echo pre-read`) — **dropped entirely.** `read_file` has no corresponding Cursor matcher, which empties the matcher; an empty matcher would widen the hook to every tool call rather than match nothing.
- Hooks: `Notification` (command `echo notify`) — **dropped.** Cursor has no `Notification` event.
- `model = "gpt-5.6-sol"` (`config.toml`): model names differ per tool.
- `keybindings.json`: `[{ "command": "realtimeVoice", "key": "Alt+V" }]` — command systems differ.
- `[projects."/tmp/some-project"]` `trust_level = "trusted"` (`config.toml`): no Cursor equivalent.
- `auth.json` (91 bytes): never read. Absent from the ledger for the same reason.
- `AGENTS.md` (`AGENTS.md`): ignored because `AGENTS.override.md` exists. Contents neither migrated nor quoted.
- `[shell_environment_policy].inherit = "core"` (`config.toml`): inheritance policy, not value injection.

## Suggestion (nothing was written)
- Approval/sandbox: source `approval_policy = "never"` and `sandbox_mode = "danger-full-access"` correspond to Cursor `approvalMode = "unrestricted"`. **Not applied** — the existing `approvalMode = "allowlist"` was left exactly as it was.

## Verification
- `jq -e .` on `cli-config.json` and `hooks.json` — both valid.
- Secret-shape scan (`sk-`, `ghp_`, `xoxb-`, `AKIA`) over the target — no match. No secret was written, since Cursor has no env surface to write one into.
- `grep -rF 'OVERRIDDEN-DECOY'` excluding `.migrate/` — no match.
- `skills-cursor/` untouched: `APP-MANAGED-DECOY-UNTOUCHED` still present and unmodified.
- No trace of `auth.json` in the target.
- Backup holds both files listed in `changes.json` `modified`.
