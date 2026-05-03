#!/usr/bin/env bash
set -euo pipefail

echo "==> This will uninstall all packages, casks, and remove dotfile symlinks."
echo "    Homebrew itself will NOT be removed."
echo ""
read -rp "Are you sure? (y/N) " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

# Restore macOS defaults first if a backup exists
BACKUP_DIR="$HOME/.config/dev-environment/defaults-backup"
if [[ -d "$BACKUP_DIR" ]]; then
  echo ""
  echo "==> Restoring macOS defaults..."
  bash "$(dirname "${BASH_SOURCE[0]}")/restore-defaults.sh"
fi

# Remove dotfile symlinks
echo ""
echo "==> Removing dotfile symlinks..."
for file in .zshrc .zprofile .p10k.zsh .tmux.conf .wezterm.lua; do
  dst="$HOME/$file"
  if [[ -L "$dst" ]]; then
    rm "$dst"
    echo "  removed $dst"
  fi
done
for name in aerospace btop gh nvim; do
  dst="$HOME/.config/$name"
  if [[ -L "$dst" ]]; then
    rm "$dst"
    echo "  removed $dst"
  fi
done

# Uninstall casks
echo ""
echo "==> Uninstalling casks..."
for cask in \
  nikitabobko/tap/aerospace \
  font-hack-nerd-font \
  sf-symbols \
  wezterm \
  iterm2 \
  visual-studio-code \
  brave-browser \
  bruno \
  docker \
  slack; do
  brew uninstall --cask --force "$cask" 2>/dev/null && echo "  removed $cask" || echo "  ! $cask not installed, skipping"
done

# Uninstall formulae
echo ""
echo "==> Uninstalling packages..."
for pkg in \
  node \
  neovim \
  tree \
  lazygit \
  font-meslo-lg-nerd-font \
  font-sf-pro \
  ripgrep \
  golang \
  gh \
  git \
  fastfetch \
  zsh-syntax-highlighting \
  zsh-autosuggestions \
  zoxide \
  eza \
  tmux \
  cmatrix \
  htop \
  btop \
  jq \
  fzf \
  powerlevel10k \
  kind \
  kubectl \
  kubernetes-cli \
  k9s \
  mas; do
  brew uninstall --force "$pkg" 2>/dev/null && echo "  removed $pkg" || echo "  ! $pkg not installed, skipping"
done

echo ""
echo "Done. Homebrew is still installed."
echo "WireGuard (Mac App Store) must be removed manually via Launchpad."
