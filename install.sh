#!/usr/bin/env bash
set -euo pipefail

dest="${1:-claude}"
case "$dest" in
  claude) target="$HOME/.claude/skills/migrate" ;;
  codex)  target="${CODEX_HOME:-$HOME/.codex}/skills/migrate" ;;
  cursor) target="$HOME/.cursor/skills/migrate" ;;
  *) echo "unsupported destination: $dest (supported: claude, codex, cursor)" >&2; exit 1 ;;
esac

src_dir="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$target"
cp "$src_dir/adapters/$dest/SKILL.md" "$target/SKILL.md"
rm -rf "$target/core"
cp -R "$src_dir/core" "$target/core"
rm -f "$target/core/tools/_template.md"
echo "installed: $target"
