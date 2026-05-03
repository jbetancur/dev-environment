#!/usr/bin/env bash
set -euo pipefail

# Applies user.conf preferences to local config files without a full install.
# Safe to re-run at any time.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
USER_CONF="$REPO_ROOT/user.conf"

if [[ ! -f "$USER_CONF" ]]; then
  echo "! user.conf not found — copy user.conf.example to user.conf and edit it first"
  exit 1
fi

# shellcheck source=/dev/null
source "$USER_CONF"

BROWSER="${BROWSER:-brave}"
MUSIC="${MUSIC:-apple-music}"
TERMINAL_APP="${TERMINAL:-wezterm}"
COMMS="${COMMS:-proton-mail}"
CITRIX_PATTERN="${WORK_CITRIX_WINDOW_PATTERN:-}"

echo "==> Applying user.conf preferences..."
echo "  browser=$BROWSER  music=$MUSIC  terminal=$TERMINAL_APP  comms=$COMMS"

# ── Patch aerospace.toml ────────────────────────────────────────────────────
AEROSPACE_TOML="$HOME/.config/aerospace/aerospace.toml"
if [[ ! -f "$AEROSPACE_TOML" ]]; then
  echo "! ~/.config/aerospace/aerospace.toml not found — run './run.sh link' first"
  exit 1
fi

echo ""
echo "==> Patching aerospace.toml..."

# Citrix window pattern
if [[ -n "$CITRIX_PATTERN" ]]; then
  # Replace either the placeholder comment or an existing pattern value
  sed -i '' "s|# if.window-title-regex-substring = 'YOUR_PATTERN_HERE'|if.window-title-regex-substring = '$CITRIX_PATTERN'|" "$AEROSPACE_TOML"
  sed -i '' "s|if.window-title-regex-substring = '.*'|if.window-title-regex-substring = '$CITRIX_PATTERN'|" "$AEROSPACE_TOML"
  echo "  ✓ Citrix pattern set to '$CITRIX_PATTERN'"
else
  echo "  - WORK_CITRIX_WINDOW_PATTERN not set — skipping"
fi

# ── Reload AeroSpace if running ─────────────────────────────────────────────
if pgrep -x AeroSpace &>/dev/null; then
  echo ""
  echo "==> Reloading AeroSpace config..."
  aerospace reload-config && echo "  ✓ AeroSpace reloaded"
else
  echo ""
  echo "  - AeroSpace not running — start it to pick up changes"
fi

echo ""
echo "Done."
