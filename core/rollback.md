# Rollback (undo one run)

Undo a migration by run-id, returning the target to the state it was in before that run
started. This is a separate entry point, not a step of the five-step procedure — the user asks
for it explicitly.

```
/open-migrate rollback <run-id>
/open-migrate rollback                 list the runs and ask which one
```

security.md still applies in full. Nothing here permits reading a credential file.

## What rollback undoes, and what it cannot

Rollback restores files. It does not un-run anything the migration told the user to run by hand,
and it cannot reach outside the target root.

- **Restored**: every file this run modified, from `backup/`.
- **Removed**: every file this run created, and every directory it created that is now empty.
- **Left alone**: anything the user changed *after* the run. Detecting that is the point of the
  digest check below.
- **Out of reach**: edits the user made themselves by following the report's manual-action list.
  Say so plainly at the end — rollback does not undo those, and the user has to reverse them.

## 0. Resolve the run

- `<root>` is the target root of that run, taken from `changes.json`'s `root` field. If the user
  gave a root, use theirs and say in the summary that it differs from the recorded one — a
  target that moved is a normal thing, a *wrong* target is not, and only the user can tell them
  apart.
- List `<root>/.migrate/*/` when no run-id was given. Show each run's id, its report title, and
  how many files it modified and created. Ask which one; never pick for the user.
- **Roll back the newest run first.** Runs stack: run B may have modified a file run A created.
  Undoing A first leaves B's changes orphaned on a file A's backup does not describe. If the
  requested run is not the newest, name every newer run, say they must come off first, and stop.

## 1. Read the record

Read `<root>/.migrate/<run-id>/changes.json`.

**If it is missing, do not improvise a rollback from the backup directory alone.** A run
predating this file recorded which files it modified but never which it created, so a
backup-only rollback silently leaves every copied skill, subagent, and command in place while
reporting success. Say the run cannot be rolled back automatically, list what `backup/` holds so
the user can restore those files by hand, and stop.

## 2. Check that nothing moved underneath you

For each path in `modified`, compare the file on disk against the corresponding file in
`backup/`. For each path in `created`, check the file still exists.

Three outcomes, and they are decided by the user, not by you:

- **Unchanged since the run** — safe to restore or remove.
- **Changed since the run** — the user has edited it after migrating. Restoring overwrites work
  that has nothing to do with the migration. List every such file with what changed about it
  (size, modification time) and ask, per file, whether to restore it or leave it.
- **Gone** — a `created` file the user already deleted, or a `modified` file that no longer
  exists. Nothing to do for that path; record it and move on.

**Present all of this before touching anything.** Rollback is a destructive operation and gets
the same treatment as Apply: one complete approval up front, nothing written before it, and no
further questions once it starts.

## 3. Restore

In this order:

1. Copy each approved `modified` path back from `backup/`.
2. Delete each approved `created` path.
3. Remove each directory in `created_dirs`, innermost first, and **only when it is empty**. A
   directory holding something this run did not create belongs to the user now.
4. Remove the run's entries from `.migrate/ledger.json` — every entry whose `run` field is this
   run-id. Leaving them makes the next migration skip files that are no longer on the target,
   which is exactly the failure the ledger exists to prevent.
5. Leave `.migrate/<run-id>/` itself in place. It is the record of what happened, and it is what
   made this rollback possible; deleting it destroys the audit trail at the moment it matters
   most. Write the rollback summary into it as `rollback-report.md`.

If any step fails, stop there. Do not continue and do not try to reverse the steps already done
— a half-rolled-back target that reports the truth is recoverable, one that reports success is
not. Say exactly which paths were restored, which were removed, and which were not reached.

## 4. Report

Write `<root>/.migrate/<run-id>/rollback-report.md` and print the same content.

```markdown
# Rollback Report: <run-id> (rolled back <date>)

## Restored from backup
- <path> (<why: unchanged since the run | user approved overwriting later edits>)

## Removed
- <path>
- <directory>/ (empty after removal)

## Left in place
- <path>: <reason — user declined, changed since the run, already gone>

## Not undone by rollback
- <manual action from the original report that the user carried out themselves>

## Ledger
- <N> entries removed; <M> remain from other runs.
```

The **Not undone** section is the one people forget. Copy it from the original run's
"Manual action required" list: those are changes rollback never made and therefore cannot
reverse. A rollback that stays silent about them reads as "everything is back to normal", which
is false whenever the user acted on the report.
