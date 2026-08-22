# Project-Scope Migration — Stage 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate the tool configuration of a single named project directory (`<repo>/.codex/` → `<repo>/.claude/` and equivalents), in addition to the home-scope migration that already works.

**Architecture:** No new machinery. The five-step procedure, the knowledge docs, and the fixture-plus-verifier test structure all stay as they are. Project scope enters as (a) a new section in `procedure.md` defining what a project root is and how it differs from home scope, (b) a "Project scope" row block in each tool doc's inventory, and (c) one project fixture plus one project verifier that compose with the existing dispatcher.

**Tech Stack:** Markdown (knowledge docs), Bash (verifier), jq / python3 tomllib (validation), git.

**Scope:** Stage 1 only — the user names one project root. Machine-wide discovery is Stage 2 and is deliberately excluded.

**Spec:** `docs/superpowers/specs/2026-08-21-project-scope-migration-design.md`

---

## File Structure

```
core/
  procedure.md              + "Project scope" section (root resolution, git reporting, ledger placement)
  tools/claude.md           + project surface rows
  tools/codex.md            + project surface rows, trust gate
  tools/cursor.md           + project surface rows
  tools/grok.md             + project surface rows
adapters/*/SKILL.md         + project root input parsing (5 files)
scripts/checks/
  project-common.sh         NEW — scope-independent project checks (ledger, backup, git note)
  target-claude-project.sh  NEW — Claude project target checks
scripts/verify-migration.sh + accept "project" as a scope argument
test/fixtures/
  codex-project/            NEW — a project root carrying Codex project config
test/tmp/
  claude-project-target/    generated during E2E (gitignored)
```

---

### Task A: Define project scope in procedure.md

**Files:**
- Modify: `core/procedure.md`

- [ ] **Step 1: Add the project scope section**

Insert this section immediately after the existing "Path resolution in test mode (applies to every tool)" section:

```markdown
## Project scope

Everything above describes **home scope** — the tool's own configuration directory. Tools also read **project scope** configuration from the repository you are working in. Migrating project scope has three differences you must respect.

**Source and target share one root.** In home scope the source (`~/.codex`) and the target (`~/.claude`) are two separate trees. In a project they are the same directory: `<project>/.codex/` is the source and `<project>/.claude/` is the target. You are given one project root, not a source root and a target root.

**Project config is usually tracked by git.** Migrating produces a diff in someone's repository and, once pushed, reaches teammates. For every file you write or modify, check whether git tracks it (`git -C <project> ls-files --error-unmatch <path>` succeeds) and record the answer in the report. Never run any other git command — do not stage, commit, or stash. The user decides what to do with the diff.

**The ledger lives in the project.** Write `<project>/.migrate/ledger.json` and `<project>/.migrate/<run-id>/`, exactly as home scope does inside the target root. A project's ledger is independent of the home ledger and of every other project's.

Everything else is unchanged: the same five steps, the same category checklist, the same conflict rules, the same security policy.

### Scope selection

- If the user names a project root, migrate project scope for that root.
- If the user names both a home target root and a project root, migrate both and report them as separate sections.
- If the user names neither, migrate home scope only. **Never scan for projects on your own** — scanning is out of scope for this version and picking projects unasked would edit repositories the user did not name.
```

- [ ] **Step 2: Verify the section reads correctly in context**

Run: `grep -n '^## ' core/procedure.md`
Expected: `## Project scope` appears after `## Path resolution in test mode (applies to every tool)` and before `## Category checklist (walk all of it, every run)`.

- [ ] **Step 3: Commit**

```bash
git add core/procedure.md
git commit -m "docs: define project scope in the migration procedure"
```

---

### Task B: Add project surfaces to the Claude and Codex docs

**Files:**
- Modify: `core/tools/claude.md`
- Modify: `core/tools/codex.md`

- [ ] **Step 1: Add the Claude project surface section**

Append to `core/tools/claude.md`:

```markdown
## Project scope surfaces

Read these when Claude is the source in a project migration; write these when it is the target. Paths are relative to the project root.

| Category | Location | Notes |
|---|---|---|
| Global rules | `CLAUDE.md`, or `.claude/CLAUDE.md` | If both exist, migrate both and keep them separated per file (procedure.md's merge format) |
| MCP | `.mcp.json` | Same server definition fields as the home-scope `mcpServers` object |
| Settings | `.claude/settings.json` (shared), `.claude/settings.local.json` (personal) | Same schema as home `settings.json`: `hooks`, `permissions`, `env`. Merge each into the matching file — never move a setting between shared and local, since that changes who sees it |
| Skills | `.claude/skills/<name>/` | Whole directory, supporting files included |
| Subagents | `.claude/agents/*.md` | Same frontmatter rules as home scope |
| Commands | `.claude/commands/*.md` | Same substitution rules as home scope |

`.claude/settings.local.json` is personal configuration that repositories usually gitignore — but not always. Report its git status like any other file rather than assuming.
```

- [ ] **Step 2: Add the Codex project surface section**

Append to `core/tools/codex.md`:

```markdown
## Project scope surfaces

Read these when Codex is the source in a project migration; write these when it is the target. Paths are relative to the project root.

| Category | Location | Notes |
|---|---|---|
| Global rules | `AGENTS.md` | `AGENTS.override.md` takes precedence here exactly as in home scope |
| Settings | `.codex/config.toml` | Only some sections load at project level. Migrate MCP servers and permission rules; leave model, approval policy, and sandbox to home scope |
| Hooks | `.codex/hooks.json` | Same `{"hooks": {...}}` structure as home scope |
| Skills | `.codex/skills/<name>/` | Whole directory |

**Trust gate — read this before writing anything.** Codex ignores a project's `.codex/config.toml`, `.codex/hooks.json`, and skills layer unless `~/.codex/config.toml` contains a trust entry for that project:

```toml
[projects."/absolute/path/to/project"]
trust_level = "trusted"
```

Without it, everything you write into `.codex/` is a file the tool never reads. **Do not add the trust entry yourself** — trusting a repository is a security decision belonging to the user. Instead, check whether the entry already exists and, if it does not, put it in the report's manual-action list with the exact TOML block above and the project's absolute path filled in.
```

- [ ] **Step 3: Verify both files still parse as intended tables**

Run: `grep -c '^| ' core/tools/claude.md core/tools/codex.md`
Expected: both counts increased relative to `git show HEAD:<file> | grep -c '^| '`.

- [ ] **Step 4: Commit**

```bash
git add core/tools/claude.md core/tools/codex.md
git commit -m "docs: add Claude and Codex project scope surfaces"
```

---

### Task C: Add project surfaces to the Cursor and Grok docs

**Files:**
- Modify: `core/tools/cursor.md`
- Modify: `core/tools/grok.md`

- [ ] **Step 1: Add the Cursor project surface section**

Append to `core/tools/cursor.md`:

```markdown
## Project scope surfaces

Read these when Cursor is the source in a project migration; write these when it is the target. Paths are relative to the project root.

| Category | Location | Notes |
|---|---|---|
| Global rules | `.cursor/rules/*.mdc`, `AGENTS.md` | Same handling as home scope — `.mdc` keeps its frontmatter, and `AGENTS.md` counts as a rule source even when no `.mdc` exists |
| Skills | `.cursor/skills/<name>/` | Whole directory |
| Subagents | `.cursor/agents/*.md` | Project agents take precedence over the user's `~/.cursor/agents/` |
| Commands | `.cursor/commands/*.md` | Deprecated surface; migrate per the write rules above |

Cursor has no project-scope MCP, permission, or hook file — those live only in the home. When Cursor is the target of a project migration, the source's project-level MCP, permissions, and hooks are not migratable at project scope. Record them in the manual-action list with their source location instead of silently dropping them.
```

- [ ] **Step 2: Add the Grok project surface section**

Append to `core/tools/grok.md`:

```markdown
## Project scope surfaces

Read these when Grok is the source in a project migration; write these when it is the target. Paths are relative to the project root.

| Category | Location | Notes |
|---|---|---|
| Global rules | `AGENTS.md` | The project root's `AGENTS.md`; `rules/*.md` is home-scope only |
| Settings | `.grok/config.toml` | **The project layer loads less than the home layer** — only MCP servers, plugins, and permission rules. Do not write model, `[ui] permission_mode`, or `[sandbox]` here; Grok ignores them at project level |
| Skills | `.grok/skills/<name>/` | Whole directory |
| Subagents | `.grok/agents/*.md` | camelCase frontmatter, same as home scope |
| Hooks | `.grok/hooks/*.json` | Project hooks require `/hooks-trust` or `--trust` before Grok honors them — note this in the report |
```

- [ ] **Step 3: Add the vendor-neutral surface to procedure.md**

Append to the `## Project scope` section created in Task A:

```markdown
### `.agents/` is shared, not migratable

`<project>/.agents/skills/` is a vendor-neutral path that Cursor and Grok read natively. A skill living there is **already visible** to those tools, so copying it into `.cursor/skills/` or `.grok/skills/` creates a duplicate rather than migrating anything.

- When the target reads `.agents/skills/` natively, record each skill found there as "already being read" and migrate nothing.
- When the target does not read it (Claude Code, Codex CLI), migrate it like any other skill directory.

The same reasoning applies to any other path a target reads natively — check the target doc's compatibility notes before copying.
```

- [ ] **Step 4: Commit**

```bash
git add core/tools/cursor.md core/tools/grok.md core/procedure.md
git commit -m "docs: add Cursor and Grok project scope surfaces"
```

---

### Task D: Teach the adapters to accept a project root

**Files:**
- Modify: `adapters/claude/SKILL.md`
- Modify: `adapters/codex/SKILL.md`
- Modify: `adapters/cursor/SKILL.md`
- Modify: `adapters/grok/SKILL.md`
- Modify: `adapters/plugin/SKILL.md`

- [ ] **Step 1: Add the project root input line to all five adapters**

In each file, find the line beginning `- Target root = ` and insert this line directly after it:

```markdown
- Project root = a repository whose per-project configuration should also be migrated. Use it only when the user names one. With a project root, migrate project scope per procedure.md's "Project scope" section; without one, migrate home scope only and never go looking for projects.
```

The five files differ in their surrounding text, so make the insertion per file rather than with a blanket replace.

- [ ] **Step 2: Verify all five carry the line**

Run: `grep -c 'Project root = ' adapters/*/SKILL.md`
Expected: every one of the five files reports `1`.

- [ ] **Step 3: Rebuild the plugin distribution**

Run: `./scripts/build-plugin.sh && ./scripts/build-plugin.sh --check`
Expected: `OK: distribution matches the sources`

- [ ] **Step 4: Commit**

```bash
git add adapters/ skills/
git commit -m "feat: accept a project root in every adapter entry point"
```

---

### Task E: Build the Codex project fixture

**Files:**
- Create: `test/fixtures/codex-project/AGENTS.md`
- Create: `test/fixtures/codex-project/.codex/config.toml`
- Create: `test/fixtures/codex-project/.codex/hooks.json`
- Create: `test/fixtures/codex-project/.codex/skills/proj-hello/SKILL.md`
- Create: `test/fixtures/codex-project/.agents/skills/shared-skill/SKILL.md`

Create every file with the Write tool, not a shell heredoc — this machine's `env-file-guard` hook blocks heredocs containing secret-shaped strings.

- [ ] **Step 1: AGENTS.md**

```markdown
# Project Rules

