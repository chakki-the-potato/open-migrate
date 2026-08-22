# Migration Procedure (5 steps — follow in order)

Before you start, confirm you have read all three: the source tool doc (`core/tools/<source>.md`), the target tool doc (`core/tools/<target>.md`), and `core/security.md`. If any is unread, read it now.

## Precedence when docs conflict

When two docs give different instructions for the same item, resolve it in this order. Do not guess, and do not pick whichever sounds more reasonable.

1. **security.md always wins.**
2. **The target doc wins on write location and format.** Even if the source doc names a destination ("move it to the target's command file"), follow the target doc when it defines that category differently ("migrate as a skill, not a command"). The source doc is authoritative on how to **read and interpret** the source; the target doc is authoritative on **where and in what shape** the result is written.
3. **A specific rule beats a general one.** When a general instruction ("copy the whole directory") collides with a specific one ("this key is invalid on the target, drop it"), follow the specific one.
4. If it is still ambiguous, **do not migrate it.** Put the original in the manual-action list and record the conflict in the report.

## Path resolution in test mode (applies to every tool)

If the target (or source) root is not that tool's real home, you are in test mode. Substitute the root for every home path the tool docs mention — `~/.cursor/cli-config.json` becomes `<root>/cli-config.json`, `~/.grok/config.toml` becomes `<root>/config.toml`. Files that live **outside** the home directory (such as Claude's `~/.claude.json`) fold **inside** the root: `<root>/.claude.json`.

**Test mode applies per side, not to the whole run.** A side is in test mode when *its* root is a path you were given rather than that tool's real home. Reading the real `~/.codex` as the source while writing to a temporary destination is a normal and useful shape — a dry run against real configuration — and the source side is simply not in test mode there.

**For a side that is in test mode, never read that tool's real home.** Pulling the user's actual configuration into a run that was pointed elsewhere corrupts the result: the destination would be checked for conflicts against files it does not have. If the root has no corresponding file, record it as "scope not present", count it as 0, and note it in the report.

## Run artifacts (every scope)

Generate the run-id now, in `YYYYMMDD-HHMMSS` format. This run's artifacts (backups, report) go in `<root>/.migrate/<run-id>/`. The one exception is the ledger `ledger.json`, which is shared across runs and lives at `<root>/.migrate/ledger.json`.

`<root>` is the target root in a home-scope migration and the project root in a project-scope one. This applies to every run, not only to test mode.

## Project scope

Everything above describes **home scope** — the tool's own configuration directory. Tools also read **project scope** configuration from the repository you are working in. Migrating project scope has three differences you must respect.

**Source and target share one root.** In home scope the source (`~/.codex`) and the target (`~/.claude`) are two separate trees. In a project they are the same directory: `<project>/.codex/` is the source and `<project>/.claude/` is the target. You are given one project root, not a source root and a target root.

**Project config is usually tracked by git.** Migrating produces a diff in someone's repository and, once pushed, reaches teammates. For every file you write or modify, check whether git tracks it (`git -C <project> ls-files --error-unmatch <path>` succeeds) and record the answer in the report. Never run any other git command — do not stage, commit, or stash. The user decides what to do with the diff.

Before trusting that answer, find out **which** repository answered. `git -C <project> rev-parse --show-toplevel` gives the repository root; compare it to the project root.

**Stop when the working tree already has uncommitted changes.** Run `git -C <project> status --porcelain` during Scan. If it returns anything, the user has work in progress, and your writes would land in the same working tree — after which `git checkout .` to undo the migration destroys their work too. Do not migrate that project. Report what is uncommitted, say the project was skipped for that reason, and let the user commit or stash before re-running. Untracked files that the migration itself would create are the exception; anything else means stop.

This is worth the interruption. A migration that is hard to undo is worse than one that has not run yet.

