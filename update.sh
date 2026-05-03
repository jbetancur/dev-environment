#!/usr/bin/env bash
set -euo pipefail

# Ask for sudo upfront and keep the session alive
sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

echo "==> Updating Homebrew..."
brew update

echo ""
echo "==> Upgrading packages..."
brew upgrade

echo ""
echo "==> Upgrading casks..."
brew upgrade --cask --greedy

echo ""
echo "==> Cleaning up..."
brew cleanup

echo ""
echo "==> Re-linking dotfiles..."
bash "$(dirname "${BASH_SOURCE[0]}")/link.sh"

echo ""
echo "Done."
