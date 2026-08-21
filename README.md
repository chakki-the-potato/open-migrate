# open-migrate

Move your settings in one step when you switch AI coding tools. It reads rules, MCP servers, skills, subagents, hooks, and permissions from the source tool and converts them into the destination tool's format.

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
/plugin install migrate@migrate-marketplace
```

or from the shell:

```
claude plugin marketplace add chakki-the-potato/open-migrate
claude plugin install migrate@migrate-marketplace
```

**Codex CLI** — from the shell. It needs the full URL, and the `@marketplace` qualifier is required on install:

```
codex plugin marketplace add https://github.com/chakki-the-potato/open-migrate
codex plugin add migrate@migrate-marketplace
```

The plugin distribution determines which tool it is running in and uses that as the destination.

### Cursor and Grok Build — install script

```
git clone https://github.com/chakki-the-potato/open-migrate.git
cd open-migrate
./install.sh cursor    # → ~/.cursor/skills/migrate
./install.sh grok      # → ~/.grok/skills/migrate  (honors GROK_HOME)
```

`./install.sh claude` and `./install.sh codex` exist too, for installing as a personal skill instead of a plugin. Pick one method per tool — installing both leaves two skills named `migrate` in the same home.

If Grok Build is not installed yet: `curl -fsSL https://x.ai/cli/install.sh | bash`.

### Install status verified

Installation and skill loading were checked on a real machine, not just in tests.

| Tool | Install | Skill loads |
|---|---|---|
| Claude Code | plugin | verified — the running session lists `migrate` |
| Codex CLI | plugin | loader confirmed (`plugin list` reports `installed, enabled`; the skill loader logs it), full round trip unverified |
| Cursor | `./install.sh cursor` | verified — `cursor-agent` lists `migrate` |
| Grok Build | `./install.sh grok` | unverified — no Grok Build on the development machine |

## Usage

```
/migrate codex          name the source explicitly
/migrate                auto-detect — finds installed tools and lets you choose
```

Natural language works as well: say "migrate my codex settings over" and it picks the tool name out of the sentence.

A run shows you a plan table and **writes nothing until you approve it.** After approval, `<target home>/.migrate/<run-id>/migration-report.md` records what moved and how.

## Verified directions

Each direction was scored by a deterministic verifier after actually migrating a fixture. These are measured results.

| Direction | Checks | Result |
|---|---|---|
| Codex → Claude | 64 | pass |
| Claude → Codex | 54 | pass |
| Claude → Cursor | 57 | pass |
| Cursor → Claude | 59 | pass |
| Claude → Grok | 61 | pass |
| Grok → Claude | 61 | pass |
| Codex → Cursor | 58 | pass |

The remaining five directions (Codex↔Grok, Cursor↔Grok, Cursor→Codex) are covered by the same structure but have not been measured. The evidence for composability is that Codex → Cursor passed **with no new fixture and no new verifier** — purely by combining existing artifacts.

To run it yourself:

```
./scripts/verify-migration.sh <target root> <target tool> <source tool>
```

## What is not migrated

**Credentials never move.** API keys, tokens, `auth.json`, and credential files are neither read nor copied. Secrets embedded in config (an API key in an MCP header, say) are replaced with `<REDACTED-REENTER>`, and the report records only which key goes where so you can re-enter it.

Also not migrated:

- **Model settings** — model names differ per tool. The current value is quoted in the report as guidance only.
- **Approval policy and sandbox** — a corresponding concept exists but its meaning differs, so nothing is applied automatically. You get a suggestion.
- **Keybindings, session history, app state** — either not configuration or not portable.
- **Account-stored settings** — things that do not live on disk, such as Cursor's User Rules, go into the manual-action list with their original text so you can paste them in.

## Where loss happens

Permission models differ in expressiveness, so approximation is unavoidable.

- Cursor has no `ask` tier. Another tool's ask rules go into neither allow nor deny (both distort the original meaning) — they are handed off as manual actions.
- Codex permissions are an argv-prefix DSL that cannot express path, domain, or MCP rules. Those are passed through verbatim instead of converted.
- Cursor has no global env injection surface. The key names and their source locations are recorded so you can move them yourself.
- Some hook tool matchers merge many-to-one (Claude `Edit` and `Write` → Cursor `Write`). The reverse has no unique restoration, so it is restored as `Edit|Write`.

All of these land in the report's "Approximated" or "Manual action required" section, together with exactly what was lost and how.

## Safety guarantees

- **No writes before approval.** Nothing is touched until you approve the plan table in the Confirm step.
- **Merge, never overwrite.** Existing settings are not deleted. Originals are copied to `.migrate/<run-id>/backup/` before modification, and if parsing fails after a write, the backup is restored and the run stops.
- **Safe to re-run.** `.migrate/ledger.json` records the sha256 of every migrated source file, so running the same migration again does not merge anything twice.
- **Name collisions are skipped.** If the target already has a skill, subagent, or MCP server with the same name, it is left alone and recorded in the report.

## Development

`skills/` is a **build artifact**. The sources of truth are `adapters/plugin/SKILL.md` and `core/`; it is committed because the plugin loader looks for `skills/` at the repository root.

```
./scripts/build-plugin.sh           regenerate the distribution
./scripts/build-plugin.sh --check   exit 1 if it drifted from the sources (pre-commit check)
claude plugin validate . --strict   validate the manifests
```

After editing `core/` or `adapters/plugin/SKILL.md`, run the build again. Copies already installed in a tool's home go stale too, so re-run `./install.sh <dest>`.

To add a new tool, fill in `core/tools/_template.md` to create its knowledge doc, then add one fixture, one target verifier, and one source check. Nothing is built per direction.

## Known limitations

- **Grok Build has not been verified on a real install.** The development environment has no Grok Build, so installation into `~/.grok/skills/migrate` was confirmed but whether Grok actually loads the skill was not. The file conversion itself is verified at 61/61 in both directions.
- The knowledge docs reflect each tool's config surface as of August 2026. If a tool changes its format, the corresponding doc needs updating.
- The similarly named community CLI `superagent-ai/grok-cli` stores its configuration somewhere else entirely (`~/.grok/user-settings.json`). This tool targets xAI's official **Grok Build** only and distinguishes the two during detection.

## License

MIT
