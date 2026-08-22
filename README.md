# open-migrate

Move your settings in one step when you switch AI coding tools. It reads rules, skills, subagents, hooks, permissions, and environment variables from the source tool and converts them into the destination tool's format.

Four tools are supported — **Claude Code, Codex CLI, Cursor, and Grok Build** — for 12 possible directions.

## How it works

There are no 12 per-direction converters. Each tool gets a single knowledge doc describing "how to read my config" and "how to write into me", and the AI combines the source doc with the destination doc to do the conversion. Adding a tool adds one doc and 2N directions.

```
core/
  procedure.md      the 5-step procedure (Scan → Plan → Confirm → Apply → Report)
  security.md       secret detection and handling policy
  tools/*.md        per-tool knowledge docs (read rules and write rules, both sides)
adapters/*/SKILL.md per-tool entry points (thin shells that differ only in destination)
```

## Install

### Claude Code and Codex CLI — plugin

Both tools install the same package without conversion, but their commands differ.

**Claude Code** — inside a session:

```
/plugin marketplace add chakki-the-potato/open-migrate
/plugin install open-migrate@migrate-marketplace
```

or from the shell:

```
claude plugin marketplace add chakki-the-potato/open-migrate
claude plugin install open-migrate@migrate-marketplace
```

**Codex CLI** — from the shell. It needs the full URL, and the `@marketplace` qualifier is required on install:

```
codex plugin marketplace add https://github.com/chakki-the-potato/open-migrate
codex plugin add open-migrate@migrate-marketplace
```

The plugin distribution determines which tool it is running in and uses that as the destination.

**Updating** also differs. Claude Code has a one-step update; Codex has no `plugin update` — refresh the marketplace snapshot first, then reinstall.

```
claude plugin update open-migrate@migrate-marketplace

codex plugin marketplace upgrade migrate-marketplace
codex plugin add open-migrate@migrate-marketplace
```

### Cursor and Grok Build — install script

```
git clone https://github.com/chakki-the-potato/open-migrate.git
cd open-migrate
./install.sh cursor    # → ~/.cursor/skills/open-migrate
./install.sh grok      # → ~/.grok/skills/open-migrate  (honors GROK_HOME)
```

`./install.sh claude` and `./install.sh codex` exist too, for installing as a personal skill instead of a plugin. Pick one method per tool — installing both leaves two skills named `migrate` in the same home.

If Grok Build is not installed yet: `curl -fsSL https://x.ai/cli/install.sh | bash`.

### Upgrading from `/migrate`

The command used to be `/migrate`, which never said whether `codex` meant the source or the destination. It is now `/open-migrate` and takes both.

`./install.sh` removes the old skill for you. Plugin installs need the old one removed by hand, since the plugin itself was renamed:

```
claude plugin uninstall migrate@migrate-marketplace
claude plugin install open-migrate@migrate-marketplace

codex plugin remove migrate
codex plugin marketplace upgrade migrate-marketplace
codex plugin add open-migrate@migrate-marketplace
```

Leaving the old one installed means two commands answer, one of them stale.

### Install status verified

Installation and skill loading were checked on a real machine, not just in tests.

| Tool | Install | Skill loads | Invoke as |
|---|---|---|---|
| Claude Code | plugin | verified — a live session lists `open-migrate` | `/open-migrate` |
| Codex CLI | plugin | loader confirmed (`plugin list` reports `installed, enabled`), full round trip unverified | `/open-migrate` |
| Cursor | `./install.sh cursor` | verified — `cursor-agent` lists `open-migrate` | `/open-migrate` |
| Grok Build | `./install.sh grok` | verified — `grok inspect` lists it | `/open-migrate` |

Grok Build has a built-in `/migrate`, which is part of why this command is named `/open-migrate` — the names no longer collide, so it stays unqualified everywhere.

### A caution about compatibility loading

Grok Build reads `~/.claude/skills/` and `~/.codex/skills/`, and Cursor reads `.claude/skills/` and `.codex/skills/`. That means **a plugin installed for Claude also shows up inside Grok and Cursor**, namespaced (`/open-migrate:open-migrate`).

Prefer the entry point installed for the tool you are actually using. The plugin distribution determines its destination at runtime and asks rather than guessing when it cannot confirm which tool it is running in — but the destination-specific entry point from `./install.sh <dest>` has its destination fixed, so it cannot be confused at all.

## Usage

```
/open-migrate                  ask which tools
/open-migrate codex claude     source first, then destination
/open-migrate rollback         list runs and undo one
```

