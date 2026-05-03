#!/usr/bin/env bash
set -euo pipefail

BACKUP_ROOT="$HOME/.config/dev-environment/dotfiles-backup"

if [[ ! -d "$BACKUP_ROOT" ]] || [[ -z "$(ls -A "$BACKUP_ROOT" 2>/dev/null)" ]]; then
  echo "No dotfile backups found at $BACKUP_ROOT"
  exit 1
fi

# List available backups
echo "Available backups:"
echo ""
backups=()
i=1
for dir in "$BACKUP_ROOT"/*/; do
  echo "  $i) $(basename "$dir")"
  backups+=("$dir")
  ((i++))
done

echo ""
read -rp "Pick a backup to restore (1-${#backups[@]}): " choice

if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#backups[@]} )); then
  echo "Invalid selection."
  exit 1
fi

BACKUP_DIR="${backups[$((choice - 1))]}"
echo ""
echo "==> Restoring from $BACKUP_DIR..."

# Root-level dotfiles
for file in .zshrc .zprofile .p10k.zsh .tmux.conf .wezterm.lua; do
  src="$BACKUP_DIR/$file"
  dst="$HOME/$file"
  if [[ -f "$src" ]]; then
    # Remove symlink if present
    [[ -L "$dst" ]] && rm "$dst"
    cp "$src" "$dst"
    echo "  ✓ restored $dst"
  fi
done

# .config subdirectories
if [[ -d "$BACKUP_DIR/.config" ]]; then
  for dir in "$BACKUP_DIR/.config"/*/; do
    name="$(basename "$dir")"
    dst="$HOME/.config/$name"
    [[ -L "$dst" ]] && rm "$dst"
    cp -r "$dir" "$dst"
    echo "  ✓ restored $dst"
  done
fi

echo ""
echo "Done. Files restored from $(basename "$BACKUP_DIR")."
