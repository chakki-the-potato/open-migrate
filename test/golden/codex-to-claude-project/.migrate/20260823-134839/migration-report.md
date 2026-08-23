# Migration Report: codex → claude (20260823-134839)

Project scope. Source and target share one root: `.codex/` is the source layer and `.claude/` is the target layer inside the same directory.

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

## Migrated (automatic)
- Global rules: AGENTS.md → CLAUDE.md (`## Migrated from codex (2026-08-23)` section, verbatim) (not a git repository). The root `CLAUDE.md` was chosen over `.claude/CLAUDE.md`: it is the location Claude Code documents first, and repositories frequently gitignore the whole `.claude/` directory, which would hide the rules from the team they are for. The root file already existed, so no choice-by-absence was involved
- Skills: proj-hello → .claude/skills/proj-hello/ (not a git repository)
- Skills: shared-skill → .claude/skills/shared-skill/ (not a git repository). This one lives in the vendor-neutral `.agents/skills/` path. Claude Code does not read that path, so it was migrated rather than recorded as already visible
- Hooks: PreToolUse `apply_patch` → .claude/settings.json PreToolUse matcher `Edit|Write` (not a git repository). Claude splits Codex's single edit tool into two, so the matcher was expanded to a regex alternation covering both
- Permission rules: `Bash(pnpm build:*)` → .claude/settings.json `permissions.allow`, verbatim (not a git repository). At project level Codex keeps permission rules inside `.codex/config.toml` `[permission]` rather than in the Starlark `rules/*.rules` DSL, and those strings already use Claude's syntax
- Permission rules: `Bash(curl:*)` → .claude/settings.json `permissions.deny`, verbatim (not a git repository)

## Approximated (review recommended)
- Nothing was approximated in this run.

## Manual action required
- Duplicate visibility of `shared-skill`: the original stays at `.agents/skills/shared-skill/` and a copy now exists at `.claude/skills/shared-skill/`. The source copy was deliberately not deleted — removing it would break the tools that were reading it. Cursor and Grok read `.agents/skills/` natively, and Cursor also reads `.claude/skills/` as a compatibility path, so Cursor may now see this skill twice. Prune whichever copy you do not want; this tool will not decide that for you.
- Source-side trust could not be checked. Codex ignores a project's `.codex/` layer unless the home `~/.codex/config.toml` holds a `[projects."<absolute path>"]` entry for it — so whether the configuration migrated here was ever live in Codex depends on that entry. This run was pointed at a project root rather than a real tool home, which puts the source side in test mode, and reading the real `~/.codex/config.toml` is forbidden in that situation. The status is therefore unknown rather than absent. If this project had no trust entry, the rules and hooks migrated above never took effect in Codex and may behave differently now that they are active in Claude — worth a look before relying on them.

## Not migrated
- Subagents: Codex reads subagents only from `$CODEX_HOME/agents/` and has no project surface for them. This project's `.codex/` layer contains none, so there was nothing to record under manual action. Counted as 0 found.
- Commands/prompts: `prompts/` is home-scope only in Codex, and this project has none. Counted as 0 found.
- Env injection: `[shell_environment_policy]` loads from the home `config.toml` only, and `.codex/config.toml` here carries no env block. Counted as 0 found.
- Approval and sandbox policy: Codex leaves these to home scope, and `.codex/config.toml` here sets neither. Counted as 0 found, so there is no suggestion to make.
- Model: not set in `.codex/config.toml`. Project-level Codex config does not load it in any case.
- MCP servers: none found. MCP is out of scope for this tool regardless — a definition usually carries its credential inline, and a redacted server would arrive registered and non-functional.

## Verification
- `jq -e . .claude/settings.json` — ok.
- `git -C <project> rev-parse --show-toplevel` — fails: **not a git repository**, and no repository holds this directory either. Nothing written here is shared with anyone **as things stand**. That is a statement about the present, not a promise: there is no `.gitignore` here, but one `git init` would turn every file this run wrote into an untracked change.
- `git -C <project> status --porcelain` — the same failure, so the uncommitted-work gate did not apply. There is no working tree to land writes in beside someone's in-progress edits.
- `git -C <project> check-ignore -q <path>` and `git -C <project> ls-files --error-unmatch <path>` — both fail for the same reason. Each check was run as its own command rather than chained, so a non-zero exit from one did not silently skip the others.
- Rules-file identity: `CLAUDE.md` and `AGENTS.md` are two separate regular files with different inodes, and neither is a symlink. They were merged normally. This matters more in project scope than in home scope, since source and target share one root and people do symlink one rules file to another.
- `grep -rE 'sk-[A-Za-z0-9_-]{16,}'` outside .migrate/ — 0 hits. No secret-bearing key was found in this source, so no `<REDACTED-REENTER>` placeholder was needed either; 0 placeholders against 0 secrets is a matching count.
- Pre-existing target content survived: `# Project notes` / `Keep this project note.` still at the top of CLAUDE.md, with the migrated section appended after it.
- The source layer is untouched: `.codex/` and `.agents/` still hold exactly what they held before the run.
- backup/ holds CLAUDE.md alone — exactly the one file in `changes.json`'s `modified`. The three files under `created` did not exist before this run and have no backup by definition, which is why `changes.json` rather than the backup directory is what makes this run undoable.
- The ledger was written to `<project>/.migrate/ledger.json`, independent of the home ledger and of every other project's.
