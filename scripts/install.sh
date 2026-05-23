/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.."; pwd)"

# Add brew to PATH for current session (works for both Apple Silicon and Intel)
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi
echo ""
echo "==> Installing packages from Brewfile..."
brew bundle --file="$REPO_ROOT/Brewfile"

# ── User preferences (user.conf) ──────────────────────────────────────────────
echo ""
echo "==> Loading user preferences..."
USER_CONF="$REPO_ROOT/user.conf"
if [[ ! -f "$USER_CONF" ]]; then
  cp "$REPO_ROOT/user.conf.example" "$USER_CONF"
  echo "  Created user.conf — edit it to customise your install, then re-run ./run.sh install"
  echo ""
  ${EDITOR:-nano} "$USER_CONF"
fi
# shellcheck source=/dev/null
source "$USER_CONF"
BROWSER="${BROWSER:-brave}"
MUSIC="${MUSIC:-apple-music}"
TERMINAL_APP="${TERMINAL:-wezterm}"
COMMS="${COMMS:-proton-mail}"
echo "  browser=$BROWSER  music=$MUSIC  terminal=$TERMINAL_APP  comms=$COMMS"

# Install browser
echo ""
echo "==> Installing browser ($BROWSER)..."
case "$BROWSER" in
  brave)   brew install --cask brave-browser   && echo "  ✓ Brave Browser" ;;
  chrome)  brew install --cask google-chrome   && echo "  ✓ Google Chrome" ;;
  firefox) brew install --cask firefox         && echo "  ✓ Firefox" ;;
  *)       echo "  ! Unknown BROWSER '$BROWSER' in user.conf — skipping" ;;
esac

# Install music app
echo ""
echo "==> Installing music app ($MUSIC)..."
case "$MUSIC" in
  apple-music) echo "  ✓ Apple Music is built-in — nothing to install" ;;
  spotify)     brew install --cask spotify && echo "  ✓ Spotify" ;;
  tidal)       brew install --cask tidal   && echo "  ✓ Tidal" ;;
  none)        echo "  - Skipping music app" ;;
  *)           echo "  ! Unknown MUSIC '$MUSIC' in user.conf — skipping" ;;
esac

# Install terminal emulator
echo ""
echo "==> Installing terminal ($TERMINAL_APP)..."
case "$TERMINAL_APP" in
  wezterm) brew install --cask wezterm && echo "  ✓ WezTerm" ;;
  iterm2)  brew install --cask iterm2  && echo "  ✓ iTerm2" ;;
  *)       echo "  ! Unknown TERMINAL '$TERMINAL_APP' in user.conf — skipping" ;;
esac

# Install comms apps
echo ""
echo "==> Installing comms apps ($COMMS)..."
IFS=',' read -ra COMMS_LIST <<< "$COMMS"
for _app in "${COMMS_LIST[@]}"; do
  _app="${_app// /}"
  case "$_app" in
    proton-mail) brew install --cask proton-mail && echo "  ✓ Proton Mail" ;;
    slack)       brew install --cask slack       && echo "  ✓ Slack" ;;
    discord)     brew install --cask discord     && echo "  ✓ Discord" ;;
    none)        echo "  - Skipping comms apps" ;;
    *)           echo "  ! Unknown comms app '$_app' in user.conf — skipping" ;;
  esac
done
# Patch Citrix window pattern into aerospace.toml if set
CITRIX_PATTERN="${WORK_CITRIX_WINDOW_PATTERN:-}"
AEROSPACE_TOML="$HOME/.config/aerospace/aerospace.toml"
if [[ -n "$CITRIX_PATTERN" && -f "$AEROSPACE_TOML" ]]; then
  echo ""
  echo "==> Applying Citrix window pattern to aerospace.toml..."
  sed -i '' "s|# if.window-title-regex-substring = 'YOUR_PATTERN_HERE'|if.window-title-regex-substring = '$CITRIX_PATTERN'|" "$AEROSPACE_TOML"
  echo "  ✓ Pattern '$CITRIX_PATTERN' applied (local only — not committed)"
fi
# nvm (Node Version Manager)
echo ""
echo "==> Installing nvm..."
if [[ ! -d "$HOME/.nvm" ]]; then
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/HEAD/install.sh | bash
  echo "  ✓ nvm installed"
else
  echo "  ✓ nvm already installed — skipping"
