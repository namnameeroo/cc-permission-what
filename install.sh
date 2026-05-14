#!/bin/bash
# install.sh — Install the Claude Code permission-announce system into ~/.claude.
#
# Idempotent: re-running is safe. Existing settings.json is patched with `jq`
# and backed up to `<file>.bak.<unixtime>` before mutation. CLAUDE.md gets the
# @import line appended only if not already present.
#
# Usage:
#   ./install.sh                 # install into $HOME/.claude
#   CLAUDE_DIR=/path ./install.sh  # install into custom dir
#
# Dependencies: bash, jq, grep.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"

# --- Dependency check ---------------------------------------------------------
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq is required. Install with: brew install jq" >&2; exit 1; }

# --- Ensure target directories -----------------------------------------------
mkdir -p "$CLAUDE_DIR/modules" "$CLAUDE_DIR/hooks"

# --- 1. Module file -----------------------------------------------------------
cp "$SCRIPT_DIR/modules/permission-announce.md" "$CLAUDE_DIR/modules/permission-announce.md"
echo "✓ $CLAUDE_DIR/modules/permission-announce.md"

# --- 2. Hook script -----------------------------------------------------------
cp "$SCRIPT_DIR/hooks/explain-bash.sh" "$CLAUDE_DIR/hooks/explain-bash.sh"
chmod +x "$CLAUDE_DIR/hooks/explain-bash.sh"
echo "✓ $CLAUDE_DIR/hooks/explain-bash.sh (+x)"

# --- 3. CLAUDE.md @import line ------------------------------------------------
CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
IMPORT_LINE="@~/.claude/modules/permission-announce.md"

if [ ! -f "$CLAUDE_MD" ]; then
  printf '%s\n' "$IMPORT_LINE" > "$CLAUDE_MD"
  echo "✓ $CLAUDE_MD (created with @import)"
elif ! grep -qF "$IMPORT_LINE" "$CLAUDE_MD"; then
  printf '\n%s\n' "$IMPORT_LINE" >> "$CLAUDE_MD"
  echo "✓ $CLAUDE_MD (@import appended)"
else
  echo "= $CLAUDE_MD (@import already present, skipped)"
fi

# --- 4. settings.json PreToolUse hook ----------------------------------------
SETTINGS="$CLAUDE_DIR/settings.json"
HOOK_CMD="$CLAUDE_DIR/hooks/explain-bash.sh"

if [ ! -f "$SETTINGS" ]; then
  cat > "$SETTINGS" <<EOF
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "$HOOK_CMD" }
        ]
      }
    ]
  }
}
EOF
  echo "✓ $SETTINGS (created with PreToolUse hook)"
else
  ALREADY=$(jq --arg cmd "$HOOK_CMD" '
    (.hooks.PreToolUse // [])
    | map(.hooks // [])
    | flatten
    | map(.command)
    | index($cmd)
  ' "$SETTINGS")

  if [ "$ALREADY" != "null" ]; then
    echo "= $SETTINGS (PreToolUse hook already present, skipped)"
  else
    BACKUP="$SETTINGS.bak.$(date +%s)"
    cp "$SETTINGS" "$BACKUP"
    tmp=$(mktemp)
    jq --arg cmd "$HOOK_CMD" '
      .hooks //= {} |
      .hooks.PreToolUse //= [] |
      .hooks.PreToolUse += [{
        "matcher": "Bash",
        "hooks": [{ "type": "command", "command": $cmd }]
      }]
    ' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
    echo "✓ $SETTINGS (PreToolUse hook appended, backup → $BACKUP)"
  fi
fi

echo
echo "──────────────────────────────────────────────────────"
echo "Install complete."
echo
echo "Quick check (hook smoke test):"
echo "  echo '{\"tool_input\":{\"command\":\"gh pr list\"}}' | $HOOK_CMD"
echo
echo "Expected output: [command-hint] 📖 현재 레포의 PR 목록 조회"
echo
echo "Start a NEW Claude Code session for the CLAUDE.md rule to take effect."
echo "──────────────────────────────────────────────────────"
