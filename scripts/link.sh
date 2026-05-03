#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../dotfiles" && pwd)"
BACKUP_DIR="$HOME/.config/dev-environment/dotfiles-backup/$(date +%Y%m%d_%H%M%S)"

echo "==> Symlinking dotfiles from $DOTFILES_DIR..."

# Root-level dotfiles
for file in .zshrc .zprofile .p10k.zsh .tmux.conf .wezterm.lua; do
  src="$DOTFILES_DIR/$file"
  dst="$HOME/$file"
  if [[ -f "$src" ]]; then
    if [[ -e "$dst" && ! -L "$dst" ]]; then
      mkdir -p "$BACKUP_DIR"
      cp "$dst" "$BACKUP_DIR/$file"
      echo "  backed up $dst -> $BACKUP_DIR/$file"
    fi
    ln -sf "$src" "$dst"
    echo "  ✓ $dst -> $src"
  fi
done

# .config subdirectories
mkdir -p "$HOME/.config"
for dir in "$DOTFILES_DIR/.config"/*/; do
  name="$(basename "$dir")"
  dst="$HOME/.config/$name"
  if [[ -e "$dst" && ! -L "$dst" ]]; then
    mkdir -p "$BACKUP_DIR/.config"
    cp -r "$dst" "$BACKUP_DIR/.config/$name"
    echo "  backed up $dst -> $BACKUP_DIR/.config/$name"
  fi
  ln -sf "$dir" "$dst"
  echo "  ✓ $dst -> $dir"
done

# VS Code settings (path has spaces, handled separately)
VSCODE_SRC="$DOTFILES_DIR/.config/vscode/settings.json"
VSCODE_DST="$HOME/Library/Application Support/Code/User/settings.json"
if [[ -f "$VSCODE_SRC" ]]; then
  if [[ -e "$VSCODE_DST" && ! -L "$VSCODE_DST" ]]; then
    mkdir -p "$BACKUP_DIR"
    cp "$VSCODE_DST" "$BACKUP_DIR/vscode-settings.json"
    echo "  backed up VS Code settings -> $BACKUP_DIR/vscode-settings.json"
  fi
  ln -sf "$VSCODE_SRC" "$VSCODE_DST"
  echo "  ✓ $VSCODE_DST -> $VSCODE_SRC"
fi

echo ""
if [[ -d "$BACKUP_DIR" ]]; then
  echo "  Previous files backed up to: $BACKUP_DIR"
fi
echo "Done."
