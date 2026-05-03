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

# Re-run user.conf installs in case preferences changed
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.."; pwd)"
USER_CONF="$REPO_ROOT/user.conf"
if [[ -f "$USER_CONF" ]]; then
  echo ""
  echo "==> Re-installing user.conf apps..."
  # shellcheck source=/dev/null
  source "$USER_CONF"
  BROWSER="${BROWSER:-brave}"
  MUSIC="${MUSIC:-apple-music}"
  TERMINAL_APP="${TERMINAL:-wezterm}"
  COMMS="${COMMS:-proton-mail}"
  case "$BROWSER" in
    brave)   brew install --cask brave-browser   2>/dev/null || true ;;
    chrome)  brew install --cask google-chrome   2>/dev/null || true ;;
    firefox) brew install --cask firefox         2>/dev/null || true ;;
  esac
  case "$MUSIC" in
    spotify) brew install --cask spotify 2>/dev/null || true ;;
    tidal)   brew install --cask tidal   2>/dev/null || true ;;
  esac
  case "$TERMINAL_APP" in
    wezterm) brew install --cask wezterm 2>/dev/null || true ;;
    iterm2)  brew install --cask iterm2  2>/dev/null || true ;;
  esac
  IFS=',' read -ra COMMS_LIST <<< "$COMMS"
  for _app in "${COMMS_LIST[@]}"; do
    _app="${_app// /}"
    case "$_app" in
      proton-mail) brew install --cask proton-mail 2>/dev/null || true ;;
      slack)       brew install --cask slack       2>/dev/null || true ;;
      discord)     brew install --cask discord     2>/dev/null || true ;;
    esac
  done
  echo "  ✓ user.conf apps up to date"
fi

echo ""
echo "Done."