**Check whether the destination path is ignored, not just untracked.** `git -C <project> check-ignore -q <path>` succeeding means the file will never be shared no matter what the user does with the diff — a stronger fact than "untracked", and one that can defeat the point of the migration. A team that expects `.claude/skills/` in the repository gets nothing if that path is in `.gitignore`. Report ignored destinations explicitly; still migrate them, since the configuration works locally either way.

**Run this check on its own.** It exits non-zero whenever the project is not in a repository — a normal outcome, not an error. Chaining it into a longer `&&` sequence silently aborts everything after it, and the output of a run where the later checks never executed looks identical to a run where they found nothing. The symlink check and the Codex trust check are exactly the kind of thing that disappears this way, so keep each check a separate command.

- **Same path** — the project is its own repository. Report tracking status directly.
- **Different path** — the project sits inside a larger repository (a monorepo package, or a scratch directory under some other checkout). The answer describes that outer repository, so say which one in the report. "Untracked" then means "the outer repository does not track it", which is a different fact from "there is no repository here".
- **No repository at all** — the command fails. Report "not a git repository" rather than "untracked"; nothing is shared **as things stand**. Say it that way rather than promising it never will be: a directory holding a `.gitignore` but no `.git` is scaffolded for a repository nobody has initialized yet, and one `git init` turns every file you just wrote into an untracked change. Mention the `.gitignore` when you see one.

**The ledger lives in the project.** Write `<project>/.migrate/ledger.json` and `<project>/.migrate/<run-id>/`, exactly as home scope does inside the target root. A project's ledger is independent of the home ledger and of every other project's.

Everything else is unchanged: the same five steps, the same category checklist, the same conflict rules, the same security policy.

### Scope selection

- If the user names a project root, migrate project scope for that root.
- If the user names both a home target root and a project root, migrate both and report them as separate sections.
- If the user asks for **every project on the machine**, run the discovery below, present the list in the plan, and migrate the approved ones.
- If the user names neither a project root nor "all projects", migrate home scope only. **Never scan unasked** — picking projects on your own would edit repositories the user never mentioned.

### Discovering every project

Run exactly this. Do not improvise a variant; the exclusions are what keep the tools' own caches out.

```bash
find "$HOME" -maxdepth 5 \
  \( -path "$HOME/.*" -o -name node_modules -o -name Library -o -name .Trash -o -name .git \) -prune -o \
  \( -type d \( -name '.claude' -o -name '.codex' -o -name '.cursor' -o -name '.grok' -o -name '.agents' \) -print \) -o \
  \( -type f \( -name 'AGENTS.md' -o -name 'CLAUDE.md' \) -print \) 2>/dev/null \
  | sed -e 's|/\.[a-z-]*$||' -e 's|/[A-Z]*\.md$||' | sort -u
```

The second clause matters: a project whose only configuration is a root `AGENTS.md` or `CLAUDE.md` has no config *directory* to match on, and searching for directories alone silently skips it. Rules files are the first row of every tool's project inventory, so a scan that cannot see them misses real projects.

Each exclusion earns its place:

- **`$HOME/.*`** — every dotdirectory directly under the home is application data, not a project. This is the rule that removes plugin caches, marketplace clones, and tool state. Without it a real machine returns roughly twice as many hits, most of them the tools' own directories.
- **`node_modules`, `Library`, `.Trash`** — dependency trees and system locations.
- **`.git`** — a repository's internals can contain anything; never treat them as config.

**Do not use "is a git repository" as the test.** On the machine this rule was measured against, 25 git repositories matched and 13 of them were plugin marketplace clones — marketplaces are themselves git repos. Report git status, never decide with it.

**Depth is capped at 5.** That covers every real project on a normal layout and keeps the scan under a tenth of a second. Say so in the report, so a user with deeper nesting knows why something is missing and can pass that project root explicitly.