Both tools are inputs, so the direction is never in doubt — and you can migrate **into a tool you have not installed yet.** Running inside Claude, you can prepare a `~/.grok` before you switch to Grok, which is usually the order people actually do it in.

Natural language works as well: "move my codex settings into claude" carries the same two values.

A run shows you a plan table and **writes nothing until you approve it.** After approval, `<target home>/.migrate/<run-id>/migration-report.md` records what moved and how.

Expect approval prompts beyond that one. Settings files are sensitive by nature, so the host tool asks before writing `settings.json`, `config.toml`, and similar — that is the tool protecting you, not the migration misbehaving. Approving each is normal; declining one leaves that category unmigrated and noted in the report.

### Project configuration

Repositories carry their own configuration — `CLAUDE.md`, `.claude/`, `.codex/`, `.cursor/rules/`, and so on. Name a project and it migrates that too.

```
migrate my codex settings, and the project config in ~/code/my-app too
```

Project scope differs from home scope in three ways worth knowing.

- **Source and target are the same directory.** `<repo>/.codex/` becomes `<repo>/.claude/` in place.
- **The diff is usually tracked by git.** The report tells you which files git tracks — and, in a monorepo, which repository answered — so you can see what a push would share with your team. The migration never stages or commits anything.
- **Each project keeps its own ledger** at `<repo>/.migrate/ledger.json`, so re-running is safe per project.

Or ask for all of them:

```
migrate my codex settings, including every project on this machine
```

Discovery scans the home directory to depth 5 and excludes what is not a project: every dotdirectory directly under the home (that is where plugin caches and tool state live), `node_modules`, `Library`, `.Trash`, and repository internals. On the machine this was measured against, that turns 38 raw matches into 17 real projects.

**Being a git repository is not the test** — 13 of the 25 git repositories found were plugin marketplace clones, which are themselves repos. Git status is reported, never used to decide.

You see the full list before anything is written, and approve the set at once. Nested projects count separately: a package inside a monorepo that carries its own config gets its own migration and its own ledger.

Nothing is discovered unless you ask for it. Name one project and only that one is touched.

Two surfaces need extra care and the report calls both out.

- **Codex project config is trust-gated.** Codex ignores a project's `.codex/` layer unless `~/.codex/config.toml` trusts that path. The report gives you the exact TOML to add; the migration will not add it for you, because trusting a repository is your decision.
- **`.agents/skills/` is already shared.** Cursor and Grok read that vendor-neutral path natively, so skills there are reported as "already being read" rather than copied. Claude and Codex do not read it, so for those targets it migrates — and since the original is never deleted, the report names any skill that ends up visible twice.

## Verified directions

Each direction was scored by a deterministic verifier after actually migrating a fixture. These are measured results.

**All twelve directions pass.**

| From \ To | Claude | Codex | Cursor | Grok |
|---|---|---|---|---|
| **Claude** | — | 48 | 47 | 55 |
| **Codex** | 59 | — | 55 | 63 |
| **Cursor** | 47 | 44 | — | 49 |
| **Grok** | 49 | 46 | 48 | — |

The numbers are how many checks that direction runs, and every one of them passes.

The Codex-source directions run extra checks the others do not. The Codex fixture's rules file
carries three argv-prefix rules that cannot become target permissions — one holding a quote and
parentheses, one holding whitespace, one whose joined form runs past 200 characters — and those
checks assert that each is kept out of the target's permission list and named verbatim in the
report instead.

What makes this affordable is that **no direction has its own test.** There are four source fixtures and four target verifiers; a direction is one combined with another. Sixteen combinations, twelve real directions, eight files. Adding a fifth tool would add one fixture and one verifier — and eight directions.

Project scope is verified separately at 26 checks, and an empty target still fails 20 of them, so the verifier is not passing everything by default.

To run it yourself, seed a target first and then migrate into it:

```
./scripts/seed-target.sh claude /tmp/t          # the pre-migration state
/open-migrate codex claude                      # migrate, pointing the destination at /tmp/t
./scripts/verify-migration.sh /tmp/t claude codex
```

The seed step matters. Half the checks assert that content already on the target survived the
merge, and against an empty directory those pass for the wrong reason. Seeding is also what makes
the suite runnable from a clean checkout — the target directories themselves are not committed.
Running the verifier against a seed alone should fail: 34 to 43 checks, depending on the tool.

## What is not migrated