- Use tabs, not spaces, in this repository.
- Never touch the generated/ directory.
```

- [ ] **Step 2: .codex/config.toml**

```toml
[mcp_servers.projsvc]
command = "npx"
args = ["-y", "project-only-server"]

[mcp_servers.projsvc.env]
PROJECT_FLAG = "1"
```

- [ ] **Step 3: .codex/hooks.json**

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "apply_patch",
        "hooks": [
          { "type": "command", "command": "echo project-pre-edit", "timeout": 5 }
        ]
      }
    ]
  }
}
```

- [ ] **Step 4: .codex/skills/proj-hello/SKILL.md**

```markdown
---
name: proj-hello
description: Project-scoped hello skill
---

Greet using the project conventions.
```

- [ ] **Step 5: .agents/skills/shared-skill/SKILL.md**

This one is the decoy for the vendor-neutral rule. Claude does not read `.agents/skills/`, so a Claude target must migrate it.

```markdown
---
name: shared-skill
description: VENDOR-NEUTRAL-SHARED lives in .agents and is read natively by some tools
---

This skill lives in the vendor-neutral path.
```

- [ ] **Step 6: Verify the fixture parses**

Run:
```bash
python3 -c "import tomllib;tomllib.load(open('test/fixtures/codex-project/.codex/config.toml','rb'))" && echo TOML_OK
jq -e . test/fixtures/codex-project/.codex/hooks.json >/dev/null && echo JSON_OK
```
Expected: `TOML_OK` and `JSON_OK`.

