# Migration Report: codex → claude (20260822-182040)

Scope: **project**. Source and target share one root — `.codex/` is the source layer and `.claude/` the target layer, in the same directory.
Project root: `test/tmp/golden-run/codex-to-claude-project`

## Git status

`git rev-parse --show-toplevel` answered `<REPO>`, which is **not** the project root. The project sits inside a larger repository, so every tracking answer below describes that outer repository rather than a repository of its own.

`git check-ignore` succeeds for the project path: **the whole project is git-ignored by the outer repository.** Nothing written here can ever be shared through that repository no matter what is done with the diff. Everything below is still migrated, since the configuration works locally either way — but a team expecting `.claude/skills/` in a repository would get nothing from this.

The outer repository's working tree does hold uncommitted changes. Normally that stops a project migration, because writes would land in the same working tree and undoing them with `git checkout .` would take the user's work with them. It does not apply here: the project path is ignored, so these writes produce no entry in that working tree and cannot collide with anything in it.

## Scan summary
| Category | Found | Automatic | Approximate | Suggestion | Skipped | Impossible |
|---|---|---|---|---|---|---|
| Global rules | 1 | 1 | 0 | 0 | 0 | 0 |
| Skills | 2 | 2 | 0 | 0 | 0 | 0 |
| Commands / prompts | 0 | 0 | 0 | 0 | 0 | 0 |
| Subagents | 0 | 0 | 0 | 0 | 0 | 0 |
| Hooks | 1 | 0 | 1 | 0 | 0 | 0 |
| Permission rules | 2 | 2 | 0 | 0 | 0 | 0 |
| Env injection | 0 | 0 | 0 | 0 | 0 | 0 |
| Approval/sandbox policy | 0 | 0 | 0 | 0 | 0 | 0 |
| Non-migratable items | 1 | 0 | 0 | 0 | 0 | 1 |

## Migrated (automatic)
- Global rules: `AGENTS.md` → `CLAUDE.md` under `## Migrated from codex (2026-08-22)` / `### AGENTS.md` (git tracked: no — answered by `<REPO>`, and the path is ignored). **The root `CLAUDE.md` was chosen over `.claude/CLAUDE.md`**: it is the location Claude Code documents first, and repositories frequently ignore the whole `.claude/` directory, which would hide the rules from the team they are for. The root file already existed, so its content was preserved and the migrated section appended.
- Skills: `.codex/skills/proj-hello/` → `.claude/skills/proj-hello/` (git tracked: no — answered by the outer repository, path ignored).
- Skills: `.agents/skills/shared-skill/` → `.claude/skills/shared-skill/` (git tracked: no — same). **`.agents/skills/` is a vendor-neutral shared path.** Cursor and Grok read it natively, so migrating it to those targets would duplicate rather than move — but Claude does not read it, so here it is a real migration. See "Duplicate visibility" below.
- Permissions: `Bash(pnpm build:*)` → `.claude/settings.json` `permissions.allow` (git tracked: no — same).
- Permissions: `Bash(curl:*)` → `permissions.deny`. Both came from **`[permission]` inside `.codex/config.toml`**, not from `rules/*.rules` — the Starlark rules DSL is a home-scope surface only, and there is no `.codex/rules/` directory to look for at project level.

Settings were written to `.claude/settings.json`, the shared file, not `settings.local.json`. Moving a setting between the two changes who sees it, so the choice is never made implicitly.

## Approximated (review recommended)
- Hooks: `.codex/hooks.json` `PreToolUse` / `apply_patch` → `.claude/settings.json` `hooks.PreToolUse` / `Edit|Write` (git tracked: no — answered by the outer repository, path ignored). Claude splits the edit tool in two where Codex has one, so the single matcher becomes an alternation and the reverse cannot recover which was meant.

## Duplicate visibility
- `shared-skill` is now readable from two locations in this project: `.agents/skills/shared-skill/` (the original, untouched) and `.claude/skills/shared-skill/` (the copy). **The original was not deleted** — removing it would break Cursor and Grok, which read `.agents/skills/` natively. Any tool reading both paths will see this skill twice. Prune one yourself if that matters; the migration will not decide it for you.

## Not migrated
- **MCP servers: 0 found** in `.codex/config.toml`. MCP is out of scope for this tool regardless — a definition carries its credential inline, and a redacted server arrives registered and broken. There were none here.
- Subagents: **no project surface on the source side.** Codex reads subagents only from `$CODEX_HOME/agents/`, so a project-scope Codex migration has none to offer. This is a real absence, not a skipped scan.
- Commands / prompts: same — `prompts/` is home-scope only in Codex.
- Env injection: same — `[shell_environment_policy]` loads from the home `config.toml` only.
- Approval/sandbox policy: home-scope only; nothing at project level to suggest from.

## Manual action required
- **Codex trust gate.** Codex ignores a project's `.codex/` layer unless the home config trusts that path. This run read `.codex/` as the source, and could not check the real `~/.codex/config.toml` because the source root given was the project — so whether the config being migrated was ever live on Codex is unknown here. If it was not, note that a rule which never took effect on the source may behave differently now that it is active on Claude. To trust it on the Codex side:

```toml
[projects."<TARGET>"]
trust_level = "trusted"
```

  **The migration did not add this** — trusting a repository is your decision.

## Verification
- `jq -e . .claude/settings.json` — valid.
- `git ls-files --error-unmatch` and `git check-ignore` were each run as their own command, never chained. Chaining them into an `&&` sequence silently aborts everything after the first non-zero exit, and a run where the later checks never executed looks identical to one where they found nothing.
- No git command other than `rev-parse`, `ls-files`, `check-ignore`, and `status --porcelain` was run. Nothing was staged, committed, or stashed.
- The ledger lives at `<project>/.migrate/ledger.json`, independent of the home ledger and of every other project's.
- Backup holds the one file listed in `changes.json` `modified`; `.claude/settings.json` is in `created`, so it has no backup and needs none.
