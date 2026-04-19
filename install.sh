#!/usr/bin/env bash
# Installer for claude-glow.
#   - Copies ClaudeGlow.spoon into ~/.hammerspoon/Spoons
#   - Ensures ~/.hammerspoon/init.lua loads and starts the Spoon
#   - Merges the Claude Code hooks into ~/.claude/settings.json (backup saved)
#
# Re-runnable: safe to run multiple times; skips steps already applied.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HS_DIR="$HOME/.hammerspoon"
HS_SPOONS="$HS_DIR/Spoons"
HS_INIT="$HS_DIR/init.lua"
CC_SETTINGS="$HOME/.claude/settings.json"

info()  { printf "\033[1;34m==>\033[0m %s\n" "$*"; }
ok()    { printf "\033[1;32m  ✓\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m  !\033[0m %s\n" "$*"; }
die()   { printf "\033[1;31m  ✗\033[0m %s\n" "$*"; exit 1; }

# --- dependency checks -------------------------------------------------------

info "Checking dependencies"

[[ "$(uname -s)" == "Darwin" ]] || die "claude-glow is macOS-only (Hammerspoon requirement)."

if ! [[ -d "/Applications/Hammerspoon.app" ]] && ! command -v hs >/dev/null 2>&1; then
  die "Hammerspoon not found. Install it first: https://www.hammerspoon.org (or: brew install --cask hammerspoon)"
fi
ok "Hammerspoon found"

command -v jq >/dev/null 2>&1 || die "jq not found. Install it: brew install jq"
ok "jq found"

# --- install Spoon -----------------------------------------------------------

info "Installing ClaudeGlow.spoon"

mkdir -p "$HS_SPOONS"
rm -rf "$HS_SPOONS/ClaudeGlow.spoon"
cp -R "$REPO_DIR/ClaudeGlow.spoon" "$HS_SPOONS/ClaudeGlow.spoon"
ok "Spoon copied to $HS_SPOONS/ClaudeGlow.spoon"

# --- patch Hammerspoon init.lua ---------------------------------------------

info "Wiring Hammerspoon init.lua"

touch "$HS_INIT"
if grep -q 'ClaudeGlow' "$HS_INIT"; then
  ok "init.lua already loads ClaudeGlow"
else
  {
    printf '\n-- claude-glow: ambient screen-border glow when Claude Code needs input\n'
    printf 'hs.loadSpoon("ClaudeGlow")\n'
    printf 'spoon.ClaudeGlow:start()\n'
  } >> "$HS_INIT"
  ok "Appended loader to $HS_INIT"
fi

# --- merge Claude Code hooks -------------------------------------------------

info "Merging Claude Code hooks into $CC_SETTINGS"

mkdir -p "$(dirname "$CC_SETTINGS")"
[[ -f "$CC_SETTINGS" ]] || echo '{}' > "$CC_SETTINGS"

if grep -q 'claudeglowon' "$CC_SETTINGS"; then
  warn "Claude Code settings already contain claudeglow hooks — skipping merge."
  warn "Run ./uninstall.sh first if you want to reapply."
else
  BACKUP="$CC_SETTINGS.bak.$(date +%Y%m%d%H%M%S)"
  cp "$CC_SETTINGS" "$BACKUP"
  ok "Backed up existing settings to $BACKUP"

  TMP="$(mktemp)"
  jq --slurpfile add "$REPO_DIR/hooks.json" '
    .hooks = (
      (.hooks // {}) as $existing
      | $add[0].hooks as $incoming
      | reduce ($incoming | keys[]) as $k ($existing;
          .[$k] = ((.[$k] // []) + $incoming[$k])
        )
    )
  ' "$CC_SETTINGS" > "$TMP"
  mv "$TMP" "$CC_SETTINGS"
  ok "Hooks merged"
fi

# --- reload Hammerspoon ------------------------------------------------------

info "Reloading Hammerspoon config"
if command -v osascript >/dev/null 2>&1; then
  osascript -e 'tell application "Hammerspoon" to reload' >/dev/null 2>&1 \
    && ok "Hammerspoon reloaded" \
    || warn "Couldn't reload Hammerspoon automatically — open it and click Reload Config."
else
  warn "osascript unavailable — reload Hammerspoon manually."
fi

cat <<EOF

Done. Restart Claude Code to pick up the hook changes.

Test it: run a command that needs permission — the screen border should glow orange
until you approve. The glow also fires when Claude finishes a turn, asks a question,
or when an MCP server elicits input.

EOF