- [ ] **Step 7: Commit**

```bash
git add test/fixtures/codex-project
git commit -m "test: add Codex project scope fixture"
```

---

### Task F: Extend the verifier dispatcher with a scope argument

**Files:**
- Modify: `scripts/verify-migration.sh`
- Create: `scripts/checks/project-common.sh`

- [ ] **Step 1: Add the scope argument to the dispatcher**

In `scripts/verify-migration.sh`, replace the three argument lines with four:

```bash
TARGET="${1:?usage: verify-migration.sh <target-root> <target-tool> <source-tool> [scope]}"
TOOL="${2:?usage: verify-migration.sh <target-root> <target-tool> <source-tool> [scope]}"
SOURCE="${3:?usage: verify-migration.sh <target-root> <target-tool> <source-tool> [scope]}"
SCOPE="${4:-home}"
```

Then, immediately after the line `. "$script_dir/checks/_common.sh"`, add:

```bash
if [ "$SCOPE" = "project" ]; then
  . "$script_dir/checks/project-common.sh"
fi
```

and change the two `tool_checks` / `source_checks` assignments to honour the scope:

```bash
if [ "$SCOPE" = "project" ]; then
  tool_checks="$script_dir/checks/target-$TOOL-project.sh"
else
  tool_checks="$script_dir/checks/target-$TOOL.sh"
fi
source_checks="$script_dir/checks/source-$SOURCE.sh"
```

Leave `source_checks` scope-independent: the source-dependent report strings are the same regardless of scope.

- [ ] **Step 2: Create project-common.sh**

```bash
# project-common.sh — checks that apply to any project-scope migration, regardless
# of which tools are involved. Sourced only when SCOPE=project. Uses TARGET (the
# project root), mig_dir, and chk/chk_not from _common.sh.

# The vendor-neutral path is read natively by some tools. Whether it was migrated
# depends on the target, so target-*-project.sh decides — this file only asserts
# that the source copy was left alone.
chk "vendor-neutral path untouched" test -f "$TARGET/.agents/skills/shared-skill/SKILL.md"

# The project ledger lives in the project, not in a home directory.
chk "project ledger in project root"  test -f "$TARGET/.migrate/ledger.json"

# Git status has to be reported, not acted on. The migration must never create a
# commit — a repository left mid-commit would be worse than one left dirty.
chk_not "no commit created by migration" sh -c 'git -C "$0" log --oneline -1 --since="10 minutes ago" 2>/dev/null | grep -q .' "$TARGET"
```

- [ ] **Step 3: Verify the dispatcher still runs home scope unchanged**

