# Migration Procedure (5 steps — follow in order)

Before you start, confirm you have read all three: the source tool doc (`core/tools/<source>.md`), the target tool doc (`core/tools/<target>.md`), and `core/security.md`. If any is unread, read it now.

## Precedence when docs conflict

When two docs give different instructions for the same item, resolve it in this order. Do not guess, and do not pick whichever sounds more reasonable.

1. **security.md always wins.**
2. **The target doc wins on write location and format.** Even if the source doc names a destination ("move it to the target's command file"), follow the target doc when it defines that category differently ("migrate as a skill, not a command"). The source doc is authoritative on how to **read and interpret** the source; the target doc is authoritative on **where and in what shape** the result is written.
3. **A specific rule beats a general one.** When a general instruction ("copy the whole directory") collides with a specific one ("this key is invalid on the target, drop it"), follow the specific one.
4. If it is still ambiguous, **do not migrate it.** Put the original in the manual-action list and record the conflict in the report.

## Path resolution in test mode (applies to every tool)

If the target (or source) root is not that tool's real home, you are in test mode. Substitute the root for every home path the tool docs mention — `~/.cursor/mcp.json` becomes `<root>/mcp.json`, `~/.grok/config.toml` becomes `<root>/config.toml`. Files that live **outside** the home directory (such as Claude's `~/.claude.json`) fold **inside** the root: `<root>/.claude.json`.

**Never read files from the real home in test mode.** Pulling the user's actual configuration into a test run corrupts the result. If the root has no corresponding file, record it as "scope not present", count it as 0, and note it in the report.

Generate the run-id now, in `YYYYMMDD-HHMMSS` format. This run's artifacts (backups, report, MCP commands) go in `<target root>/.migrate/<run-id>/`. The one exception is the ledger `ledger.json`, which is shared across runs and lives at `<target root>/.migrate/ledger.json`.

## Category checklist (walk all of it, every run)

1. Global rules  2. MCP servers  3. Skills  4. Commands/prompts  5. Subagents  6. Hooks
7. Permission rules  8. Env injection  9. Approval/sandbox policy  10. Non-migratable items (keybindings, sessions, auth, model, etc.)

If the source tool doc's inventory table lists a surface that is missing from this checklist, do not skip it for being absent here — add it as an item, process it, and note it in the report.

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

## Step 4: Apply

Process only approved categories, in this order.

1. Create `.migrate/<run-id>/backup/` and back up every existing file you are about to modify.
2. Check the ledger: if `<target root>/.migrate/ledger.json` already records the sha256 of a source file, skip that item and record it in the report as "already migrated" (this is what makes re-runs safe).
3. Convert and merge per category, following the target doc's write rules.
4. Update the ledger: record every source file you actually read this run as `{ "<source file path>": { "sha256": "...", "run": "<run-id>" } }`. Every file you read belongs here regardless of whether it was classified automatic, approximate, or impossible — the next run needs it for change detection. Files forbidden by security.md are never read, not even to compute a hash, so they are not in the ledger. **Files the source tool doc declares out of scope**, whose contents you therefore never opened (Cursor's `skills-cursor/`, Grok's `GROK.md`), stay out for the same reason — the ledger records what you read and migrated, not everything you laid eyes on. Those files get excluded again by the same rule on the next run, so change detection is unnecessary. The key is the source root resolved to an absolute path joined with the file's relative path — one entry per file, in test mode too. Re-migrating the same file overwrites its entry with the latest run info; no history is kept.

If a write fails (JSON parse error and the like): restore that file from the backup, stop the remaining categories, and record the failure point in the report.

### Global-rule merge format (applies to every target)

Every target doc instructs you to write a `## Migrated from <source> (<date>)` section. The format is defined here, once.

- `<source>` is the source token you were given (`claude`, `codex`, `cursor`, `grok`) in **lowercase, verbatim**. Do not expand it into the product's formal name.
- `<date>` is **`YYYY-MM-DD`**. The difference from the run-id format (`YYYYMMDD-HHMMSS`) is deliberate — the heading is for humans to read, and the run-id is already in the report title.
- Give every source rule file its own **`### <filename>` subheading. Add it even when there is only one file** — a format that changes with the file count makes rules untraceable and produces different output run to run.
- Order files the way the source tool actually loads them (alphabetical by filename when the source doc does not say).
- If the source body contains higher-level headings (`# ...`), **leave the body verbatim and do not adjust heading levels.** Inverted heading levels are acceptable; preserving the original takes priority.

## Step 5: Report

Write `.migrate/<run-id>/migration-report.md` and print the same content to the user as a summary. Format:

```markdown
# Migration Report: <source> → <target> (<run-id>)

## Scan summary
| Category | Found | Automatic | Approximate | Suggestion | Impossible |
|---|---|---|---|---|---|
- Write **all ten** checklist categories, one row each. Categories with nothing found still get a `0` (this is where Step 1's "never stay silent" is honored).

## Migrated (automatic)
- <category>: <item> → <target location>

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

Never write a secret's literal value in the report (security.md).

## Approval/sandbox policy approximation table (reference only — never auto-apply, suggest only)

| Automation level | Codex approval_policy + sandbox | Claude defaultMode | Cursor approvalMode | Grok permission_mode |
|---|---|---|---|---|
| 1 — mostly asks | untrusted / read-only | default | allowlist | default(ask) |
| 2 — auto-accepts edits | on-request / workspace-write | acceptEdits | auto-review | acceptEdits |
| 3 — fully permissive | never / danger-full-access | bypassPermissions | unrestricted | bypassPermissions |

**Each value listed here appears once per column** — if the source value is in the table, the reverse lookup is uniquely determined. But **this table does not cover every tool's full value space.** Grok's `permission_mode`, for example, also has `auto`, `dontAsk`, and `plan`, which have no row because no corresponding concept in the other tools has been confirmed. When you hit a value that is not in the table, do not force a match: record the source value and "no corresponding row" in the report, and suggest no target value.

This table lines up each tool's automation levels in the same order; it does not claim the behaviors are identical. Cursor's `allowlist` and `auto-review` differ in whether a classifier is used (allowlist is deterministic; auto-review routes non-allowlisted commands through a sandbox and a classifier), and the correspondence to Claude's modes has never been confirmed by research. That is why this is a **suggestion-only table that must never be auto-applied**.
