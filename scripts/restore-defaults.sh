#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="$HOME/.config/dev-environment/defaults-backup"

if [[ ! -d "$BACKUP_DIR" ]]; then
  echo "No backup found at $BACKUP_DIR — run ./defaults.sh first to create one."
  exit 1
fi

echo "==> Restoring macOS defaults from backup..."
for plist in "$BACKUP_DIR"/*.plist; do
  domain="$(basename "$plist" .plist)"
  defaults import "$domain" "$plist" \
    && echo "  ✓ $domain restored" \
    || echo "  ! $domain — restore failed (skipping)"
done

# Restart affected apps
for app in Finder Dock SystemUIServer Safari; do
  killall "$app" &>/dev/null || true
done

echo ""
echo "Done. Defaults restored to pre-install state."
