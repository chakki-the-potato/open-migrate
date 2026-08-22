# source-codex-project.sh — checks for the source-dependent strings that must appear
# in migration-report.md when Codex was the source of a *project-scope* migration.
#
# Deliberately much smaller than source-codex.sh. The home fixture carries a model
# name, keybindings, and an approval policy;
# a project's .codex/ layer holds none of those, so asserting them here would fail
# for a correct migration.


# Codex ignores a project's .codex/ layer unless ~/.codex/config.toml trusts the path
# (core/tools/codex.md, "Trust gate"). That matters in the other direction — when
# Codex is the *target* — so it is not asserted here. What must hold in this
# direction is only that the report names what it took from the project.