**Discard results that are not projects.** The exclusions above remove tool data, but a match can still land somewhere that is obviously not a repository — a `~/Documents/.claude/settings.local.json` makes the whole Documents folder look like a project. Drop a hit when it is a standard home folder (`Documents`, `Downloads`, `Desktop`, `Pictures`, `Music`, `Movies`, `Public`) rather than something inside one. Name every discarded hit in the report so the decision is visible; if the user actually keeps a project at that path, they can pass it explicitly.

**Skip projects with nothing to migrate.** A discovered project whose source-tool surfaces are all empty gets no `.migrate/` directory and no ledger — creating them would leave an untracked directory in a repository for no reason. Count it in the scan summary as found-but-empty and move on.

**Rules for the results:**

- **Nested hits are separate projects.** `a/b` appearing under `a` means both carry config; the tools resolve them as distinct scopes. Give each its own ledger and never merge a child's config into its parent.
- **Present the full list before writing anything.** The plan names every project found; Confirm approves the set at once. A run that silently edits seventeen repositories is not acceptable no matter how correct each edit is.
- **One project's failure does not stop the rest.** Record it, continue, and list the failure in the report. Per-project ledgers make a re-run skip whatever already succeeded.

### `.agents/` is shared, not migratable

`<project>/.agents/skills/` is a vendor-neutral path that Cursor and Grok read natively. A skill living there is **already visible** to those tools, so copying it into `.cursor/skills/` or `.grok/skills/` creates a duplicate rather than migrating anything.

- When the target reads `.agents/skills/` natively, record each skill found there as "already being read" and migrate nothing.
- When the target does not read it (Claude Code, Codex CLI), migrate it like any other skill directory.

The same reasoning applies to any other path a target reads natively — check the target doc's compatibility notes before copying.

### Copying a skill directory is not always enough

"Copy the whole directory" is the right default, but two things inside a skill can break or mislead when it moves.

**Relative paths that leave the skill.** A `SKILL.md` referring to `../../../deployment.md` resolves against its own location. It survives only if the target path sits at the same depth — `.codex/skills/<name>/` and `.claude/skills/<name>/` happen to match, but a target that nests differently breaks the reference silently. Check any `../` reference against the destination depth and report the ones that would no longer resolve.

**Vendor-specific helper files.** A skill can ship files only its original tool reads (`openai.yaml` alongside a Codex skill, for example). They copy fine and are harmless, but they are inert on the target — neither lossless nor approximated, just carried along dead. Report them as migrated-but-inert instead of forcing them into another category, and do not mistake one for a subagent because it happens to live in a directory named `agents/`.

**`.agents/skills/` belongs to the project, not to any one tool.** It is a shared surface, so migrate it regardless of which tool you were told the source is — the question is only whether the *target* already reads it. Do not skip it because the source tool's inventory does not list the path; no tool's inventory claims it, and treating that as "not my configuration" would strand every skill living there.

**Never delete the source copy after migrating it.** When you copy a skill out of `.agents/skills/` into a target that does not read that path, the original stays where it is — removing it would break the tools that were reading it. That does leave the same skill visible twice to any tool reading both paths, so say so in the report: name the skill, both locations, and which tools see the duplicate. The user decides whether to prune.

## Category checklist (walk all of it, every run)

1. Global rules  2. Skills  3. Commands/prompts  4. Subagents  5. Hooks
6. Permission rules  7. Env injection  8. Approval/sandbox policy  9. Non-migratable items (keybindings, sessions, auth, model, MCP servers, etc.)

**MCP servers are deliberately out of scope.** Every supported tool has them, and converting the
definitions would be easy, but registering a server changes what the target tool can reach on the
user's machine, and a server definition routinely carries an API key. This tool does neither on the
user's behalf.

Do not treat that as a reason to stay silent. Count the servers you find, list each one by name and
source location under "Not migrated", and say plainly that MCP is out of scope so the user knows to
move them by hand. Silence here reads as "the source had none", which is the one wrong answer.

If the source tool doc's inventory table lists a surface that is missing from this checklist, do not skip it for being absent here — add it as an item, process it, and note it in the report.

