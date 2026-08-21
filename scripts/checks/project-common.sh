# project-common.sh — checks that apply to any project-scope migration, regardless
# of which tools are involved. Sourced only when SCOPE=project. Uses TARGET (the
# project root), mig_dir, and chk/chk_not from _common.sh.

# The vendor-neutral path is read natively by some tools. Whether it was migrated
# depends on the target, so target-*-project.sh decides — this file only asserts
# that the source copy was left alone.
chk "vendor-neutral path untouched" test -f "$TARGET/.agents/skills/shared-skill/SKILL.md"

# The project ledger lives in the project, not in a home directory.
chk "project ledger in project root"  test -f "$TARGET/.migrate/ledger.json"

# Git status has to be reported, not acted on. The migration must never create a
# commit — a repository left mid-commit would be worse than one left dirty.
#
# Only meaningful when the project root is itself the top of a repository. Without
# that guard `git -C` walks upward and finds the enclosing repo's commits, which
# have nothing to do with the migration.
chk_not "no commit created by migration" sh -c '
  top=$(git -C "$0" rev-parse --show-toplevel 2>/dev/null) || exit 1
  [ "$top" = "$(cd "$0" && pwd)" ] || exit 1
  git -C "$0" log --oneline -1 --since="10 minutes ago" 2>/dev/null | grep -q .
' "$TARGET"
