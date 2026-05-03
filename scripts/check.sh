#!/usr/bin/env bash

PASS=0
FAIL=0

check() {
  local label="$1"
  local cmd="$2"
  if eval "$cmd" &>/dev/null; then
    echo "  ✓ $label"
    ((PASS++))
  else
    echo "  ✗ $label"
    ((FAIL++))
  fi
}

echo "==> Health check..."
echo ""

echo "--- Core ---"
check "Homebrew"     "command -v brew"
check "Git"          "command -v git"
check "GitHub CLI"   "gh auth status"
check "SSH → GitHub" "ssh -T git@github.com 2>&1 | grep -q 'successfully authenticated'"

echo ""
echo "--- Languages ---"
check "Go"           "command -v go"
check "Node (nvm)"   "command -v node"
check "Python (pyenv)" "command -v python3"

echo ""
echo "--- Shell ---"
check "Neovim"       "command -v nvim"
check "tmux"         "command -v tmux"
check "TPM"          "[[ -d $HOME/.tmux/plugins/tpm ]]"
check "zoxide"       "command -v zoxide"
check "fzf"          "command -v fzf"
check "eza"          "command -v eza"
check "ripgrep"      "command -v rg"
check "lazygit"      "command -v lazygit"

echo ""
echo "--- Kubernetes ---"
check "kubectl"      "command -v kubectl"
check "kind"         "command -v kind"
check "k9s"          "command -v k9s"
check "Docker"       "command -v docker"

echo ""
echo "--- Apps ---"
check "VS Code (code)" "command -v code"

echo ""
echo "--- Dotfiles ---"
for file in .zshrc .zprofile .p10k.zsh .tmux.conf .wezterm.lua; do
  check "$file is a symlink" "[[ -L $HOME/$file ]]"
done
for dir in aerospace btop gh nvim; do
  check ".config/$dir is a symlink" "[[ -L $HOME/.config/$dir ]]"
done
check "VS Code settings is a symlink" "[[ -L \"$HOME/Library/Application Support/Code/User/settings.json\" ]]"

echo ""
if (( FAIL == 0 )); then
  echo "All $PASS checks passed."
else
  echo "$PASS passed, $FAIL failed."
  exit 1
fi
