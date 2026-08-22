#!/usr/bin/env bash
# Creates the pre-migration state of a target, so a verification run is reproducible
# from a clean checkout.
#
# The verifiers assert two different things about a target: that the migrated content
# arrived, and that whatever was already there survived. The second half needs the target
# to hold something before the migration runs — otherwise "existing content preserved"
# passes for the trivial reason that there was no existing content. That starting state
# used to exist only as directories on one machine, which made the whole suite
# unreproducible. This script is the missing half.
#
#   ./scripts/seed-target.sh <tool> <dest>     tool: claude | codex | cursor | grok | claude-project
#
# <dest> is created if absent and must be empty (or --force to wipe it first). Seeding
# never touches a real tool home: a destination under $HOME/.claude, $HOME/.codex,
# $HOME/.cursor, or $HOME/.grok is refused outright.
set -euo pipefail

usage() {
  echo "usage: seed-target.sh <claude|codex|cursor|grok|claude-project> <dest> [--force]" >&2
  exit 2
}

tool="${1:-}"; dest="${2:-}"; force="${3:-}"
[ -n "$tool" ] && [ -n "$dest" ] || usage

# A seed writes files unconditionally, so pointing it at a real home would overwrite
# live configuration. Refuse before creating anything.
abs_dest="$(cd "$(dirname "$dest")" 2>/dev/null && pwd)/$(basename "$dest")" || abs_dest="$dest"
for real in "$HOME/.claude" "$HOME/.codex" "$HOME/.cursor" "$HOME/.grok"; do
  case "$abs_dest" in
    "$real"|"$real"/*)
      echo "refusing to seed inside a real tool home: $abs_dest" >&2
      exit 1 ;;
  esac
done

if [ -d "$dest" ] && [ -n "$(ls -A "$dest" 2>/dev/null)" ]; then
  if [ "$force" = "--force" ]; then
    rm -rf "${dest:?}"
  else
    echo "destination is not empty: $dest (pass --force to wipe it)" >&2
    exit 1
  fi
fi
mkdir -p "$dest"

existing_rules() {
  cat > "$1" <<'EOF'
# Existing

Keep me.
EOF
}

case "$tool" in
  claude)
    existing_rules "$dest/CLAUDE.md"
    cat > "$dest/settings.json" <<'EOF'
{
  "model": "claude-fable-5",
  "env": { "EXISTING_KEY": "keep" },
  "permissions": { "allow": ["Bash(ls:*)"], "deny": [] },
  "hooks": {
    "PreToolUse": [
      { "matcher": "Read", "hooks": [ { "type": "command", "command": "echo existing-pre" } ] }
    ]
  }
}
EOF
    ;;

  codex)
    existing_rules "$dest/AGENTS.md"
    cat > "$dest/config.toml" <<'EOF'
model = "gpt-5.6-sol"

[shell_environment_policy.set]
EXISTING_KEY = "keep"
EOF
    ;;

  cursor)
    cat > "$dest/hooks.json" <<'EOF'
{ "version": 1, "hooks": { "sessionStart": [ { "command": "echo existing-session", "type": "command" } ] } }
EOF
    cat > "$dest/cli-config.json" <<'EOF'
{ "version": 1, "approvalMode": "allowlist", "permissions": { "allow": ["Shell(ls)"], "deny": [] } }
EOF
    # skills-cursor/ is an app-managed area. It is seeded so the verifier can prove the
    # migration left it alone; nothing should ever write here.
    mkdir -p "$dest/skills-cursor/canvas"
    cat > "$dest/skills-cursor/canvas/SKILL.md" <<'EOF'
---
name: canvas
description: APP-MANAGED-DECOY-UNTOUCHED — app-managed skill, never a migration destination
---

APP-MANAGED-DECOY-UNTOUCHED
EOF
    ;;

  grok)
    existing_rules "$dest/AGENTS.md"
    cat > "$dest/config.toml" <<'EOF'
model = "grok-5-code"

[shell_environment_policy]
inherit = "core"

[shell_environment_policy.set]
EXISTING_KEY = "keep"

[permission]
allow = ["Bash(ls:*)"]
EOF
    ;;

  claude-project)
    # A project target is one directory holding both sides. The Codex source layer is
    # copied in from the fixture; the Claude side starts with only a root CLAUDE.md,
    # which is what the "existing content preserved" checks read.
    repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
    src="$repo_dir/test/fixtures/codex-project"
    [ -d "$src" ] || { echo "missing fixture: $src" >&2; exit 1; }
    cp -R "$src/." "$dest/"
    cat > "$dest/CLAUDE.md" <<'EOF'
# Project notes

Keep this project note.
EOF
    ;;

  *) usage ;;
esac

echo "seeded $tool: $dest"
