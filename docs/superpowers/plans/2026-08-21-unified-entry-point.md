# Unified Entry Point Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace five destination-fixed entry points with one `/open-migrate` command that asks for source and destination.

**Architecture:** `core/` is untouched — the knowledge docs and the five-step procedure do not change. Only the entry layer changes: `adapters/` collapses from five directories to one, the runtime destination-detection block is deleted, and `install.sh` installs the same file everywhere under a new skill name.

**Tech Stack:** Markdown (entry point), Bash (installer, build), git.

**Spec:** `docs/superpowers/specs/2026-08-21-unified-entry-point-design.md`

---

## File Structure

```
adapters/
  open-migrate/SKILL.md    NEW — the single entry point (replaces all five)
  claude/  codex/  cursor/  grok/  plugin/    DELETED
install.sh                 installs skills/open-migrate/, removes any old skills/migrate/
scripts/build-plugin.sh    builds from adapters/open-migrate/
.claude-plugin/plugin.json name migrate -> open-migrate, version bump
skills/open-migrate/       build output (skills/migrate/ deleted)
README.md                  new command, upgrade instructions
```

---

### Task A: Write the unified entry point

**Files:**
- Create: `adapters/open-migrate/SKILL.md`

- [ ] **Step 1: Write the file**

```markdown
---
name: open-migrate
description: Migrate settings between AI coding tools (Claude Code, Codex CLI, Cursor, Grok Build) — rules, MCP servers, skills, subagents, hooks, permissions. Use when the user asks to move or import settings from one AI coding tool to another.
user-invocable: true
---

# open-migrate — move settings between AI coding tools

Migrate one tool's configuration into another. Both tools are inputs: you are told which to read from and which to write to, so never infer either from where this file is installed.

## 0. Resolve inputs

### 0-1. Source and destination

Read them from the user's input if present. `/open-migrate codex claude` means **source `codex`, destination `claude`** — source first, matching the order of "migrate from X to Y". Some tools substitute arguments into `$ARGUMENTS`; Cursor does not, so also read the message body. A natural-language request ("move my codex settings into claude") carries the same two values.

Ask for whatever is still missing. Do not guess, and do not assume the tool you are running inside is either one.

When asking, list what is actually on the machine — check for `~/.claude`, `~/.codex`, `~/.cursor`, and `~/.grok` and present what exists. Offer tools that are not installed as destinations too, noting that their home will be created; migrating into a tool before installing it is a normal thing to want.

Valid values: `claude`, `codex`, `cursor`, `grok`. Source and destination must differ. If either has no doc under `core/tools/`, say support is planned and stop.

### 0-2. Scope

Ask what to migrate when the user has not said:

- **Home only** — the tool's own configuration directory. The default.
- **A named project** — that repository's per-project configuration as well.
- **Every project** — discovery per procedure.md's "Project scope" section.

### 0-3. Roots

- Source root = the source doc's default home, unless the user names a path.
- Destination root = the destination doc's default home, unless the user names a path — in which case switch to **test mode** (procedure.md, "Path resolution in test mode").
- Project root = whatever the scope answer produced.

## 1. Load knowledge (relative to this file's directory, all required)

1. `core/security.md` — the policy that overrides everything
2. `core/procedure.md` — the execution procedure
3. `core/tools/<source>.md` — how to read and convert the source
4. `core/tools/<destination>.md` — how to write to the destination
5. If any of those delegates a rule to another tool's doc (for example "apply codex.md's MCP conversion rules directly"), **read that doc too.** Skipping the delegation leaves you with half the rules.

## 2. Execute

Follow procedure.md's Scan → Plan → Confirm → Apply → Report, in order.
```

- [ ] **Step 2: Verify no destination is hardcoded**

Run: `grep -ciE 'you are running inside|destination \(claude|destination \(codex' adapters/open-migrate/SKILL.md`
Expected: `0`. Any hit means a destination assumption survived the rewrite.

- [ ] **Step 3: Commit**

```bash
git add adapters/open-migrate/SKILL.md
git commit -m "feat: add unified entry point that takes source and destination as inputs"
```

---

### Task B: Delete the five old entry points

**Files:**
- Delete: `adapters/claude/`, `adapters/codex/`, `adapters/cursor/`, `adapters/grok/`, `adapters/plugin/`

- [ ] **Step 1: Delete them**

```bash
git rm -r adapters/claude adapters/codex adapters/cursor adapters/grok adapters/plugin
```

- [ ] **Step 2: Confirm only the new one remains**

Run: `ls adapters/`
Expected: `open-migrate` alone.

- [ ] **Step 3: Confirm the runtime detection logic is gone**

Run: `grep -rc 'hint, not proof' adapters/ || echo 0`
Expected: `0`. That block existed only because the plugin had to infer its destination; with the destination supplied there is nothing to infer, and leaving it would contradict the new entry point.

- [ ] **Step 4: Commit**

```bash
git commit -m "refactor: remove destination-fixed entry points"
```

---

### Task C: Update the installer

**Files:**
- Modify: `install.sh`

- [ ] **Step 1: Rewrite it**