**A path that looks like a config surface is not necessarily one.** Repositories contain application code, and some of it borrows the same vocabulary — a `sandbox/skills/<id>/SKILL.md` that an application ships to its own runtime is not this repository's editor configuration, however much the path resembles a skill directory. Migrate only what the source doc's inventory names, at the location it names. When something outside those locations looks migratable, leave it alone and record what you saw and why you skipped it; the user knows their codebase and you do not.

Conversely, if you find **a setting present in the source files but absent from the source doc's inventory table**, do not stay silent about it either. An undocumented setting means there is no conversion rule, so **do not migrate it** — quote the key name and its current value and record it in the report as "not migrated — no conversion rule in the docs".

## Step 1: Scan

- Walk the source doc's inventory table and check each category for file existence and contents.
- For files security.md forbids, record existence only.
- Count the items found per category (record `0` when there are none — never stay silent).

## Step 2: Plan

Group the plan table by category but write **one row per item** — a single category can mix automatic, approximate, and impossible items. Mark each row with one of these:

- **Automatic**: lossless conversion (include a preview of the converted result)
- **Approximate**: conversion with semantic loss (state exactly what is lost)
- **Impossible**: cannot be migrated (reason + how to do it manually)
- **Suggestion**: the target has a corresponding concept but **automatic application is forbidden** (approval policy, sandbox, etc.). Record the source value alongside the suggested value, but write nothing. Do not count these as approximate — approximate means something was written, suggestion means nothing was.

Mark any item with a detected secret as `<REDACTED-REENTER>` in the plan table.

## Step 3: Confirm

- Present the plan table to the user and get approval. Allow excluding whole categories.
- Items that conflict with something already in the target (same-name skill, env key with a different value) are confirmed individually here.
- **Write nothing before approval.** If the user stops, end the run leaving only the plan table.

**When there is nobody to ask** — a scripted run, CI, a non-interactive session — approval cannot be inferred from silence. Produce the plan table, write nothing, and stop, saying that the run needs approval to continue. The one exception is an explicit standing approval in the request itself ("treat Confirm as approved", "run to completion without asking"); that is the user approving in advance, and it is the only thing that substitutes for the step.

Never treat "the user is not here to object" as consent. An unattended run that writes is the one shape of this tool that cannot be undone by declining.

## Step 4: Apply

Process only approved categories, in this order.

1. Create `.migrate/<run-id>/backup/` and back up every existing file you are about to modify. Create the directory even when nothing needs backing up — an empty backup directory records that the run modified no pre-existing file, which is itself worth knowing. Say why it is empty in the report.
2. Check the ledger: if `<target root>/.migrate/ledger.json` already records the sha256 of a source file, skip that item and record it in the report as "already migrated" (this is what makes re-runs safe).
3. Convert and merge per category, following the target doc's write rules.
4. Update the ledger: record every source file you actually read this run as `{ "<source file path>": { "sha256": "...", "run": "<run-id>" } }`. Every file you read belongs here regardless of whether it was classified automatic, approximate, or impossible — the next run needs it for change detection. Files forbidden by security.md are never read, not even to compute a hash, so they are not in the ledger. **Files the source tool doc declares out of scope**, whose contents you therefore never opened (Cursor's `skills-cursor/`, Grok's `GROK.md`), stay out for the same reason — the ledger records what you read and migrated, not everything you laid eyes on. Those files get excluded again by the same rule on the next run, so change detection is unnecessary. The key is the source root resolved to an absolute path joined with the file's relative path — one entry per file, in test mode too. Re-migrating the same file overwrites its entry with the latest run info; no history is kept.

5. Write `.migrate/<run-id>/changes.json` — the record of what this run touched, and the
   only thing that makes the run undoable. Backups alone cannot do it: a backup exists for
   a file you *modified*, and says nothing about a file you *created*. Rolling back from
   backups alone restores the modified files and leaves every copied skill, subagent, and
   command behind.

