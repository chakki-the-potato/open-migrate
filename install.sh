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
