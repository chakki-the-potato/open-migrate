# Development

## Layout

```
core/
  procedure.md       the 5-step procedure (Scan → Plan → Confirm → Apply → Report)
  rollback.md        how to undo a run
  security.md        secret detection and handling policy
  tools/*.md         per-tool knowledge docs — how to read it, how to write into it
  tools/_template.md fill this in to add a tool

adapters/open-migrate/SKILL.md    the entry point

skills/            BUILD ARTIFACT — generated from adapters/ and core/
scripts/           build, install, seed, verify
test/fixtures/     one source fixture per tool
scripts/checks/    one target verifier and one source check per tool
```

There are **no per-direction converters**. A direction is one tool's read rules paired with
another's write rules, resolved at run time. Twelve directions, eight files.

## `skills/` is generated — never edit it

The plugin loader looks for `skills/` at the repository root, so the built distribution has to be
committed. The sources of truth are `adapters/open-migrate/SKILL.md` and `core/`.

```
./scripts/build-plugin.sh           regenerate the distribution
./scripts/build-plugin.sh --check   exit 1 if it drifted (CI runs this)
claude plugin validate . --strict   validate the manifests
```

## Bump the version whenever shipped content changes

Plugin managers compare version numbers, not content. Without a bump, `claude plugin update`
reports "already at the latest version" and keeps serving the stale cache no matter how much
changed. `./scripts/check-version-bump.sh` enforces this in CI.

This has silently invalidated end-to-end runs more than once.

## Do not keep the plugin enabled while developing

With both installed there are two skills of the same name — the fresh one from `./install.sh` and
the plugin's cache, which lags until you push, bump, and update. Which one loads is not
predictable, and the stale copy silently lacks whatever you just wrote.

```
claude plugin disable open-migrate@migrate-marketplace   # develop against ./install.sh
claude plugin enable open-migrate@migrate-marketplace    # restore when done
```

A live session shows which copy it loaded in the skill's header path. Check it before trusting a
test result.

## Testing

The migration itself is model-driven, so CI cannot run the twelve directions. What CI does run:
shell syntax, shellcheck, distribution drift, the version bump rule, fixture parsing, a
secret-shape scan, and the seed probe — which asserts a seeded-but-unmigrated target *fails* the
suite while still passing the preserved-content checks.

To run a direction by hand, see [verification.md](verification.md).

## Adding a tool

1. Copy `core/tools/_template.md` and fill in the read inventory and write rules.
2. Add one source fixture under `test/fixtures/<tool>-home/`.
3. Add one target verifier `scripts/checks/target-<tool>.sh` and one source check
   `scripts/checks/source-<tool>.sh`.
4. Add the tool to `scripts/seed-target.sh` so its pre-migration state is reproducible.

That is three files and a seed case, and it buys eight new directions. Nothing is written per
direction.

## Writing a check

Two rules keep the suite honest.

**Measure it failing first.** Add the check, run it against the un-migrated target, and confirm
it fails for the reason you expect. A check that passes the moment you write it is testing
nothing — several have been caught this way.

**Keep source checks target-agnostic.** `scripts/checks/source-*.sh` is combined with every
target verifier, so it may only use what `_common.sh` exports (`mig_dir`, `chk`, `chk_not`,
`$TARGET`). Referencing a variable that a particular `target-*.sh` defines makes the file safe
only in that one pairing, and any other combination dies on a `set -u` error.