```json
{
  "run": "<run-id>",
  "root": "<absolute target root>",
  "modified": ["settings.json", "CLAUDE.md"],
  "created": ["skills/hello/SKILL.md", "agents/reviewer.md"],
  "created_dirs": ["skills/hello", "agents"]
}
```

   - Paths are **relative to the root**, so moving the target does not break the record.
   - `modified` lists exactly the files you backed up, and every one of them must have a
     file of the same name under `backup/`. If the two disagree, say so in the report —
     rollback will be partial and the user needs to know before they rely on it.
   - `created` lists files that did not exist before this run. A file you created is not in
     `modified`, and a file you modified is never in `created`; a path in both means you
     lost track of which it was, and the honest fix is to record it as `modified`.
   - `created_dirs` lists directories that did not exist before this run, innermost last, so
     rollback can remove them in reverse order once their files are gone.
   - Write the file even when nothing changed. An empty `modified` and `created` is the
     record that the run was a no-op, and rollback on it correctly does nothing.

If a write fails (JSON parse error and the like): restore that file from the backup, stop the remaining categories, and record the failure point in the report.

### Hook commands that point into the source tool's home

A hook command is a shell string, and it often names a script by absolute path — `/Users/me/.codex/hooks/notify.sh`. Copied unchanged, it runs fine, but the target tool's configuration now depends on the source tool's directory. Uninstall the source and the hook breaks; the dependency is invisible until then.

Do not rewrite the path. You cannot know whether the script is safe to relocate, what else calls it, or whether it reads files beside itself.

Instead, **report every migrated hook whose command references the source tool's home**, quoting the path, and say plainly that the target now depends on it. The user decides whether to copy the script somewhere neutral and update the command. A hook pointing at a shared location outside both homes needs no mention.

### Global-rule merge format (applies to every target)

Every target doc instructs you to write a `## Migrated from <source> (<date>)` section. The format is defined here, once.

- `<source>` is the source token you were given (`claude`, `codex`, `cursor`, `grok`) in **lowercase, verbatim**. Do not expand it into the product's formal name.
- `<date>` is **`YYYY-MM-DD`**. The difference from the run-id format (`YYYYMMDD-HHMMSS`) is deliberate — the heading is for humans to read, and the run-id is already in the report title.
- Give every source rule file its own **`### <filename>` subheading. Add it even when there is only one file** — a format that changes with the file count makes rules untraceable and produces different output run to run.
- Order files the way the source tool actually loads them (alphabetical by filename when the source doc does not say).
- If the source body contains higher-level headings (`# ...`), **leave the body verbatim and do not adjust heading levels.** Inverted heading levels are acceptable; preserving the original takes priority.

**When the target rules file does not exist, create it** containing only the migrated section. Every target doc says to "append to the end of the file", which reads as though a file is always there — in project scope the opposite is normal, since the target tool may never have been used in that repository. Create any missing parent directory too. There is nothing to back up in this case; say so rather than leaving the backup step unexplained.

**Check that the target file is not the source file before writing.** People symlink one rules file to another so several tools share it — `CLAUDE.md -> AGENTS.md` in the same directory is a common arrangement, and project scope makes it likely because source and target live in one root. Appending to a symlink writes through to its destination, so a migration that does not check would copy the source into itself and keep growing on every run.

Before merging, resolve both paths (`readlink -f`, or compare inode and size) and compare:

- **Same file** — write nothing. Report it as already shared: one file already serves both tools, which is the outcome the migration was trying to produce.
- **Target is a symlink somewhere else** — say where in the report before writing, because the edit lands outside the path you were given.
- **Different files** — merge normally.

## Step 5: Report

Write `.migrate/<run-id>/migration-report.md` and print the same content to the user as a summary. Format:

