/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
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
brew install neofetch
brew install --cask wezterm
brew install --cask iterm2
brew install --cask visual-studio-code
brew install --cask brave-browser
brew install zsh-syntax-highlighting
brew install zoxide
brew install eza
brew install tmux
brew install cmatrix
brew install htop
brew install btop
brew install jq
brew install fzf
brew install --cask postman
brew install powerlevel10k

# #Sketchybar
# brew tap FelixKratz/formulae
# brew install sketchybar
# mkdir -p ~/.config/sketchybar/plugins
# cp $(brew --prefix)/share/sketchybar/examples/sketchybarrc ~/.config/sketchybar/sketchybarrc
# cp -r $(brew --prefix)/share/sketchybar/examples/plugins/ ~/.config/sketchybar/plugins/

# sketchybar
# brew services start sketchybar

#setup podman
brew install podman
brew install podman-desktop
podman machine init
podman machine start

#kubernetes
brew install kind
brew install kubectl
brew install kubernetes-cli 
brew install k9s

#apps
brew install --cask spotify
brew install --cask discord
brew install --cask slack
brew install --cask tidal
brew install --cask logitech-g-hub