**Credentials never move.** API keys, tokens, `auth.json`, and credential files are neither read nor copied. Secrets embedded in config (an API key in an injected environment variable, say) are replaced with `<REDACTED-REENTER>`, and the report records only which key goes where so you can re-enter it.

Also not migrated:

- **MCP servers** — deliberately out of scope. Registering a server changes what the destination tool can reach on your machine, and a server definition routinely carries an API key. The report counts every server it finds and names each one with its source location so you can move them yourself.

- **Model settings** — model names differ per tool. The current value is quoted in the report as guidance only.
- **Approval policy and sandbox** — a corresponding concept exists but its meaning differs, so nothing is applied automatically. You get a suggestion.
- **Keybindings, session history, app state** — either not configuration or not portable.
- **Account-stored settings** — things that do not live on disk, such as Cursor's User Rules, go into the manual-action list with their original text so you can paste them in.

## Where loss happens

Permission models differ in expressiveness, so approximation is unavoidable.

- Cursor has no `ask` tier. Another tool's ask rules go into neither allow nor deny (both distort the original meaning) — they are handed off as manual actions.
- Codex permissions are an argv-prefix DSL that cannot express path, domain, or MCP-tool rules. Those are passed through verbatim instead of converted.
- Cursor has no global env injection surface. The key names and their source locations are recorded so you can move them yourself.
- Some hook tool matchers merge many-to-one (Claude `Edit` and `Write` → Cursor `Write`). The reverse has no unique restoration, so it is restored as `Edit|Write`.

All of these land in the report's "Approximated" or "Manual action required" section, together with exactly what was lost and how.

## Safety guarantees

- **No writes before approval.** Nothing is touched until you approve the plan table in the Confirm step.
- **Merge, never overwrite.** Existing settings are not deleted. Originals are copied to `.migrate/<run-id>/backup/` before modification, and if parsing fails after a write, the backup is restored and the run stops.
- **Safe to re-run.** `.migrate/ledger.json` records the sha256 of every migrated source file, so running the same migration again does not merge anything twice.
- **Undoable.** Every run writes `.migrate/<run-id>/changes.json` listing what it modified and what it created. `/open-migrate rollback <run-id>` restores the modified files from the backup and removes the created ones, asking first about anything you edited after the run. Manual actions you carried out yourself are named in the rollback report as things it could not undo.
- **Name collisions are skipped.** If the target already has a skill or subagent with the same name, it is left alone and recorded in the report.

## Development

`skills/` is a **build artifact**. The sources of truth are `adapters/open-migrate/SKILL.md` and `core/`; it is committed because the plugin loader looks for `skills/` at the repository root.

```
./scripts/build-plugin.sh           regenerate the distribution
./scripts/build-plugin.sh --check   exit 1 if it drifted from the sources (pre-commit check)
claude plugin validate . --strict   validate the manifests
```

After editing `core/` or `adapters/open-migrate/SKILL.md`, run the build again. Copies already installed in a tool's home go stale too, so re-run `./install.sh <dest>`.

**Bump `version` in `.claude-plugin/plugin.json` whenever the content changes.** Plugin managers compare version numbers, not content — `claude plugin update` reports "already at the latest version" and keeps serving the stale cache if the version did not move, no matter how much the files changed.

**Do not keep the plugin enabled while developing.** With both installed, two skills named `migrate` exist — the fresh one from `./install.sh` and the plugin's cache, which lags behind until you push, bump, and update. Which one loads is not predictable, and the stale copy silently lacks whatever you just wrote. Disable the plugin for the duration:

```
claude plugin disable open-migrate@migrate-marketplace   # develop against ./install.sh
claude plugin enable open-migrate@migrate-marketplace    # restore when done
```

This bit us during development: an end-to-end test loaded the plugin cache instead of the freshly installed docs and only passed because the agent noticed the staleness on its own.

To add a new tool, fill in `core/tools/_template.md` to create its knowledge doc, then add one fixture, one target verifier, and one source check. Nothing is built per direction.

## Known limitations

- **Grok Build has not been verified on a real install.** The development environment has no Grok Build, so installation into `~/.grok/skills/open-migrate` was confirmed but whether Grok actually loads the skill was not. The file conversion itself is verified at 61/61 in both directions.
- The knowledge docs reflect each tool's config surface as of August 2026. If a tool changes its format, the corresponding doc needs updating.
- The similarly named community CLI `superagent-ai/grok-cli` stores its configuration somewhere else entirely (`~/.grok/user-settings.json`). This tool targets xAI's official **Grok Build** only and distinguishes the two during detection.

## License

MIT