```bash
#!/usr/bin/env bash
set -euo pipefail

dest="${1:-claude}"
case "$dest" in
  claude) home="$HOME/.claude" ;;
  codex)  home="${CODEX_HOME:-$HOME/.codex}" ;;
  cursor) home="$HOME/.cursor" ;;
  grok)   home="${GROK_HOME:-$HOME/.grok}" ;;
  *) echo "unsupported destination: $dest (supported: claude, codex, cursor, grok)" >&2; exit 1 ;;
esac
target="$home/skills/open-migrate"

src_dir="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$target"
cp "$src_dir/adapters/open-migrate/SKILL.md" "$target/SKILL.md"
rm -rf "$target/core"
cp -R "$src_dir/core" "$target/core"
rm -f "$target/core/tools/_template.md"

# The command name comes from the directory name, so the pre-rename install would
# keep answering to /migrate with a copy that no longer receives updates.
if [ -d "$home/skills/migrate" ]; then
  rm -rf "$home/skills/migrate"
  echo "removed superseded install: $home/skills/migrate"
fi

echo "installed: $target"
```

Note the argument still names a *destination home* — that is where the skill is installed, which is separate from the destination of any migration it later performs.

- [ ] **Step 2: Verify it installs and cleans up**

```bash
mkdir -p /tmp/fake-home/skills/migrate && touch /tmp/fake-home/skills/migrate/SKILL.md
HOME=/tmp/fake-home ./install.sh claude
ls /tmp/fake-home/skills/
```
Expected: `open-migrate` present, `migrate` gone, and the removal message printed.

- [ ] **Step 3: Commit**

```bash
git add install.sh
git commit -m "feat: install as open-migrate and remove the superseded skill"
```

---

### Task D: Update the build and manifest

**Files:**
- Modify: `scripts/build-plugin.sh`
- Modify: `.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`

- [ ] **Step 1: Point the build at the new paths**

In `scripts/build-plugin.sh`, change the output path and the source file:

```bash
out="$repo_dir/skills/open-migrate"
```

```bash
  cp "$repo_dir/adapters/open-migrate/SKILL.md" "$dest/SKILL.md"
```

and in the `--check` branch, change the missing-directory message to name `skills/open-migrate/`.

- [ ] **Step 2: Rename the plugin**

In `.claude-plugin/plugin.json`, set `"name": "open-migrate"` and `"version": "0.3.0"`. The rename is what lets a user tell the old install from the new one; the minor bump signals the command changed.

In `.claude-plugin/marketplace.json`, change the plugin entry's `"name"` to `"open-migrate"` and update its description to mention that both tools are chosen at run time.

- [ ] **Step 3: Remove the stale build output**

```bash
git rm -r skills/migrate
./scripts/build-plugin.sh
./scripts/build-plugin.sh --check
```
Expected: `OK: distribution matches the sources`

- [ ] **Step 4: Validate the manifests**

Run: `claude plugin validate . --strict`
Expected: `✔ Validation passed`

- [ ] **Step 5: Commit**

```bash
git add scripts/build-plugin.sh .claude-plugin skills
git commit -m "feat: package as open-migrate"
```

---

### Task E: Verify nothing in core regressed

**Files:** none — this task only runs checks

`core/` was not touched, so every existing direction must still score identically. A change here would mean the entry-point work leaked into the knowledge docs.

- [ ] **Step 1: Run every direction**

```bash
./scripts/verify-migration.sh "$(pwd)/test/tmp/claude-target" claude codex
./scripts/verify-migration.sh "$(pwd)/test/tmp/codex-target" codex claude
./scripts/verify-migration.sh "$(pwd)/test/tmp/cursor-target" cursor claude
./scripts/verify-migration.sh "$(pwd)/test/tmp/claude-target-from-cursor" claude cursor
./scripts/verify-migration.sh "$(pwd)/test/tmp/grok-target" grok claude
./scripts/verify-migration.sh "$(pwd)/test/tmp/claude-target-from-grok" claude grok
./scripts/verify-migration.sh "$(pwd)/test/tmp/cursor-target-from-codex" cursor codex
./scripts/verify-migration.sh "$(pwd)/test/tmp/fake-claude-project" claude codex project
./scripts/verify-migration.sh "$(pwd)/test/tmp/claude-project-target" claude codex project
```

Expected: 64, 54, 57, 59, 61, 61, 58, 30, 30 — all exit 0.

- [ ] **Step 2: Confirm the version guard is satisfied**

Run: `./scripts/check-version-bump.sh origin/main`
Expected: `OK: shipped content changed and version moved 0.2.1 -> 0.3.0`

---

### Task F: End-to-end with the new command

**Files:** fixes land in `adapters/open-migrate/SKILL.md` if the run reveals gaps

- [ ] **Step 1: Install and confirm the command name changed**

```bash
./install.sh claude
ls ~/.claude/skills/
```
Expected: `open-migrate` present, `migrate` absent.

- [ ] **Step 2: Seed a target**

