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

The rule is mechanical: if your diff touches `core/`, `adapters/open-migrate/`, `skills/`, `bin/`,
or `package.json`, bump the version. Changes to `docs/`, `test/`, `scripts/`, or the README do not
reach an installed copy and need no bump. `./scripts/check-version-bump.sh` decides this the same
way in CI.

The version lives in two manifests — `.claude-plugin/plugin.json` for the plugin and
`package.json` for npm — two release surfaces for the same content. Move both. CI compares them
before it looks at what the diff touched, so a commit that moves only one fails even when nothing
shipped changed, and a release tag matching only one makes `publish.yml` refuse.

### 3. CI does not test the migration itself

The migration is model-driven, so no runner can execute it. Nothing in CI converts anything. What
is frozen instead is its output: the twelve home-scope directions plus project scope, thirteen
golden trees under `test/golden/`.

What CI can do is refuse to build until *you* produce the new output. Every golden under
`test/golden/` is pinned to the sha256 of the knowledge docs that produced it — `core/procedure.md`,
`core/security.md`, `core/rollback.md`, and the two tool docs for that direction. Edit one and the
directions it feeds go stale, and `check-golden-fresh.sh` fails naming them.

Pinning is per direction, so you only re-run what you actually invalidated. Editing
`core/tools/cursor.md` marks the six Cursor directions stale and leaves the rest alone; editing
`core/procedure.md` marks all thirteen.

**So a `core/` change is not finished until the affected goldens are re-frozen and committed.**

```
./scripts/seed-target.sh claude /tmp/g                  # the pre-migration state
/open-migrate codex claude                              # migrate, destination /tmp/g
./scripts/verify-migration.sh /tmp/g claude codex       # confirm it is correct
./scripts/freeze-golden.sh codex claude /tmp/g          # add `project` as a 4th arg for project scope
```

Five things silently produce a worthless golden.

- **Seeding is not optional**, and now for two reasons. Half the verifier's checks assert that
  content already on the target survived the merge, and against an empty directory those pass for
  the wrong reason. On top of that, `freeze-golden.sh` refuses a run whose report says "already
  migrated" — freezing a ledger no-op would pin an empty diff as the expected output, after which
  every content check passes against a target that never changed. It also refuses a target holding
  more than one run under `.migrate/`.
- **Read `core/` from the repository, never from an installed skill.** An installed copy lags until
  someone pushes, bumps, and updates. A golden produced against a stale doc gets pinned to
  repository hashes it did not come from, and the manifest still looks correct. The gate cannot
  detect this, and it has already come close once — the installed `procedure.md` had already
  fallen behind when the first golden was generated, caught by hand. How far was never measured.
- **Do not let the run read `test/golden/`.** An agent regenerating from inside this checkout can
  read the golden it is about to replace, and one that finds the expected output will match it.
  The result passes everything for the wrong reason — the gate compares doc hashes, the verifier
  compares rules, and neither can tell a conversion that followed `core/` from one that copied the
  answer. This is the only one of the five where the golden comes out correct, and reading `core/`
  from the repository does not help — a golden is not an input to the run, it is what the run is
  being measured against. Regenerate from a checkout without `test/golden/`, or a worktree with
  that path removed. Observed, not hypothetical.
- **Verify before you freeze.** `freeze-golden.sh` records whatever is in the directory. A wrong
  migration frozen as the golden becomes the expected answer.
- Absolute paths are rewritten to `<REPO>` and `<TARGET>` at freeze time so goldens are identical
  on every machine. Nothing to do — it just means a diff full of home directories is a bug.

See [docs/verification.md](docs/verification.md) for the per-direction table.

## What this project takes

- **Fixes to a tool's read or write rules** — a field that migrates wrong, a matcher that does not
  round-trip, a path that moved when an editor changed its layout.
- **A new tool.** One knowledge doc, one fixture, one verifier, one seed case — and it buys eight
  new directions. See [Adding a tool](docs/development.md#adding-a-tool). The expected direction
  set is derived from `core/tools/`, so the moment the doc lands `check-golden-fresh.sh` reports
  eight unfrozen directions by name. They cannot be quietly forgotten.
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
./scripts/check-version-bump.sh origin/main        version rule, and both manifests agreeing
./scripts/check-golden-fresh.sh                    no golden left behind by a doc edit
bash -n install.sh scripts/*.sh                    shell syntax
shellcheck -S warning -e SC1090,SC1091 \
  install.sh scripts/build-plugin.sh scripts/check-version-bump.sh \
  scripts/seed-target.sh scripts/verify-migration.sh \
  scripts/freeze-golden.sh scripts/check-golden-fresh.sh
```

Then, if the diff touches `core/`, the re-run and re-freeze from point 3 above.

## What CI runs

Twelve checks, all in [.github/workflows/ci.yml](.github/workflows/ci.yml).

| Check | Fails when |
| --- | --- |
| Shell syntax | any script under `scripts/` or `install.sh` does not parse |
| shellcheck | a standalone script trips a warning-level rule |
| Distribution matches sources | `skills/` was edited directly, or the build was not re-run |
| Version bumped | shipped content changed without a bump, or the two manifests disagree |
| Fixtures parse | a fixture's JSON or TOML is malformed |
| Goldens match the knowledge docs that produced them | a pinned doc's hash moved, a manifest entry has no golden tree, or a golden tree has no manifest entry |
| Goldens still pass the verifier | `verify-migration.sh` reports a FAIL against any frozen tree |
| Seed produces a target the verifier rejects | the seed passes the suite, meaning the checks assert nothing |
| npx installer puts the payload in place | `bin/open-migrate.js` does not install what it claims to |
| Packaged contents are only what ships | the npm tarball gained or lost a file |
| Seed refuses a real tool home | the seed script can write into `~/.claude` and friends |
| No real secret shapes committed | a value matching a real key prefix reached the repository |

Two are worth understanding beyond their names.

**The seed probe** seeds an unmigrated target and asserts the verifier *fails* it while the
preserved-content checks still pass. A suite that goes green against an unmigrated target is
testing nothing.

**The golden gate** is the only thing standing between a knowledge-doc edit and a broken
migration, because everything else here tests the verifier rather than the conversion. It cannot
check that your new output is right — only that somebody produced one. Whether it is correct is
what `verify-migration.sh` and your review are for.

## Reporting a bug

Include the direction (`codex → claude`), the versions of both tools, and the run id from
`.migrate/`. The report generated by the run is usually enough to reproduce.

Do not paste config that carries secrets. Key names and structure are what matter.

## Security

Do not open a public issue for a vulnerability. See [SECURITY.md](SECURITY.md).

## License

Contributions are accepted under the [MIT License](LICENSE).
