# dev-environment

A single-script bootstrap for a fresh macOS machine. Run it once and walk away.

## Usage

```sh
git clone https://github.com/<you>/dev-environment.git
cd dev-environment
chmod +x install.sh link.sh update.sh defaults.sh restore-defaults.sh
./install.sh
```

To re-link dotfiles only (without reinstalling packages):

```sh
./link.sh
```

To upgrade all packages and re-link dotfiles:

```sh
./update.sh
```

> **Note:** Sign into the **Mac App Store** before running — the script uses `mas` to install WireGuard automatically.

## What it installs

### Package manager
- [Homebrew](https://brew.sh)

### Shell & terminal
| Tool | Purpose |
|---|---|
| WezTerm + iTerm2 | Terminal emulators |
| Zsh syntax highlighting | Command highlighting |
| Zsh autosuggestions | Fish-style suggestions |
| Powerlevel10k | Zsh prompt theme |
| zoxide | Smarter `cd` |
| eza | Modern `ls` replacement |
| fzf | Fuzzy finder |
| tmux | Terminal multiplexer |

### Fonts
- Hack Nerd Font
- MesloLG Nerd Font
- SF Pro + SF Symbols

### Development tools
| Tool | Purpose |
|---|---|
| Node.js | JavaScript runtime |
| Go | Go toolchain |
| Neovim | Text editor |
| Git + GitHub CLI (`gh`) | Version control |
| lazygit | Terminal Git UI |
| ripgrep | Fast grep |
| jq | JSON processor |

### Window management
- [AeroSpace](https://github.com/nikitabobko/AeroSpace) — tiling window manager

### Containers & Kubernetes
- Docker Desktop
- `kind`, `kubectl`, `kubernetes-cli`, `k9s`

### Apps
- Visual Studio Code
- Brave Browser
- Bruno (API client)
- Slack
- WireGuard (via Mac App Store)

### System utilities
- `htop` / `btop` — process monitors
- `fastfetch` — system info
- `tree` — directory tree
- `cmatrix` — for the aesthetic

## Dotfiles

Config files are **symlinked** from the repo into `~/` so edits to your live configs are automatically tracked in git.

| Repo file | Symlinked to |
|---|---|
| `.zshrc` | `~/.zshrc` |
| `.zprofile` | `~/.zprofile` |
| `.p10k.zsh` | `~/.p10k.zsh` |
| `.tmux.conf` | `~/.tmux.conf` |
| `.wezterm.lua` | `~/.wezterm.lua` |
| `.config/aerospace/` | `~/.config/aerospace/` |
| `.config/btop/` | `~/.config/btop/` |
| `.config/gh/` | `~/.config/gh/` |
| `.config/nvim/` | `~/.config/nvim/` |

## SSH key setup

The script automatically generates an **Ed25519 SSH key** at `~/.ssh/id_ed25519` (skipped if one already exists), adds it to the macOS Keychain, and prompts you to add it to GitHub before continuing.

## macOS defaults

Applied automatically by `install.sh` via `defaults.sh`. Before applying, **current values are backed up** to `~/.config/dev-environment/defaults-backup/` as plists. To revert everything:

```sh
./restore-defaults.sh
```

The following developer-friendly defaults are applied:

| Setting | Value |
|---|---|
| Finder: show hidden files | enabled |
| Finder: show all file extensions | enabled |
| Finder: show path bar and status bar | enabled |
| Finder: disable extension-change warning | enabled |
| Disable .DS_Store on network/USB volumes | enabled |
| Key repeat rate | fast (no press-and-hold) |
| Smart quotes / smart dashes | disabled |
| Dock: auto-hide with no delay | enabled |
| Dock: show recent apps | disabled |
| Screenshots: save to `~/Desktop/Screenshots` as PNG | enabled |

## Commented-out items

A few installs are commented out in `install.sh` and can be enabled as needed:

- **Sketchybar** — custom macOS menu bar
- **Discord**, **Tidal**, **Logitech G Hub**