```bash
T=test/tmp/claude-target-unified
rm -rf "$T" && mkdir -p "$T"
printf '# Existing\n\nKeep me.\n' > "$T/CLAUDE.md"
cat > "$T/settings.json" <<'JSON'
{
  "model": "claude-fable-5",
  "env": { "EXISTING_KEY": "keep" },
  "permissions": { "allow": ["Bash(ls:*)"], "deny": [] },
  "hooks": { "PreToolUse": [ { "matcher": "Read", "hooks": [ { "type": "command", "command": "echo existing-pre" } ] } ] }
}
JSON
```

- [ ] **Step 3: Run it with both tools given as arguments**

```bash
P="/open-migrate codex claude

Source root: $(pwd)/test/fixtures/codex-home
Destination root: $(pwd)/test/tmp/claude-target-unified
Scope: home only.

Treat Confirm as fully approved; run through Apply and Report without asking.
Report anything the entry point failed to tell you."
timeout 590 claude -p "$P" --permission-mode acceptEdits --allowedTools Bash Read Write Edit Glob Grep
```

Put the prompt before the options — `--allowedTools` is variadic and swallows a trailing positional argument.

- [ ] **Step 4: Score it**

Run: `./scripts/verify-migration.sh "$(pwd)/test/tmp/claude-target-unified" claude codex`
Expected: 64/64, exit 0. Same fixture and same verifier as the existing home-scope run, so any difference is the entry point's doing.

- [ ] **Step 5: Run it again with no arguments**

```bash
P="/open-migrate

I want to move settings between two of my AI coding tools. Ask me what you need.
Answer for me: source is codex, destination is claude, scope is home only.
Source root: $(pwd)/test/fixtures/codex-home
Destination root: $(pwd)/test/tmp/claude-target-unified-2

Then run to completion, treating Confirm as approved."
timeout 590 claude -p "$P" --permission-mode acceptEdits --allowedTools Bash Read Write Edit Glob Grep
```

This checks the interactive path — that the entry point asks rather than assuming the tool it is running in.

- [ ] **Step 6: Score the second run and fix any gaps**

Run: `./scripts/verify-migration.sh "$(pwd)/test/tmp/claude-target-unified-2" claude codex`
Expected: 64/64.

Classify failures: an entry-point gap goes in `adapters/open-migrate/SKILL.md` (then rebuild, reinstall, rerun); a `core/` gap should not exist, since core was untouched — if one appears, it was already there and this run merely exposed it.

- [ ] **Step 7: Commit**

```bash
git add adapters/ skills/
git commit -m "fix: close entry point gaps found by E2E"
```

---

### Task G: Update the README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Replace the usage section**

Replace the `## Usage` code block and the sentence after it with:

```markdown
```
/open-migrate                  ask which tools
/open-migrate codex claude     source first, then destination
```

Both tools are inputs, so the direction is never ambiguous and you can migrate into a tool you have not installed yet — running inside Claude, you can prepare a `~/.grok` before switching. Natural language works too: "move my codex settings into claude".

A run shows you a plan table and **writes nothing until you approve it.** After approval, `<destination home>/.migrate/<run-id>/migration-report.md` records what moved and how.
```

- [ ] **Step 2: Replace the install commands**

Every `migrate@migrate-marketplace` becomes `open-migrate@migrate-marketplace`, and `~/.cursor/skills/migrate` becomes `~/.cursor/skills/open-migrate`.

- [ ] **Step 3: Add an upgrade note under Install**

```markdown
### Upgrading from `/migrate`

The command was `/migrate`, which did not say whether `codex` meant the source or the destination. It is now `/open-migrate` and takes both.

`./install.sh` removes the old skill automatically. Plugin installs need the old one removed by hand, because the plugin was renamed:

```
claude plugin uninstall migrate@migrate-marketplace
claude plugin install open-migrate@migrate-marketplace

codex plugin remove migrate
codex plugin marketplace upgrade migrate-marketplace
codex plugin add open-migrate@migrate-marketplace
```
```

- [ ] **Step 4: Verify no stale command references remain**

Run: `grep -n '/migrate\b' README.md | grep -v 'open-migrate' | grep -v 'Upgrading'`
Expected: no output apart from lines inside the upgrade section.

- [ ] **Step 5: Commit and push**

```bash
git add README.md
git commit -m "docs: document the open-migrate command and the upgrade path"
git push -u origin feat/unified-entry-point
```

---

## Self-Review

**Spec coverage.** Ambiguous direction → Task A Step 1 (source-first ordering, both asked). Destination inference removed → Task A Step 2 and Task B Step 3. Five entry points collapse → Task B. Migrating into an uninstalled tool → Task A Step 1 (destinations offered regardless of installation). Argument handling incl. Cursor's lack of substitution → Task A Step 1. Interactive flow → Task A Steps 0-1/0-2 and Task F Step 5. Rename and upgrade path → Tasks C, D, G.

**Placeholders.** None. Every code step carries the literal content; every command states its expected output.

**Type consistency.** The skill name `open-migrate` is identical across the frontmatter (Task A), the install path (Task C), the build output path (Task D), and the README (Task G). `plugin.json` name and marketplace entry name both become `open-migrate` in Task D. Version `0.3.0` is set in Task D and asserted in Task E Step 2.