Run: `./scripts/verify-migration.sh "$(pwd)/test/tmp/claude-target" claude codex`
Expected: `64 PASS`, exit 0 — identical to before the change, because the scope argument defaults to `home`.

- [ ] **Step 4: Commit**

```bash
git add scripts/verify-migration.sh scripts/checks/project-common.sh
git commit -m "feat: add a scope argument to the verifier dispatcher"
```

---

### Task G: Build the Claude project target verifier

**Files:**
- Create: `scripts/checks/target-claude-project.sh`

- [ ] **Step 1: Write the verifier**

```bash
# target-claude-project.sh — checks for a Claude Code target in a project-scope
# migration. TARGET is the project root, not a home directory. Uses TARGET,
# mig_dir, find_run_artifact, and chk/chk_not from _common.sh.

# Project rules land in the project's CLAUDE.md.
chk "project CLAUDE.md exists"        test -f "$TARGET/CLAUDE.md"
chk "project rule 1 migrated"         grep -qF "Use tabs, not spaces" "$TARGET/CLAUDE.md"
chk "project rule 2 migrated"         grep -qF "Never touch the generated/ directory" "$TARGET/CLAUDE.md"
chk "merge heading present"           grep -q "^## Migrated from codex" "$TARGET/CLAUDE.md"
chk "per-file subheading present"     grep -q "^### AGENTS.md" "$TARGET/CLAUDE.md"

# Project MCP goes to .mcp.json, never to the home-scope CLI.
chk ".mcp.json valid JSON"            jq -e . "$TARGET/.mcp.json"
chk "project MCP server migrated"     jq -e '.mcpServers.projsvc.command == "npx"' "$TARGET/.mcp.json"
chk "project MCP env carried"         jq -e '.mcpServers.projsvc.env.PROJECT_FLAG == "1"' "$TARGET/.mcp.json"

# Project hooks go into .claude/settings.json, converted from the Codex matcher.
chk "project settings valid JSON"     jq -e . "$TARGET/.claude/settings.json"
chk "project hook matcher converted"  jq -e '[.hooks.PreToolUse[].matcher] | index("Edit|Write") != null' "$TARGET/.claude/settings.json"
chk "project hook body carried"       jq -e '[.hooks.PreToolUse[].hooks[].command] | index("echo project-pre-edit") != null' "$TARGET/.claude/settings.json"

# Project skills are copied into the project's own skill directory.
chk "project skill copied"            test -f "$TARGET/.claude/skills/proj-hello/SKILL.md"
chk "project skill content"           grep -qF "Greet using the project conventions" "$TARGET/.claude/skills/proj-hello/SKILL.md"

# Claude does NOT read .agents/skills/, so the vendor-neutral skill must be migrated.
chk "vendor-neutral skill migrated"   test -f "$TARGET/.claude/skills/shared-skill/SKILL.md"

# Home-scope-only settings must not leak into the project layer.
chk_not "no model at project scope"   jq -e '.model' "$TARGET/.claude/settings.json"
chk_not "no defaultMode at project"   jq -e '.permissions.defaultMode' "$TARGET/.claude/settings.json"

# Backup of anything pre-existing that got modified.
claude_proj_backup="$(find_run_artifact backup/CLAUDE.md)"
: "${claude_proj_backup:=$TARGET/.migrate/__missing__/backup/CLAUDE.md}"
chk "backup of pre-existing CLAUDE.md" test -f "$claude_proj_backup"
chk "backup is the original"           grep -qF "Keep this project note." "$claude_proj_backup"

# The report has to state git tracking status for files it touched.
chk "report notes git tracking"        grep -qiE "git|tracked" "${mig_dir}migration-report.md"
```

- [ ] **Step 2: Verify it fails on an empty target**

```bash
mkdir -p test/tmp/empty-project-target
./scripts/verify-migration.sh "$(pwd)/test/tmp/empty-project-target" claude codex project
```
Expected: exit 1 with many FAIL lines. An empty directory must not pass.