```markdown
# Migration Report: <source> → <target> (<run-id>)

## Scan summary
| Category | Found | Automatic | Approximate | Suggestion | Skipped | Impossible |
|---|---|---|---|---|---|---|
- Write **all nine** checklist categories, one row each. Categories with nothing found still get a `0` (this is where Step 1's "never stay silent" is honored).
- **Skipped** counts items the target already has — a same-name skill, a subagent, an env key with the same value. These are neither failures nor conversions, and forcing them into Impossible misreports a healthy run as a broken one. On a real machine this is often the largest column: 33 subagents skipped because the same plugin is installed on both sides is a normal outcome, not 33 losses.
- Every row must satisfy `Found = Automatic + Approximate + Suggestion + Skipped + Impossible`. If it does not, a category is missing from your accounting.

## Migrated (automatic)
- <category>: <item> → <target location>

In a project-scope run, append the git tracking status to every line that names a file you wrote: `(git tracked: yes)`, `(git tracked: no)`, or `(not a git repository)`. When an outer repository answered rather than the project itself, name it: `(git tracked: no — answered by <outer repo path>)`. Home-scope runs omit this entirely.

## Approximated (review recommended)
- <item>: <what was approximated and how>

## Manual action required
- <item> (<source file path>): <what the user must do> (for secret re-entry, key name and location only)

## Not migrated
- <item> (<source file path>): <reason> (disabled server, keybinding, session, auth, etc.)

Every entry must include the source file path (for example `keybindings.json`, or the server name in `config.toml`). For settings you did not migrate (model name and the like), **quote the current value verbatim** — never name the category and omit the value. For approval/sandbox policy suggestions, give **the source-side field name with its current value** and **the target-side concept name with the suggested value** together (Codex uses `approval_policy` and `sandbox_mode`, Claude `permissions.defaultMode`, Cursor `approvalMode`, Grok `[ui] permission_mode`). Which name plays which role depends on which tool is the source.

## Verification
- <the checks you ran and their results>
```

### Reporting a multi-project run

When several projects were migrated, keep the structure above but repeat it per project under a `## Project: <path>` heading, and open the report with a roll-up:

```markdown
## Projects
| Project | Found | Migrated | Skipped | Failed | Git tracked files touched |
|---|---|---|---|---|---|
| ~/code/app-one | 6 | 5 | 1 | 0 | 2 |
| ~/code/app-two | 3 | 3 | 0 | 0 | 0 |

Scanned to depth 5 from the home directory; <N> projects found, <M> approved.
```

The roll-up is what makes a seventeen-project run reviewable. Put the per-project detail below it, in the order the projects were processed, and write each project's own report into that project's `.migrate/<run-id>/` as well — a repository should carry the record of what was done to it.

Never write a secret's literal value in the report (security.md).

## Approval/sandbox policy approximation table (reference only — never auto-apply, suggest only)

| Automation level | Codex approval_policy + sandbox | Claude defaultMode | Cursor approvalMode | Grok permission_mode |
|---|---|---|---|---|
| 1 — mostly asks | untrusted / read-only | default | allowlist | default(ask) |
| 2 — auto-accepts edits | on-request / workspace-write | acceptEdits | auto-review | acceptEdits |
| 3 — fully permissive | never / danger-full-access | bypassPermissions | unrestricted | bypassPermissions |

**Each value listed here appears once per column** — if the source value is in the table, the reverse lookup is uniquely determined. But **this table does not cover every tool's full value space.** Grok's `permission_mode`, for example, also has `auto`, `dontAsk`, and `plan`, which have no row because no corresponding concept in the other tools has been confirmed. When you hit a value that is not in the table, do not force a match: record the source value and "no corresponding row" in the report, and suggest no target value.

This table lines up each tool's automation levels in the same order; it does not claim the behaviors are identical. Cursor's `allowlist` and `auto-review` differ in whether a classifier is used (allowlist is deterministic; auto-review routes non-allowlisted commands through a sandbox and a classifier), and the correspondence to Claude's modes has never been confirmed by research. That is why this is a **suggestion-only table that must never be auto-applied**.
