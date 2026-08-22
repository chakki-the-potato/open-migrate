# Verification

Every number here was measured by running the verifier against a target that had really been
migrated. Nothing is estimated.

## The twelve directions

| From \ To | Claude | Codex | Cursor | Grok |
|---|---|---|---|---|
| **Claude** | — | 56 | 55 | 63 |
| **Codex** | 77 | — | 73 | 81 |
| **Cursor** | 54 | 51 | — | 56 |
| **Grok** | 56 | 53 | 55 | — |

The numbers are how many checks that direction runs. All of them pass.

Project scope is verified separately at 36 checks.

## Why the verifier is not rubber-stamping

Three controls, all of which must keep failing:

- An **empty target** fails 43 home-scope checks and 29 project-scope checks.
- A **seeded target that was never migrated** fails 41 to 51 checks, depending on the tool, while
  still passing the "existing content survived" checks. That combination is the point: if a seed
  passed everything, the suite would be asserting nothing about the migration itself. CI enforces
  it on every push.
- Every new check is **measured failing before the fixture is migrated**, then passing after. A
  check that passes the moment it is written is testing nothing.

## Why the Codex column is bigger

That fixture carries the cases a real `~/.codex` turned up:

- three argv-prefix rules that cannot become target permissions — one holding a quote and
  parentheses, one holding whitespace, one whose joined form runs past 200 characters
- a hook field outside the shared structure (`statusMessage`)
- a native Codex tool-name matcher (`read_file`)
- a matcher that is a regex alternation mixing several vocabularies
- a hook command pointing into Codex's own directory
- a secret-shaped environment value and a digest-shaped one

Each has a check asserting the rule was honored **and** that the report says so. Skipping
something silently is as much a failure as converting it wrong.

## The dry run against real configuration

Fixtures are small and tidy; real config is neither. One dry run read an actual `~/.codex` and
wrote into a temporary directory — source read, never written.

That machine held 353 permission rules, 33 subagents, 6 MCP servers, 24 plugins and 46 trusted
projects. Results:

| | |
|---|---|
| Permission rules | 353 found → 104 converted, 249 skipped (203 quote/paren, 45 whitespace, 1 over-length) |
| Longest resulting entry | 168 characters, none over 200 |
| Digest handling | a real `NODE_REPL_TRUSTED_..._SHA256S` value carried verbatim, not redacted |
| Hook dependencies | 5 commands pointing into the source home, each flagged |
| Subagents | 33 converted, none rejected |
| Skills | 3 user skills copied, `skills/.system/` excluded |
| Secrets | no secret shape in the output, no trace of `auth.json` |

For comparison, the version before the permission guard produced 334 entries from the same
source, 43 of them over 200 characters, the longest 806 — none of which could ever match.

That run is also what found the missing rule for alternation matchers.

## Running it yourself

Seed a target first, then migrate into it:

```
./scripts/seed-target.sh claude /tmp/t          # the pre-migration state
/open-migrate codex claude                      # migrate, destination /tmp/t
./scripts/verify-migration.sh /tmp/t claude codex
```

The seed step matters. Half the checks assert that content already on the target survived the
merge, and against an empty directory those pass for the wrong reason. Seeding is also what makes
the suite runnable from a clean checkout — the target directories themselves are not committed.

To check a rollback, compare against a fresh seed:

```
./scripts/verify-rollback.sh /tmp/t claude <run-id>
```

A rolled-back target must be byte-identical to a seed, `.migrate/` excluded.

## What is not covered

- **A Cursor source has no secret-report coverage.** Its only secret-bearing surface was
  `mcp.json`, and MCP is no longer migrated; Cursor has no environment-variable surface to move
  the case into. The gap is structural, not an omission. Every other source carries a
  secret-shaped value and a check that its key name reaches the report.
- **Grok Build has never been verified on a real install.** The conversion is verified in both
  directions; whether Grok loads the installed skill was never confirmed.
- **Codex CLI's full round trip is unverified.** `plugin list` reports it installed and enabled;
  nothing beyond that was checked.
