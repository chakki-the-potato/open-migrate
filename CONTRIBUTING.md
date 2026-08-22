# Contributing

Bug reports, corrections to a tool's config knowledge, and new tools are all welcome.

Read the next section first. Three properties of this repository break otherwise-correct pull
requests, and CI can only catch two of them.

## Three things that will break your pull request

### 1. `skills/` is a build artifact — never edit it

The plugin loader looks for `skills/` at the repository root, so the built distribution has to be
committed. It is generated from `adapters/open-migrate/SKILL.md` and `core/`, which are the
sources of truth. An edit made directly in `skills/` is overwritten by the next build and fails
CI immediately.

```
./scripts/build-plugin.sh           regenerate the distribution
./scripts/build-plugin.sh --check   exit 1 if it drifted — CI runs this
```

### 2. Bump the version when shipped content changes

Plugin managers compare version numbers, not content. Ship a change without a bump and
`claude plugin update` reports "already at the latest version" and keeps serving the stale cache.
This has silently invalidated end-to-end runs more than once.

The rule is mechanical: if your diff touches `core/`, `adapters/open-migrate/`, or `skills/`,
bump `version` in `.claude-plugin/plugin.json`. Changes to `docs/`, `test/`, `scripts/`, or the
README do not reach an installed copy and need no bump. `./scripts/check-version-bump.sh` decides
this the same way in CI.

### 3. CI does not test the migration itself

The migration is model-driven, so no runner can execute the twelve directions. CI checks shell
syntax, distribution drift, the version rule, fixture parsing, secret shapes, and the seed probe
— it never converts anything.

That means **a change to `core/tools/*.md` can break a real migration while CI stays green.** If
your diff touches `core/`, run the affected directions by hand and paste the verifier output into
the pull request:

```
./scripts/seed-target.sh claude /tmp/t          # the pre-migration state
/open-migrate codex claude                      # migrate, destination /tmp/t
./scripts/verify-migration.sh /tmp/t claude codex
```

Seeding is not optional. Half the checks assert that content already on the target survived the
merge, and against an empty directory those pass for the wrong reason. See
[docs/verification.md](docs/verification.md) for the full procedure and the per-direction table.

## What this project takes

- **Fixes to a tool's read or write rules** — a field that migrates wrong, a matcher that does not
  round-trip, a path that moved when an editor changed its layout.
- **A new tool.** One knowledge doc, one fixture, one verifier, one seed case — and it buys eight
  new directions. See [Adding a tool](docs/development.md#adding-a-tool).
- **Checks.** The verifier is the only thing between a knowledge-doc edit and a silent regression,
  so more of it is better. See [Writing a check](docs/development.md#writing-a-check) — a check
  has to be measured failing before it counts.
- **Documentation** that is wrong, stale, or assumes knowledge a first-time reader lacks.

## What it does not take

These are decisions rather than gaps. A pull request against one is likely to be declined, so
open an issue first if you disagree.

- **MCP server registration.** Deliberately out of scope: adding a server changes what an editor
  can reach, and server definitions routinely carry API keys.
- **Anything that reads or copies a credential.** [core/security.md](core/security.md) overrides
  every other step, including a user's explicit request.
- **Per-direction converters.** A direction is one tool's read rules paired with another's write
  rules, resolved at run time. Twelve directions, eight files. A converter written for a single
  pair reintroduces the N-squared problem the design exists to avoid.
- **Deleting or overwriting anything on the target.** Same-name skills and subagents are skipped
  and reported, never replaced.

## Setup

```
git clone https://github.com/chakki-the-potato/open-migrate
cd open-migrate
./install.sh
```

Disable the published plugin while you develop. With both installed there are two skills of the
same name — the fresh one from `./install.sh` and the plugin's cache, which lags until you push,
bump, and update. Which one loads is not predictable.

```
claude plugin disable open-migrate@migrate-marketplace   # develop against ./install.sh
claude plugin enable open-migrate@migrate-marketplace    # restore when done
```

A live session shows which copy it loaded in the skill's header path. Check it before trusting a
test result.

[docs/development.md](docs/development.md) covers the repository layout and how the pieces fit.

## Branches and commits

Branch names take a type prefix and kebab-case: `feat/`, `fix/`, `docs/`, `chore/`, `test/`,
`refactor/`.

Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/). One commit is
one logical unit — say what changed and why it was wrong, not what file you touched.

```
fix: rollback could not tell a user's later edit from its own write
docs: name the command a plugin install actually answers to
```

No AI attribution lines, no emoji.

## Before you open a pull request

```
./scripts/build-plugin.sh --check                  distribution matches sources
./scripts/check-version-bump.sh origin/main        version rule
bash -n install.sh scripts/*.sh                    shell syntax
shellcheck -S warning -e SC1090,SC1091 \
  install.sh scripts/build-plugin.sh scripts/check-version-bump.sh \
  scripts/seed-target.sh scripts/verify-migration.sh
```

Then, if the diff touches `core/`, the hand-run from point 3 above.

## What CI runs

Eight checks, all in [.github/workflows/ci.yml](.github/workflows/ci.yml).

| Check | Fails when |
| --- | --- |
| Shell syntax | any script under `scripts/` or `install.sh` does not parse |
| shellcheck | a standalone script trips a warning-level rule |
| Distribution matches sources | `skills/` was edited directly, or the build was not re-run |
| Version bumped | shipped content changed without a version bump |
| Fixtures parse | a fixture's JSON or TOML is malformed |
| Seed produces a target the verifier rejects | the seed passes the suite, meaning the checks assert nothing |
| Seed refuses a real tool home | the seed script can write into `~/.claude` and friends |
| No real secret shapes committed | a value matching a real key prefix reached the repository |

The seed probe is the one worth understanding. It seeds an unmigrated target and asserts the
verifier *fails* it while the preserved-content checks still pass. A suite that goes green against
an unmigrated target is testing nothing.

## Reporting a bug

Include the direction (`codex → claude`), the versions of both tools, and the run id from
`.migrate/`. The report generated by the run is usually enough to reproduce.

Do not paste config that carries secrets. Key names and structure are what matter.

## Security

Do not open a public issue for a vulnerability. See [SECURITY.md](SECURITY.md).

## License

Contributions are accepted under the [MIT License](LICENSE).