fi
# Load nvm for the rest of this script
export NVM_DIR="$HOME/.nvm"
[[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
nvm install --lts
nvm use --lts

# pyenv (Python Version Manager)
echo ""
echo "==> Installing pyenv..."
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)" 2>/dev/null || true
pyenv install --skip-existing 3
pyenv global "$(pyenv versions --bare | grep "^3" | tail -1)"
echo "  ✓ Python $(python3 --version 2>&1) set as global"

# TPM (Tmux Plugin Manager)
echo ""
echo "==> Installing TPM..."
if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
  echo "  ✓ TPM installed — plugins will load on next tmux session"
else
  echo "  ✓ TPM already installed — skipping"
fi

# WireGuard — official GUI via Mac App Store
echo ""
echo "==> Installing WireGuard..."
mas install 1451685025 || echo "! WireGuard install failed — make sure you're signed into the Mac App Store, then run: mas install 1451685025"


# Git global config
echo ""
echo "==> Configuring git..."
current_name="$(git config --global user.name 2>/dev/null || true)"
current_email="$(git config --global user.email 2>/dev/null || true)"

if [[ -n "$current_name" ]]; then
  echo "  user.name already set to '$current_name' — skipping"
else
  read -rp "  Enter your git user.name (e.g. John Smith): " git_name
  git config --global user.name "$git_name"
fi

if [[ -n "$current_email" ]]; then
  echo "  user.email already set to '$current_email' — skipping"
else
  echo "  Tip: use your GitHub no-reply email to keep it private."
  echo "       Find it at: https://github.com/settings/emails"
  echo "       It looks like: 12345678+username@users.noreply.github.com"
  read -rp "  Enter your git user.email: " git_email
  git config --global user.email "$git_email"
fi

# Auto-create remote branch on first push (no more --set-upstream)
git config --global push.autoSetupRemote true
# Use main as default branch name
git config --global init.defaultBranch main
# Pull with rebase by default
git config --global pull.rebase true
# Use Neovim as default editor
git config --global core.editor nvim
# Aliases
git config --global alias.st "status"
git config --global alias.co "checkout"
git config --global alias.br "branch"
git config --global alias.lg "log --oneline --graph --decorate --all"
git config --global alias.undo "reset --soft HEAD~1"
# delta — syntax-highlighted diffs
git config --global core.pager delta
git config --global interactive.diffFilter "delta --color-only"
git config --global delta.navigate true
git config --global delta.side-by-side true
git config --global merge.conflictstyle zdiff3
echo "  ✓ git configured"

# SSH key for GitHub (Ed25519)
echo ""
echo "==> Checking for existing SSH key..."
if [[ -f "$HOME/.ssh/id_ed25519" ]]; then
  echo "✓ SSH key already exists at ~/.ssh/id_ed25519 — skipping generation"
  eval "$(ssh-agent -s)"
  ssh-add --apple-use-keychain "$HOME/.ssh/id_ed25519" 2>/dev/null || true
else
  ssh-keygen -t ed25519 -C "$(git config user.email 2>/dev/null || echo 'github')" -f "$HOME/.ssh/id_ed25519" -N ""
  eval "$(ssh-agent -s)"
  ssh-add --apple-use-keychain "$HOME/.ssh/id_ed25519"
  pbcopy < "$HOME/.ssh/id_ed25519.pub"
  echo ""
  echo "  ✓ Public key copied to clipboard"
  echo "    Opening GitHub SSH key page..."
  open "https://github.com/settings/ssh/new"
  echo ""
  read -rp "Press ENTER once you have added the key to GitHub to continue..."
fi
ssh -T git@github.com 2>&1 | grep -q "successfully authenticated" \
  && echo "✓ GitHub SSH auth confirmed" \
  || echo "! Could not verify — check your key was saved correctly"

# GitHub CLI auth
echo ""
echo "==> Authenticating GitHub CLI..."
if gh auth status &>/dev/null; then
  echo "  ✓ gh already authenticated — skipping"
else
  gh auth login
fi

# Dotfiles — symlink repo files into ~/
bash "$(dirname "${BASH_SOURCE[0]}")/link.sh"

# DNS sync launchd daemon — triggers dns-sync.sh on every network change
echo ""
echo "==> Installing DNS sync network watcher..."
PLIST_SRC="${REPO_ROOT}/dotfiles/.config/launchd/dev.cluster.dns-sync.plist"
PLIST_DST="/Library/LaunchDaemons/dev.cluster.dns-sync.plist"
SCRIPTS_DIR="${REPO_ROOT}/scripts"
# Substitute the real scripts path into the plist
sed "s|SCRIPTS_DIR|${SCRIPTS_DIR}|g" "$PLIST_SRC" | sudo tee "$PLIST_DST" > /dev/null
sudo chown root:wheel "$PLIST_DST"
sudo chmod 644 "$PLIST_DST"
# Unload first in case it's already registered (idempotent)
sudo launchctl unload "$PLIST_DST" 2>/dev/null || true
sudo launchctl load "$PLIST_DST"
echo "  ✓ DNS sync watcher installed — syncing now..."
sudo "${SCRIPTS_DIR}/dns-sync.sh"

# VS Code extensions
echo ""
echo "==> Installing VS Code extensions..."
if command -v code &>/dev/null; then
  extensions=(
    # Go
    "golang.go"
    # React / JS / TS
    "dbaeumer.vscode-eslint"
    "esbenp.prettier-vscode" 
    # Kubernetes & Docker
    "ms-kubernetes-tools.vscode-kubernetes-tools"
    "ms-azuretools.vscode-docker"
    # Git
    "eamodio.gitlens"
    "mhutchie.git-graph"
    # Editor
    "vscodevim.vim"
    "catppuccin.catppuccin-vsc"
    "catppuccin.catppuccin-vsc-icons"
    "christian-kohler.path-intellisense"
    "usernamehw.errorlens"
    # Misc
    "ms-vscode-remote.remote-ssh"
    "tamasfe.even-better-toml"
    "redhat.vscode-yaml"
    # AI
    "anthropic.claude-code"
  )
  for ext in "${extensions[@]}"; do
    code --install-extension "$ext" --force 2>/dev/null && echo "  ✓ $ext" || echo "  ! $ext failed"
  done
else
  echo "  ! 'code' not found — open VS Code and run 'Install code command in PATH' from the command palette"
fi

# macOS defaults for developers
bash "$(dirname "${BASH_SOURCE[0]}")/defaults.sh"

# Final health check
echo ""
bash "$(dirname "${BASH_SOURCE[0]}")/check.sh"
