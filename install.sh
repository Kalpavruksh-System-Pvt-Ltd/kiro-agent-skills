#!/usr/bin/env bash
#
# install.sh — Install kiro-agent skills to ~/.claude/skills/
#
# Usage:
#   cd ~/.claude/skills/kiro-agent-skills
#   ./install.sh
#
# To update after a git pull, run ./install.sh again.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="$HOME/.claude/skills"

log()    { echo "  $1"; }
ok()     { echo "  [ok] $1"; }
skip()   { echo "  [--] $1"; }

echo ""
echo "Installing kiro-agent skills"
echo "============================="
echo ""

mkdir -p "$SKILLS_DIR"

install_skill() {
  local name="$1"
  local src="$REPO_DIR/$name"
  local dst="$SKILLS_DIR/$name"

  if [ ! -d "$src" ]; then
    log "Skipping $name (not found in repo)"
    return
  fi

  mkdir -p "$dst"
  cp -r "$src/." "$dst/"
  ok "~/.claude/skills/$name"
}

install_skill "kiro-agent"
install_skill "kiro-sales"

# Make binaries executable
find "$SKILLS_DIR/kiro-agent/bin" -type f -exec chmod +x {} + 2>/dev/null || true

echo ""
echo "Done. To authenticate:"
echo ""
echo "  ~/.claude/skills/kiro-agent/bin/kiro-login"
echo ""
echo "Then use the /kiro-sales skill in Claude."
echo ""
