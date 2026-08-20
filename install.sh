#!/usr/bin/env bash
set -euo pipefail

dest="${1:-claude}"
case "$dest" in
  claude) target="$HOME/.claude/skills/migrate" ;;
  *) echo "unsupported destination: $dest (phase 1 supports: claude)" >&2; exit 1 ;;
esac

src_dir="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$target"
cp "$src_dir/adapters/$dest/SKILL.md" "$target/SKILL.md"
rm -rf "$target/core"
cp -R "$src_dir/core" "$target/core"
echo "installed: $target"
