#!/usr/bin/env bash
# Uninstaller for claude-glow.
#   - Removes ClaudeGlow.spoon from ~/.hammerspoon/Spoons
#   - Strips the loader lines from ~/.hammerspoon/init.lua
#   - Removes claude-glow hooks from ~/.claude/settings.json (backup saved)

set -euo pipefail

HS_DIR="$HOME/.hammerspoon"
HS_SPOONS="$HS_DIR/Spoons"
HS_INIT="$HS_DIR/init.lua"
CC_SETTINGS="$HOME/.claude/settings.json"

info() { printf "\033[1;34m==>\033[0m %s\n" "$*"; }
ok()   { printf "\033[1;32m  ✓\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m  !\033[0m %s\n" "$*"; }

command -v jq >/dev/null 2>&1 || { echo "jq is required for uninstall." >&2; exit 1; }

# --- remove Spoon ------------------------------------------------------------

info "Removing ClaudeGlow.spoon"
if [[ -d "$HS_SPOONS/ClaudeGlow.spoon" ]]; then
  rm -rf "$HS_SPOONS/ClaudeGlow.spoon"
  ok "Removed $HS_SPOONS/ClaudeGlow.spoon"
else
  warn "Not installed at $HS_SPOONS/ClaudeGlow.spoon"
fi

# --- strip loader lines from init.lua ---------------------------------------

if [[ -f "$HS_INIT" ]] && grep -q 'ClaudeGlow' "$HS_INIT"; then
  info "Cleaning Hammerspoon init.lua"
  BACKUP="$HS_INIT.bak.$(date +%Y%m%d%H%M%S)"
  cp "$HS_INIT" "$BACKUP"
  ok "Backed up to $BACKUP"

  # Drop our loader block (comment + two lines). Also drop any bare ClaudeGlow lines.
  awk '
    /^-- claude-glow:/ { skip = 3; next }
    skip > 0          { skip -= 1; next }
    /ClaudeGlow/      { next }
    { print }
  ' "$HS_INIT" > "$HS_INIT.tmp"
  mv "$HS_INIT.tmp" "$HS_INIT"
  ok "Loader lines removed"
fi

# --- strip hooks from Claude Code settings ----------------------------------

if [[ -f "$CC_SETTINGS" ]] && grep -q 'claudeglow' "$CC_SETTINGS"; then
  info "Removing claude-glow hooks from $CC_SETTINGS"
  BACKUP="$CC_SETTINGS.bak.$(date +%Y%m%d%H%M%S)"
  cp "$CC_SETTINGS" "$BACKUP"
  ok "Backed up to $BACKUP"

  TMP="$(mktemp)"
  jq '
    .hooks = (
      (.hooks // {})
      | to_entries
      | map(
          .value |= map(
            .hooks |= map(select((.command // "") | test("claudeglow") | not))
          )
          | .value |= map(select((.hooks // []) | length > 0))
        )
      | map(select((.value // []) | length > 0))
      | from_entries
    )
  ' "$CC_SETTINGS" > "$TMP"
  mv "$TMP" "$CC_SETTINGS"
  ok "Hooks removed"
fi

# --- reload Hammerspoon ------------------------------------------------------

if command -v osascript >/dev/null 2>&1; then
  osascript -e 'tell application "Hammerspoon" to reload' >/dev/null 2>&1 || true
fi

echo
echo "Uninstall complete. Restart Claude Code to drop the hooks from the active session."
