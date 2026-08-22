# open-migrate

**Switching AI coding tools? Take your settings with you.**

[![ci](https://github.com/chakki-the-potato/open-migrate/actions/workflows/ci.yml/badge.svg)](https://github.com/chakki-the-potato/open-migrate/actions/workflows/ci.yml)
[![npm](https://img.shields.io/npm/v/open-migrate.svg)](https://www.npmjs.com/package/open-migrate)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

You cancelled Codex and paid for Claude. Your rules, skills, subagents, hooks, and permissions
are still sitting in `~/.codex`. open-migrate reads them and writes the equivalent into the tool
you moved to — showing you a plan first, and letting you undo it after.

Works between **Claude Code, Codex CLI, Cursor, and Grok Build**, in any of the 12 directions.

---

## What moves

| | Claude Code | Codex CLI | Cursor | Grok Build |
|---|---|---|---|---|
| Global rules | `CLAUDE.md` | `AGENTS.md` | account-stored → manual | `AGENTS.md` |
| Skills | yes | yes | yes | yes |
| Subagents | yes | yes | yes | yes |
| Commands / prompts | `commands/` | `prompts/` | as a skill | as a skill |
| Hooks | yes | yes | yes | yes |
| Permissions | allow / ask / deny | argv-prefix DSL | allow / deny, no ask | allow / ask / deny |
| Environment variables | yes | yes | no surface | yes |
| Approval policy | suggested, never applied | suggested | suggested | suggested |
| MCP servers | out of scope | out of scope | out of scope | out of scope |
| Credentials | never read | never read | never read | never read |

A cell says where a category lands, not that the conversion is lossless.
[Where loss happens](#where-loss-happens) is the honest part.

---

## Quickstart

Two steps: one in your terminal, one inside the tool.

### 1. Install the skill

```
npx open-migrate
```

It asks which tool, then puts the skill where that tool will find it. Works the same for all
four — Node 18+ is the only requirement.

```
npx open-migrate claude     skip the question
npx open-migrate --all      every tool present on this machine
```

**This copies documentation. It does not migrate anything yet.**

<details>
<summary>Prefer a plugin? (Claude Code and Codex CLI only)</summary>

The plugin route gives you automatic updates, at the cost of a longer command name.

```
# Claude Code, inside a session
/plugin marketplace add chakki-the-potato/open-migrate
/plugin install open-migrate@migrate-marketplace

# Codex CLI, from the shell
codex plugin marketplace add https://github.com/chakki-the-potato/open-migrate
codex plugin add open-migrate@migrate-marketplace
```

A plugin answers to `<plugin>:<skill>`, so it becomes `/open-migrate:open-migrate` — the
namespace, not a typo. Cursor and Grok Build have no plugin manager; use `npx` for those.

**Do not install both ways in one tool.** Two skills of the same name, and which one loads is
not predictable.
</details>

<details>
<summary>Prefer a clone?</summary>

```
git clone https://github.com/chakki-the-potato/open-migrate.git
cd open-migrate
./install.sh claude      # or codex / cursor / grok
```
</details>

### 2. Do not delete the old tool's directory yet

open-migrate reads files from disk and never launches the source tool, so a cancelled
subscription changes nothing — but a deleted `~/.codex` leaves nothing to migrate. Move first,
clean up after.

### 3. Run it

Restart the tool first, then:

```
/open-migrate                  ask which tools
/open-migrate codex claude     source first, then destination
/open-migrate rollback         list past runs and undo one
```

Plain language works too: *"move my codex settings into claude"*.

Both tools are inputs, so the direction is never ambiguous — and you can migrate **into a tool
you have not installed yet**. Preparing `~/.grok` before you switch to Grok is the order people
actually do it in.

---

## What a run looks like

1. **Scan** — every category is counted, including the ones that come back empty.
2. **Plan** — a table of what moves, what gets approximated, and what cannot move at all.
3. **Approve** — **nothing is written before you say yes.** Expect further prompts from your
   editor before it writes `settings.json` and friends; that is your tool protecting you, not the
   migration misbehaving.
4. **Apply** — existing settings are merged, never overwritten. Originals are copied to
   `.migrate/<run-id>/backup/` first.
5. **Report** — `<target>/.migrate/<run-id>/migration-report.md` records what moved, what was
   approximated, and what you have to finish by hand.

**Changed your mind?** `/open-migrate rollback <run-id>` restores the modified files and removes
the created ones. It asks before touching anything you edited after the migration, and the
rollback report names the manual steps it *cannot* undo.

---

## What it will not do

- **Move credentials.** `auth.json`, API keys, and credential files are never read, let alone
  copied. A secret found inside a config value becomes `<REDACTED-REENTER>`, and the report names
  the key and where it came from — never the value.
- **Register MCP servers.** Deliberately out of scope. A server definition routinely carries its
  credential inline, and this tool redacts secrets rather than copying them — so a migrated server
  would arrive registered and broken, working only once you re-entered the key. Something that
  looks migrated and is not is worse than something the report hands back to you. Servers found are
  counted and named with their source location.
- **Change your automation level.** Approval policy and sandbox mode have a matching concept in
  every tool but not a matching meaning, so you get a suggestion and nothing is applied.
- **Delete anything.** Not in the source, not in the target. Same-name skills and subagents are
  skipped and reported rather than overwritten.
- **Migrate twice.** `.migrate/ledger.json` records a checksum per source file, so re-running is
  safe.

Also not portable: model names, keybindings, session history, and settings your tool keeps in
your account rather than on disk — Cursor's User Rules, for instance. Those land in the report
with their original text so you can paste them in.

---

## Where loss happens

Permission models differ in expressiveness, so approximation is unavoidable. The report labels
every one of these under "Approximated" or "Manual action required".

- **Cursor has no `ask` tier.** Rules that mean "ask me" go to neither allow nor deny — both
  would distort the intent — and are handed back as manual actions.
- **Codex permissions are an argv-prefix DSL.** Most real rules cannot become a target pattern:
  on the machine this was measured against, 353 rules yielded 104 conversions. The other 249 hold
  quotes, parentheses, or whitespace that a pattern cannot express, and are reproduced verbatim
  in the report rather than mangled into rules that match nothing.
- **Some hook matchers merge many-to-one.** Claude's `Edit` and `Write` both become Cursor's
  `Write`; the reverse cannot be unique, so it is restored as `Edit|Write`.
- **Cursor has nowhere to inject environment variables.** Key names and their source locations
  are recorded so you can move them yourself.

---

## Project configuration

Repositories carry their own settings — `CLAUDE.md`, `.claude/`, `.codex/`, `.cursor/rules/`.
Name a project and it migrates that too.

```
migrate my codex settings, and the project config in ~/code/my-app too
```

Three things differ from home scope:

- **Source and target share one directory.** `<repo>/.codex/` becomes `<repo>/.claude/` in place.
- **The diff is usually tracked by git.** The report says which files git tracks — and in a
  monorepo, which repository answered — so you can see what a push would share with your team. It
  never stages or commits anything.
- **Each project keeps its own ledger,** so re-running is safe per project.

You can also ask for every project on the machine. Discovery presents the full list before
anything is written, and **nothing is scanned unless you ask** — naming one project touches only
that one.

Two surfaces get called out in the report: Codex ignores a project's `.codex/` layer unless your
home config trusts that path (you get the exact TOML, but trusting a repo is your decision), and
`.agents/skills/` is a shared path Cursor and Grok already read, so it is reported rather than
duplicated.

---

## Is it actually tested?

Yes, and the numbers are measured rather than claimed. All twelve directions pass a deterministic
verifier — 51 to 81 checks each — after really migrating a fixture. An empty target fails 43 of
them, so the verifier is not rubber-stamping.

What makes that affordable: there are **no per-direction converters**. Each tool has one
knowledge doc — how to read it, how to write into it — and a direction is just one doc paired
with another. Four fixtures and four verifiers cover all twelve.

Those runs are frozen in the repository, each one pinned to the sha256 of the docs that produced
it. The migration is performed by an agent reading those docs, so CI cannot re-run it — but it can
refuse to build when a doc moves ahead of its output. **Editing a tool doc fails the build until
the affected directions are re-measured and re-frozen.**

Fixtures only prove so much, so it was also run against a real `~/.codex` holding 353 permission
rules. The current guard converts 104 of them and reproduces the other 249 verbatim in the report.
The version before that guard emitted 334 entries from the same source — 43 of them over 200
characters, the longest 806 — **none of which could ever have matched anything.** That run is what
found the guard, and then a second defect in how alternation matchers were decomposed.

See **[docs/verification.md](docs/verification.md)** for the per-direction table, the full dry-run
breakdown, and what is still uncovered.

---

## How this compares

Codex CLI ships its own `/import`, which pulls *into* Codex from Cursor and Claude Code. Where it
applies, it is first-party and you should probably use it.

open-migrate covers what that does not: migrating **out of** Codex, and migrating **into** Cursor
or Grok Build. It also works at a different level — home scope plus project scope, explicit
secret handling, an approval gate, a loss report, and rollback.

**[rulesync](https://github.com/dyoshikawa/rulesync)** solves a neighbouring problem and covers far
more tools than this does. If what you want is `AGENTS.md`, `CLAUDE.md`, and `.cursor/rules/` kept
in step across a repository from one source of truth, use it — that is what it is built for.

It is a generator, though, and generators regenerate. That is the right model for project rule
files you own and can recreate, and the wrong one for `~/.claude`, which holds settings you
accumulated over months and cannot. So open-migrate merges rather than writes, shows you the plan
before it touches anything, and can be undone afterwards. Different problem, different guarantees.

---

## Known limitations

- **Grok Build has not been verified on a real install.** The development machine has no Grok
  Build, so the files land in the right place but whether Grok loads them was never confirmed.
  The conversion itself is verified in both directions.
- The tool docs describe each editor's config surface **as of August 2026**. If a tool changes
  its format, its doc needs updating.
- The similarly named community CLI `superagent-ai/grok-cli` keeps its config somewhere else
  entirely. This targets xAI's official **Grok Build**, and tells the two apart during detection.

---

## Contributing

Adding a tool costs one knowledge doc, one fixture, and one verifier — and buys eight new
directions.

Start with **[CONTRIBUTING.md](CONTRIBUTING.md)** — it covers what is in scope, and the three
things that break otherwise-correct pull requests. **[docs/development.md](docs/development.md)**
has the repository layout. Vulnerabilities go through **[SECURITY.md](SECURITY.md)**, not the
issue tracker.

## License

MIT
