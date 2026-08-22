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

## Goldens: what CI can and cannot catch

Everything above is measured by hand. The migration is performed by an agent reading `core/`,
so CI cannot re-run it — which left a hole: **every automated check in this repository tests the
verifier, not the conversion.** A wrong edit to `core/tools/claude.md` shipped green.

A golden closes it. `test/golden/<direction>/` holds a real migrated target, committed, together
with `manifest.json` recording the sha256 of exactly the docs that direction depends on — the
three shared ones plus its two tool docs. `check-golden-fresh.sh` recomputes those hashes on every
build. A doc that moves ahead of the output it produced fails the build until the affected
directions are re-run and re-frozen.

Pinning is per direction on purpose. Editing `core/tools/cursor.md` marks the six Cursor
directions stale and leaves the other six alone; a blunt all-or-nothing gate is the kind people
stop honoring.

**All twelve directions and project scope are frozen**, so a doc edit cannot reach `main` without
the affected outputs being re-measured. When a direction is missing the gate says so by name on
every build — a partially frozen manifest otherwise reads as full coverage, which is the exact
failure this whole thing exists to prevent. The expected set is derived from `core/tools/`, so
adding a fifth tool widens the reported gap rather than hiding inside it.

One property the gate does not have, stated so nobody assumes otherwise: it cannot tell a
*correct* regeneration from a careless one. It proves the golden was produced by the current
docs, not that whoever produced it was paying attention.

### Regenerating one

```
./scripts/seed-target.sh claude /tmp/g          # the pre-migration state
/open-migrate codex claude                      # pointed at /tmp/g
./scripts/verify-migration.sh /tmp/g claude codex
./scripts/freeze-golden.sh codex claude /tmp/g
```

**Read `core/` from this repository, never the installed skill.** An installed copy lags behind
until you push, bump, and update, so a golden generated against it gets pinned to repository
hashes it was not produced from — the one failure this gate cannot detect, because the manifest
would look correct. This is not hypothetical: the first golden was nearly generated against an
installed `procedure.md` two commits old. It stays true after the fact — the copy sitting in
`~/.grok` was later found lagging `core/procedure.md` by one commit (e8765be, which replaced the
MCP rationale) while its `SKILL.md` still matched the repository. An installed tree can look
current at the surface the tool reads first and be stale underneath.

`freeze-golden.sh` refuses a target holding more than one run, and refuses a run whose report says
"already migrated" — a ledger no-op would freeze an empty diff as the expected output and every
content check would pass against a target that never changed. Absolute paths in the run artifacts
are rewritten to `<REPO>` and `<TARGET>` so the tree is identical on every machine.

## What is not covered

- **A Cursor source has no secret-report coverage.** Its only secret-bearing surface was
  `mcp.json`, and MCP is no longer migrated; Cursor has no environment-variable surface to move
  the case into. The gap is structural, not an omission. Every other source carries a
  secret-shaped value and a check that its key name reaches the report.
- **Grok Build finds the installed skill; no migration has been driven from inside it.** A
  headless `grok -p` session lists `open-migrate` among its skills and returns its description,
  opening verbatim from `adapters/open-migrate/SKILL.md`, so the install lands where Grok looks.
  That is discovery, not execution: it shows the path is read and the frontmatter parsed, and says
  nothing about whether `core/*.md` resolves when the skill is actually invoked. Every direction in
  the table above was driven from another tool, and the conversion itself remains verified in both
  directions.
- **Codex CLI's full round trip is unverified.** `plugin list` reports it installed and enabled;
  nothing beyond that was checked.
