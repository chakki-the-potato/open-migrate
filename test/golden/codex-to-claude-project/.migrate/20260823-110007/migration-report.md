# Migration Report: codex → claude (20260823-110007)

Project root: `<TARGET>`
Scope: project. Source and target share one root — `.codex/` is the source layer, `.claude/` and the root `CLAUDE.md` are the destination.
Confirm: approved in full, nothing excluded.

## Scan summary
| Category | Found | Automatic | Approximate | Suggestion | Skipped | Excluded | Impossible |
|---|---|---|---|---|---|---|---|
| Global rules | 1 | 1 | 0 | 0 | 0 | 0 | 0 |
| Skills | 2 | 2 | 0 | 0 | 0 | 0 | 0 |
| Commands/prompts | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| Subagents | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| Hooks | 1 | 1 | 0 | 0 | 0 | 0 | 0 |
| Permission rules | 2 | 2 | 0 | 0 | 0 | 0 | 0 |
| Env injection | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| Approval/sandbox policy | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| Non-migratable items | 0 | 0 | 0 | 0 | 0 | 0 | 0 |

Commands, subagents, env injection, and approval policy are all zero because **Codex has no project surface for them** — `prompts/`, `agents/`, and `[shell_environment_policy]` load from the home config only. There was nothing to find, not something that failed.

## Git status
**This project is not a git repository.** `git rev-parse --show-toplevel` fails here, and no ancestor answered either. Nothing written by this run is shared with anyone as things stand — but say it that way rather than as a promise: one `git init` in this directory would turn every file below into an untracked change. There is no `.gitignore` here today.

Because there is no repository, the working-tree check that would normally stop a migration mid-flight had nothing to report, and `check-ignore` had nothing to answer.

## Migrated (automatic)
- Global rules: `AGENTS.md` → `CLAUDE.md` (appended `## Migrated from codex (2026-08-23)` → `### AGENTS.md`, body verbatim) (not a git repository)
- Skills: `.codex/skills/proj-hello/` → `.claude/skills/proj-hello/` (not a git repository)
- Skills: `.agents/skills/shared-skill/` → `.claude/skills/shared-skill/` (not a git repository)
- Hooks: `.codex/hooks.json` PreToolUse `apply_patch` → `.claude/settings.json` hooks.PreToolUse matcher `Edit|Write` (not a git repository)
- Permission rules: `Bash(pnpm build:*)` allow → `.claude/settings.json` `permissions.allow` (not a git repository)
- Permission rules: `Bash(curl:*)` deny → `.claude/settings.json` `permissions.deny` (not a git repository)

The rules were written to the **root `CLAUDE.md`**, not `.claude/CLAUDE.md`. That is the location Claude Code documents first, and repositories frequently gitignore the whole `.claude/` directory — putting team rules there would hide them from the team they are for. `.claude/CLAUDE.md` does not exist here, so there was no reason to prefer it.

The project's permission rules came from `[permission]` inside `.codex/config.toml`, which is where Codex keeps them at project level. The home-scope Starlark `rules/*.rules` surface does not exist in a project, so no `.codex/rules/` was looked for. They were already written in Claude's rule syntax, so they carried over verbatim.

`.claude/settings.json` did not exist before this run, so it was created rather than merged, and there was nothing to back up for it. It was written as the **shared** settings file, not `settings.local.json` — moving a setting between shared and local changes who sees it, so the source's shared project config stays shared.

## Manual action required
- **Codex trust could not be checked, and it matters in both directions.** Codex ignores a project's `.codex/` layer unless `~/.codex/config.toml` holds a `[projects."<path>"] trust_level = "trusted"` entry for it. This run is pointed at a given project root rather than a real tool home, so reading the real `~/.codex` was off limits and no answer is available. Two things follow. If the entry was missing, the `.codex/` config you just migrated was never active in Codex — and a rule that never took effect at the source can behave differently once it is live on the target, so review the migrated permissions and hook before trusting them. Check by hand with:

```toml
[projects."<TARGET>"]
trust_level = "trusted"
```

## Not migrated
- MCP servers: **0 found**. `.codex/config.toml` holds only a `[permission]` table. MCP is out of scope for this tool regardless — a definition usually carries its credential inline, and a redacted server would arrive registered and non-functional.

## The shared skill is now visible twice
`.agents/skills/` is a vendor-neutral path, not Codex's and not anyone else's. Claude Code does **not** read it, so `shared-skill` had to be copied into `.claude/skills/` for Claude to see it. **The original was not deleted** — removing it would break the tools that were reading it.

The consequence is worth stating plainly: `shared-skill` now exists at `.agents/skills/shared-skill/` and at `.claude/skills/shared-skill/`. Claude sees the new copy. Cursor and Grok read `.agents/skills/` natively and see the original. Any tool reading both paths sees it twice. Nothing here decides that for you — prune whichever copy you do not want.

## Verification
- `jq -e . .claude/settings.json` — valid JSON.
- `git rev-parse --show-toplevel` and `git status --porcelain` were each run **on their own**, not chained. Both report that this is not a repository, which is a normal outcome rather than an error, and chaining them would have silently skipped every check after the first failure.
- Symlink check before merging: `CLAUDE.md` and `AGENTS.md` resolve to two different files, and neither is a symlink. Appending to a symlinked rules file would have written the source into itself.
- Backup: `.migrate/20260823-110007/backup/` holds `CLAUDE.md`, matching `changes.json` `modified` exactly. Nothing else pre-existed, so nothing else was backed up.
- Existing project content preserved: `CLAUDE.md` still opens with `# Project notes / Keep this project note.`
- No secrets were found in the source and no placeholder was needed; the target holds neither.
- Ledger written to `<project>/.migrate/ledger.json` with the 5 source files actually read. A project's ledger is independent of the home ledger and of every other project's.
