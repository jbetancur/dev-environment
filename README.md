# dev-environment

My personal macOS bootstrap for a fresh machine.

This is opinionated toward how I work as a **Go, React, and Kubernetes developer** — terminal-first, keyboard-driven, minimal GUI friction. It installs the tools I actually use, symlinks my dotfiles, and sets macOS defaults the way I like them.

If you're of similar mind clone it and make it your own!

## Usage

```sh
git clone https://github.com/jbetancur/dev-environment.git
cd dev-environment
./run.sh
```

| Command | Description |
|---|---|
| `./run.sh` | Full bootstrap (default) |
| `./run.sh install` | Same as above, explicit |
| `./run.sh update` | Upgrade packages + re-link dotfiles |
| `./run.sh link` | Re-link dotfiles only |
| `./run.sh defaults` | Apply macOS defaults |
| `./run.sh restore` | Revert macOS defaults from backup |
| `./run.sh uninstall` | Remove all packages, casks, and symlinks (keeps Homebrew) |

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
| `dotfiles/.zshrc` | `~/.zshrc` |
| `dotfiles/.zprofile` | `~/.zprofile` |
| `dotfiles/.p10k.zsh` | `~/.p10k.zsh` |
| `dotfiles/.tmux.conf` | `~/.tmux.conf` |
| `dotfiles/.wezterm.lua` | `~/.wezterm.lua` |
| `dotfiles/.config/aerospace/` | `~/.config/aerospace/` |
| `dotfiles/.config/btop/` | `~/.config/btop/` |
| `dotfiles/.config/gh/` | `~/.config/gh/` |
| `dotfiles/.config/nvim/` | `~/.config/nvim/` |

## SSH key setup

The script automatically generates an **Ed25519 SSH key** at `~/.ssh/id_ed25519` (skipped if one already exists), adds it to the macOS Keychain, and prompts you to add it to GitHub before continuing.

## macOS defaults

Applied automatically by `scripts/install.sh` via `scripts/defaults.sh`. Before applying, **current values are backed up** to `~/.config/dev-environment/defaults-backup/` as plists. To revert everything, see the restore command in [Usage](#usage).

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

A few installs are commented out in `scripts/install.sh` and can be enabled as needed:

- **Sketchybar** — custom macOS menu bar
- **Discord**, **Tidal**, **Logitech G Hub**
