#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../dotfiles" && pwd)"

echo "==> Symlinking dotfiles from $DOTFILES_DIR..."

# Root-level dotfiles
for file in .zshrc .zprofile .p10k.zsh .tmux.conf .wezterm.lua; do
  src="$DOTFILES_DIR/$file"
  dst="$HOME/$file"
  if [[ -f "$src" ]]; then
    ln -sf "$src" "$dst"
    echo "  ✓ $dst -> $src"
  fi
done

# .config subdirectories
mkdir -p "$HOME/.config"
for dir in "$DOTFILES_DIR/.config"/*/; do
  name="$(basename "$dir")"
  dst="$HOME/.config/$name"
  ln -sf "$dir" "$dst"
  echo "  ✓ $dst -> $dir"
done

# Clean up any .bak files left from previous runs
echo ""
echo "==> Cleaning up .bak files..."
for file in .zshrc .zprofile .p10k.zsh .tmux.conf .wezterm.lua; do
  bak="$HOME/${file}.bak"
  if [[ -f "$bak" ]]; then
    rm "$bak"
    echo "  removed $bak"
  fi
done
for dir in "$DOTFILES_DIR/.config"/*/; do
  name="$(basename "$dir")"
  bak="$HOME/.config/${name}.bak"
  if [[ -e "$bak" ]]; then
    rm -rf "$bak"
    echo "  removed $bak"
  fi
done

echo ""
echo "Done."