- [ ] **Step 3: Commit**

```bash
git add scripts/checks/target-claude-project.sh
git commit -m "test: add Claude project target verifier"
```

---

### Task H: Prove the verifier on a hand-built ideal target

**Files:**
- Create: `test/tmp/fake-claude-project/` (gitignored, built by hand)

This proves the verifier accepts a correct result before any migration is run against it. Without this step a passing E2E could mean either "the migration worked" or "the verifier checks nothing".

- [ ] **Step 1: Seed the project with pre-existing content**

```bash
T=test/tmp/fake-claude-project
rm -rf "$T" && mkdir -p "$T/.claude/skills" "$T/.agents/skills/shared-skill" "$T/.migrate/20260821-120000/backup"
printf '# Project Notes\n\nKeep this project note.\n' > "$T/CLAUDE.md"
printf '# Project Notes\n\nKeep this project note.\n' > "$T/.migrate/20260821-120000/backup/CLAUDE.md"
```

- [ ] **Step 2: Write the migrated CLAUDE.md**

Append the migrated section so the file holds both the original note and the migration:

```bash
cat >> test/tmp/fake-claude-project/CLAUDE.md <<'EOF'

## Migrated from codex (2026-08-21)

### AGENTS.md

# Project Rules

- Use tabs, not spaces, in this repository.
- Never touch the generated/ directory.
EOF
```

- [ ] **Step 3: Write the remaining artifacts**

```bash
T=test/tmp/fake-claude-project
cat > "$T/.mcp.json" <<'EOF'
{ "mcpServers": { "projsvc": { "command": "npx", "args": ["-y", "project-only-server"], "env": { "PROJECT_FLAG": "1" } } } }
EOF
cat > "$T/.claude/settings.json" <<'EOF'
{ "hooks": { "PreToolUse": [ { "matcher": "Edit|Write", "hooks": [ { "type": "command", "command": "echo project-pre-edit", "timeout": 5 } ] } ] } }
EOF
mkdir -p "$T/.claude/skills/proj-hello" "$T/.claude/skills/shared-skill"
printf -- '---\nname: proj-hello\ndescription: Project-scoped hello skill\n---\n\nGreet using the project conventions.\n' > "$T/.claude/skills/proj-hello/SKILL.md"
printf -- '---\nname: shared-skill\ndescription: VENDOR-NEUTRAL-SHARED lives in .agents and is read natively by some tools\n---\n\nThis skill lives in the vendor-neutral path.\n' > "$T/.claude/skills/shared-skill/SKILL.md"
printf -- '---\nname: shared-skill\ndescription: VENDOR-NEUTRAL-SHARED lives in .agents and is read natively by some tools\n---\n\nThis skill lives in the vendor-neutral path.\n' > "$T/.agents/skills/shared-skill/SKILL.md"
```

- [ ] **Step 4: Write the ledger and report**

The ledger needs at least five distinct sha256 values because `_common.sh` requires it. Compute them from the fixture so they are real.

```bash
T=test/tmp/fake-claude-project
SRC="$(pwd)/test/fixtures/codex-project"
{
  echo "{"
  first=1
  for f in AGENTS.md .codex/config.toml .codex/hooks.json .codex/skills/proj-hello/SKILL.md .agents/skills/shared-skill/SKILL.md; do
    h=$(shasum -a 256 "$SRC/$f" | awk '{print $1}')
    [ $first -eq 1 ] || echo ","
    first=0
    printf '  "%s": { "sha256": "%s", "run": "20260821-120000" }' "$SRC/$f" "$h"
  done
  echo ""
  echo "}"
} > "$T/.migrate/ledger.json"
jq -e . "$T/.migrate/ledger.json" >/dev/null && echo LEDGER_OK
```

Then write `test/tmp/fake-claude-project/.migrate/20260821-120000/migration-report.md` with the Write tool:

```markdown
# Migration Report: codex → claude (20260821-120000)

## Scan summary
| Category | Found | Automatic | Approximate | Suggestion | Impossible |
|---|---|---|---|---|---|
| 1. Global rules | 1 | 1 | 0 | 0 | 0 |
| 2. MCP servers | 1 | 1 | 0 | 0 | 0 |
| 3. Skills | 2 | 2 | 0 | 0 | 0 |
| 4. Commands/prompts | 0 | 0 | 0 | 0 | 0 |
| 5. Subagents | 0 | 0 | 0 | 0 | 0 |
| 6. Hooks | 1 | 0 | 1 | 0 | 0 |
| 7. Permission rules | 0 | 0 | 0 | 0 | 0 |
| 8. Env injection | 0 | 0 | 0 | 0 | 0 |
| 9. Approval/sandbox | 0 | 0 | 0 | 0 | 0 |
| 10. Non-migratable | 0 | 0 | 0 | 0 | 0 |

## Migrated (automatic)
- Global rules: `AGENTS.md` → `CLAUDE.md` (git tracked: no)
- MCP servers: `projsvc` (`.codex/config.toml`) → `.mcp.json` (git tracked: no)
- Skills: `proj-hello` (`.codex/skills/`) → `.claude/skills/` (git tracked: no)
- Skills: `shared-skill` (`.agents/skills/`) → `.claude/skills/` — Claude does not read the vendor-neutral path, so this one is migrated rather than shared (git tracked: no)

## Approximated (review recommended)
- Hooks: matcher `apply_patch` (`.codex/hooks.json`) → `Edit|Write`, because Claude splits editing across two tools

## Manual action required
- None.

## Not migrated
- None.

## Verification
- `jq -e .` on `.mcp.json` and `.claude/settings.json` — both valid
- Git tracking checked per file with `git ls-files --error-unmatch`; this project is not a git repository, so every file is reported as untracked
```

- [ ] **Step 5: Run the verifier against the ideal target**

Run: `./scripts/verify-migration.sh "$(pwd)/test/tmp/fake-claude-project" claude codex project`
Expected: every check PASS, exit 0. If anything fails, the verifier expectation and this hand-built target disagree — fix whichever is wrong before continuing.

- [ ] **Step 6: Commit**

```bash
git add scripts/checks/
git commit -m "test: prove the project verifier accepts a correct result"
```

---

### Task I: End-to-end project migration

**Files:** no source changes; fixes land in `core/*.md` if the run reveals gaps

- [ ] **Step 1: Reinstall so the agent reads the current docs**

```bash
./install.sh claude && ./scripts/build-plugin.sh
claude plugin update migrate@migrate-marketplace || true
```

Docs edited in this plan do not reach an installed skill until you reinstall. Skipping this makes the E2E test a stale copy.

- [ ] **Step 2: Seed the E2E project target**

```bash
T=test/tmp/claude-project-target
rm -rf "$T" && mkdir -p "$T"
cp -R test/fixtures/codex-project/. "$T/"
printf '# Project Notes\n\nKeep this project note.\n' > "$T/CLAUDE.md"
```

The target starts as a copy of the fixture because in a project migration the source and target are the same root. The pre-existing `CLAUDE.md` is what proves merge-not-overwrite.

- [ ] **Step 3: Run the migration in an isolated session**

```bash
P="Use the migrate skill to migrate the Codex project configuration in this project into Claude Code.

Project root: $(pwd)/test/tmp/claude-project-target
This is a project-scope migration: source and target are the same root.
Treat Confirm as fully approved; run through Apply and Report without asking.
Follow the documented procedure exactly. Report anything the docs failed to tell you."
claude -p "$P" --permission-mode acceptEdits --allowedTools Bash Read Write Edit Glob Grep
```

Put the prompt before the options — `--allowedTools` and `--add-dir` are variadic and swallow a trailing positional argument.

- [ ] **Step 4: Score the run**

