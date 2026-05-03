/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Add brew to PATH for current session (works for both Apple Silicon and Intel)
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi
brew install --cask nikitabobko/tap/aerospace
brew install node
brew install neovim
brew install tree
brew install jesseduffield/lazygit/lazygit
# Fonts
brew install --cask font-hack-nerd-font
brew install font-meslo-lg-nerd-font
brew install font-sf-pro
brew install --cask sf-symbols
brew install ripgrep
brew install golang
brew install gh
brew install git
brew install fastfetch
brew install --cask wezterm
brew install --cask iterm2
brew install --cask visual-studio-code
brew install --cask brave-browser
brew install zsh-syntax-highlighting
brew install zsh-autosuggestions
brew install zoxide
brew install eza
brew install tmux
brew install cmatrix
brew install htop
brew install btop
brew install jq
brew install fzf
brew install --cask bruno
brew install powerlevel10k
# #Sketchybar
# brew tap FelixKratz/formulae
# brew install sketchybar
# mkdir -p ~/.config/sketchybar/plugins
# cp $(brew --prefix)/share/sketchybar/examples/sketchybarrc ~/.config/sketchybar/sketchybarrc
# cp -r $(brew --prefix)/share/sketchybar/examples/plugins/ ~/.config/sketchybar/plugins/
# sketchybar
# brew services start sketchybar
# Docker Desktop
brew install --cask docker
#kubernetes
brew install kind
brew install kubectl
brew install kubernetes-cli 
brew install k9s
#apps
#brew install --cask discord
brew install --cask slack
#brew install --cask tidal
#brew install --cask logitech-g-hub

# WireGuard — official GUI via Mac App Store
echo ""
echo "==> Installing WireGuard..."
brew install mas
if mas account &>/dev/null; then
  mas install 1451685025 || echo "! WireGuard install failed — install manually from the App Store"
else
  echo "! Sign into the Mac App Store first, then run: mas install 1451685025"
fi


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
  echo ""
  echo "==> Your public key (add this to GitHub → Settings → SSH Keys):"
  echo ""
  cat "$HOME/.ssh/id_ed25519.pub"
  echo ""
  echo "    Visit: https://github.com/settings/ssh/new"
  echo ""
  read -rp "Press ENTER once you have added the key to GitHub to continue..."
fi
ssh -T git@github.com 2>&1 | grep -q "successfully authenticated" \
  && echo "✓ GitHub SSH auth confirmed" \
  || echo "! Could not verify — check your key was saved correctly"
