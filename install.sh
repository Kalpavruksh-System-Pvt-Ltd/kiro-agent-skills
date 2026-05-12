#!/usr/bin/env bash
#
# install.sh — Install kiro-agent skills to ~/.claude/skills/
#              and register skill routing in ~/.claude/CLAUDE.md
#
# Usage:
#   cd kiro-agent-skills && ./install.sh
#
# To update after a git pull, run ./install.sh again.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="$HOME/.claude/skills"
CLAUDE_MD="$HOME/.claude/CLAUDE.md"

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
install_skill "kiro-inventory"
install_skill "kiro-finance"

# Make binaries executable
find "$SKILLS_DIR/kiro-agent/bin" -type f -exec chmod +x {} + 2>/dev/null || true

# ── Register skill routing in ~/.claude/CLAUDE.md ──────────────────────────
KIRO_BLOCK_START="# kiro-agent skills"
KIRO_BLOCK_END="# /kiro-agent skills"

KIRO_SECTION=$(cat <<'BLOCK'
# kiro-agent skills

When the user asks about Kiro Beauty business data, invoke the matching skill
as the FIRST action. Do NOT answer directly — let the skill handle it.

| User asks about | Skill |
|---|---|
| Sales, revenue, orders, D2C, B2B, customers, AOV | `/kiro-sales` |
| Inventory, stock levels, SKUs, products, purchase orders, warehouses | `/kiro-inventory` |
| Invoices, credit notes, bills, expenses, payables, accounting | `/kiro-finance` |
| "Connect to Kiro", "Kiro login", authenticate | `/kiro-sales` |

# /kiro-agent skills
BLOCK
)

if [ ! -f "$CLAUDE_MD" ]; then
  echo "$KIRO_SECTION" > "$CLAUDE_MD"
  ok "Created ~/.claude/CLAUDE.md with kiro skill routing"
elif grep -q "$KIRO_BLOCK_START" "$CLAUDE_MD"; then
  # Replace existing block
  awk -v start="$KIRO_BLOCK_START" -v end="$KIRO_BLOCK_END" -v new="$KIRO_SECTION" '
    $0 == start { skip=1; printed=1; print new; next }
    $0 == end   { skip=0; next }
    !skip       { print }
  ' "$CLAUDE_MD" > "$CLAUDE_MD.tmp" && mv "$CLAUDE_MD.tmp" "$CLAUDE_MD"
  ok "Updated kiro skill routing in ~/.claude/CLAUDE.md"
else
  # Append
  printf '\n%s\n' "$KIRO_SECTION" >> "$CLAUDE_MD"
  ok "Added kiro skill routing to ~/.claude/CLAUDE.md"
fi

echo ""
echo "Done. Skills installed and routing configured."
echo ""
echo "  To authenticate:  ~/.claude/skills/kiro-agent/bin/kiro-login"
echo ""
echo "  Skills available:"
echo "    /kiro-sales      — D2C + B2B sales data"
echo "    /kiro-inventory   — Stock, products, purchase orders"
echo "    /kiro-finance     — Invoices, credit notes, bills"
echo ""
