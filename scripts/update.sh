#!/usr/bin/env bash
set -euo pipefail

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
echo "==> Updating Node (nvm)..."
export NVM_DIR="$HOME/.nvm"
[[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
nvm install --lts
nvm use --lts

echo ""
echo "==> Updating Python (pyenv)..."
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)" 2>/dev/null || true
LATEST_PY3="$(pyenv install --list | grep -E '^\s+3\.[0-9]+\.[0-9]+$' | tail -1 | tr -d ' ')"
pyenv install --skip-existing "$LATEST_PY3"
pyenv global "$LATEST_PY3"
echo "  ✓ Python $LATEST_PY3 set as global"

echo ""
echo "==> Re-linking dotfiles..."
bash "$(dirname "${BASH_SOURCE[0]}")/link.sh"

echo ""
echo "Done."