Run: `./scripts/verify-migration.sh "$(pwd)/test/tmp/claude-project-target" claude codex project`
Expected: all PASS, exit 0.

- [ ] **Step 5: Classify and fix any failures**

For each FAIL decide which side is wrong:
- **Doc gap** — the docs never told the agent what to do. Fix `core/*.md`, reinstall (Step 1), reseed (Step 2), rerun.
- **Verifier error** — the check expects something the docs never promised. Fix `scripts/checks/target-claude-project.sh`.

Record any doc gap in the commit message; those are the findings this task exists to produce.

- [ ] **Step 6: Confirm home scope did not regress**

```bash
./scripts/verify-migration.sh "$(pwd)/test/tmp/claude-target" claude codex
./scripts/verify-migration.sh "$(pwd)/test/tmp/codex-target" codex claude
./scripts/verify-migration.sh "$(pwd)/test/tmp/cursor-target" cursor claude
./scripts/verify-migration.sh "$(pwd)/test/tmp/grok-target" grok claude
```
Expected: 64, 54, 57, 61 PASS respectively, all exit 0. Project-scope doc edits must not change home-scope behavior.

- [ ] **Step 7: Commit**

```bash
git add core/ scripts/ skills/
git commit -m "fix: close project scope doc gaps found by E2E"
```

---

### Task J: Document project scope in the README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add the usage section**

Insert after the existing `## Usage` code block:

```markdown
### Project configuration

Repositories carry their own configuration — `CLAUDE.md`, `.claude/`, `.codex/`, `.cursor/rules/`, and so on. Name a project and it migrates that too.

```
/migrate codex --project ~/code/my-app
```

Project scope differs from home scope in three ways worth knowing.

- **Source and target are the same directory.** `<repo>/.codex/` becomes `<repo>/.claude/` in place.
- **The diff is usually tracked by git.** The report tells you which files git tracks, so you can see what a push would share with your team. The migration never stages or commits anything.
- **Each project keeps its own ledger** at `<repo>/.migrate/ledger.json`, so re-running is safe per project.

Projects are never discovered automatically — only the one you name is touched.

Two surfaces need extra care and the report calls both out.

- **Codex project config is trust-gated.** Codex ignores a project's `.codex/` layer unless `~/.codex/config.toml` trusts that path. The report gives you the exact TOML to add; the migration will not add it for you, because trusting a repository is your decision.
- **`.agents/skills/` is already shared.** Cursor and Grok read that vendor-neutral path natively, so skills there are reported as "already being read" rather than copied. Claude and Codex do not read it, so for those targets it migrates normally.
```

- [ ] **Step 2: Verify the README renders the new section**

Run: `grep -n '^### Project configuration' README.md`
Expected: one match inside the `## Usage` section.

- [ ] **Step 3: Commit and push**

```bash
git add README.md
git commit -m "docs: document project scope migration"
git push
```

---

## Self-Review

**Spec coverage.** Every spec section maps to a task: scope concept → Task A; per-tool surfaces → Tasks B and C; `.agents/` sharing → Task C Step 3; git reporting → Task A Step 1 and Task G's report check; project ledger → Task A and `project-common.sh`; Codex trust gate → Task B Step 2; staged implementation → this plan is Stage 1 only, and discovery is excluded by Task A's "never scan" rule. Nested projects and the depth limit belong to Stage 2 discovery and are intentionally absent here.

**Placeholders.** None. Every code step carries the literal content to write, and every command states its expected output.

**Type consistency.** `SCOPE` is introduced in Task F and consumed by the same dispatcher lines. `target-claude-project.sh` is named identically in Task F's dispatch expression and Task G's filename. `project-common.sh` is created in Task F and sourced there. The fixture paths written in Task E are the exact paths read by Tasks G, H, and I. The marker strings (`Use tabs, not spaces`, `echo project-pre-edit`, `VENDOR-NEUTRAL-SHARED`, `Keep this project note.`) match between fixture, verifier, and ideal target.
