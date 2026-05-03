#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="$HOME/.config/dev-environment/defaults-backup"
mkdir -p "$BACKUP_DIR"

echo "==> Backing up current defaults to $BACKUP_DIR..."
for domain in \
  com.apple.finder \
  NSGlobalDomain \
  com.apple.desktopservices \
  com.apple.dock \
  com.apple.screencapture; do
  defaults export "$domain" "$BACKUP_DIR/$domain.plist" 2>/dev/null \
    && echo "  ✓ $domain" \
    || echo "  ! $domain — skipped (domain may not exist yet)"
done

echo ""
echo "==> Applying macOS defaults..."

# Finder: show hidden files
defaults write com.apple.finder AppleShowAllFiles -bool true
# # Finder: show all file extensions
# defaults write NSGlobalDomain AppleShowAllExtensions -bool true
# # Finder: show path bar and status bar
# defaults write com.apple.finder ShowPathbar -bool true
# defaults write com.apple.finder ShowStatusBar -bool true
# Finder: disable the warning when changing a file extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
# Disable .DS_Store on network and USB volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# Key repeat — essential for Neovim/terminal use
# Disables press-and-hold accent menu so key repeat works in all apps
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15

# # Disable smart quotes and smart dashes (stop mangling code in Messages/Notes)
# defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
# defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

# Dock: auto-hide
defaults write com.apple.dock autohide -bool true
# Mission Control: don't reorder spaces based on recent use (essential for AeroSpace)
defaults write com.apple.dock mru-spaces -bool false
# defaults write com.apple.dock autohide-delay -float 0
# defaults write com.apple.dock autohide-time-modifier -float 0.4
# # Dock: don't show recent apps
# defaults write com.apple.dock show-recents -bool false

# Screenshots: save to ~/Desktop/Screenshots, PNG
mkdir -p "$HOME/Desktop/Screenshots"
defaults write com.apple.screencapture location -string "$HOME/Desktop/Screenshots"
defaults write com.apple.screencapture type -string "png"

# Restart affected apps to pick up changes
for app in Finder Dock SystemUIServer; do
  killall "$app" &>/dev/null || true
done

echo "  ✓ macOS defaults applied"
echo "  Restore anytime with: ./restore-defaults.sh"
