# dev-environment

My personal macOS bootstrap for a fresh machine.

This is opinionated toward how I work as a **Go, React, and Kubernetes developer** terminal-first, keyboard-driven, minimal GUI friction. It installs the tools I use, symlinks my dotfiles, and sets macOS defaults.

If you're of similar mind clone it and make it your own!

## Usage

```sh
git clone https://github.com/jbetancur/dev-environment.git
cd dev-environment
./run.sh
```

| Command | Description |
| --- | --- |
| `./run.sh` | Full bootstrap (default) |
| `./run.sh install` | Same as above, explicit |
| `./run.sh update` | Upgrade packages + re-link dotfiles |
| `./run.sh link` | Re-link dotfiles only |
| `./run.sh defaults` | Apply macOS defaults |
| `./run.sh check` | Verify all tools are installed and working |
| `./run.sh restore` | Revert macOS defaults from backup |
| `./run.sh restore-dotfiles` | Restore dotfiles from a previous backup |
| `./run.sh uninstall` | Remove all packages, casks, and symlinks (keeps Homebrew) |

> **Note:** Sign into the **Mac App Store** before running — the script uses `mas` to install WireGuard automatically.

## Customization

This repo is designed to be forked and tailored. The main levers:

- **Brewfile** — add or remove formulae, casks, and Mac App Store apps; it's the single source of truth for everything Homebrew installs
- **`dotfiles/`** — swap in your own shell, editor, and tool configs; they're symlinked so live edits are tracked in git automatically
- **`scripts/install.sh`** — uncomment optional items (Sketchybar, Discord, etc.) or add your own install steps
- **`scripts/defaults.sh`** — adjust or remove macOS defaults that don't match your workflow

Fork the repo, change what you like, and run `./run.sh` on any new machine.

## What it installs

### Package manager

- [Homebrew](https://brew.sh)

### Shell & terminal

| Tool | Purpose |
| --- | --- |
| WezTerm + iTerm2 | Terminal emulators |
| Zsh syntax highlighting | Command highlighting |
| Zsh autosuggestions | Fish-style suggestions |
| Powerlevel10k | Zsh prompt theme |
| zoxide | Smarter `cd` |
| eza | Modern `ls` replacement |
| fzf | Fuzzy finder |
| tmux + TPM | Terminal multiplexer + plugin manager |

### Fonts

- Hack Nerd Font
- MesloLG Nerd Font
- SF Pro + SF Symbols

### Development tools

| Tool | Purpose |
| --- | --- |
| nvm + Node.js LTS | Node version manager |
| pyenv + Python 3 | Python version manager |
| Go | Go toolchain |
| Neovim | Text editor |
| Git + GitHub CLI (`gh`) | Version control |
| lazygit | Terminal Git UI |
| ripgrep | Fast grep |
| jq | JSON processor |

### VS Code extensions

| Extension | Purpose |
| --- | --- |
| `golang.go` | Go language support |
| `vscodevim.vim` | Vim keybindings |
| `dbaeumer.vscode-eslint` | ESLint |
| `esbenp.prettier-vscode` | Prettier formatter |
| `ms-kubernetes-tools.vscode-kubernetes-tools` | Kubernetes |
| `ms-azuretools.vscode-docker` | Docker |
| `eamodio.gitlens` | Git blame + history |
| `mhutchie.git-graph` | Git graph |
| `catppuccin.catppuccin-vsc` | Theme |
| `catppuccin.catppuccin-vsc-icons` | File icons |
| `usernamehw.errorlens` | Inline errors |
| `ms-vscode-remote.remote-ssh` | Remote SSH |
| `tamasfe.even-better-toml` | TOML support |
| `redhat.vscode-yaml` | YAML support |

### Window management

- [AeroSpace](https://github.com/nikitabobko/AeroSpace) — tiling window manager

### Containers & Kubernetes

- Docker Desktop
- `kind`, `kubectl`, `kubernetes-cli`, `k9s`
- `kubectx` / `kubens` — fast context and namespace switching
- `pulumi` — cluster bootstrap
- Stakater Reloader — auto-restarts pods when ConfigMaps or Secrets change

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
| --- | --- |
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
| --- | --- |
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

## User guide

### AeroSpace — window management

AeroSpace is a tiling window manager that automatically arranges windows without needing to drag or resize them.

#### Focus & move windows

| Keybind | Action |
| --- | --- |
| `⌥ + H/J/K/L` | Focus window left / down / up / right |
| `⌥ + Shift + H/J/K/L` | Move window left / down / up / right |
| `⌥ + Shift + -` | Shrink window |
| `⌥ + Shift + =` | Grow window |

#### Layouts

| Keybind | Action |
| --- | --- |
| `⌥ + /` | Toggle tiles layout (horizontal / vertical) |
| `⌥ + ,` | Toggle accordion layout |

#### Workspaces

Numbered workspaces `1–9` plus named ones: **B** (browser), **C** (code), **G** (chat/Messages), **M** (music), **S** (mail), **T** (terminal), **W** (work).

| Keybind | Action |
| --- | --- |
| `⌥ + 1–9` | Switch to workspace |
| `⌥ + B/C/G/M/S/T/W` | Switch to named workspace |
| `⌥ + Shift + 1–9` | Move focused window to workspace |
| `⌥ + Shift + B/C/G/M/S/T/W` | Move focused window to named workspace |
| `⌥ + Tab` | Toggle back to previous workspace |
| `⌥ + Shift + Tab` | Move workspace to next monitor |

#### Service mode (`⌥ + Shift + ;`)

Enter service mode for layout maintenance commands:

| Key | Action |
| --- | --- |
| `Esc` | Reload config and exit service mode |
| `R` | Flatten / reset workspace layout |
| `B` | Balance / equalize all window sizes |
| `F` | Toggle window between floating and tiling |

---

### tmux — terminal multiplexer

Prefix key is `Ctrl + A`.

#### Sessions & windows

| Keybind | Action |
| --- | --- |
| `Prefix + \|` | Split pane horizontally |
| `Prefix + -` | Split pane vertically |
| `Prefix + R` | Reload tmux config |

#### Pane resizing

| Keybind | Action |
| --- | --- |
| `Prefix + H/J/K/L` | Resize pane left / down / up / right |
| `Prefix + M` | Zoom (maximize) / unzoom pane |

#### Copy mode (vi-style)

| Keybind | Action |
| --- | --- |
| `Prefix + [` | Enter copy mode |
| `V` | Begin selection |
| `Y` | Copy selection |

#### Plugins (TPM)

Sessions are **automatically saved** every 15 minutes via `tmux-continuum` and **restored on startup** via `tmux-resurrect`. Navigate between tmux panes and Neovim splits seamlessly with `Ctrl + H/J/K/L` via `vim-tmux-navigator`.

---

### Shell (Zsh)

#### Useful aliases

| Alias | Expands to |
| --- | --- |
| `ls` | `eza --icons=always` (icon-enhanced listing) |
| `cd` | `z` (zoxide — smarter directory jumping) |
| `jb` | Jump to `~/Development/github.com/jbetancur` |

#### zoxide — smarter `cd`

| Command | Action |
| --- | --- |
| `z <partial-path>` | Jump to best-matching recent directory |
| `zi` | Interactive fuzzy jump (uses fzf) |

#### fzf — fuzzy finder

| Keybind | Action |
| --- | --- |
| `Ctrl + R` | Fuzzy search shell history |
| `Ctrl + T` | Fuzzy search files and paste path |
| `⌥ + C` | Fuzzy cd into subdirectory |

---

### lazygit — terminal Git UI

Launch with `lazygit` from any Git repo.

| Key | Action |
| --- | --- |
| `Arrow keys / H/J/K/L` | Navigate panels |
| `Space` | Stage / unstage file |
| `C` | Commit |
| `P` | Push |
| `F` | Fetch |
| `B` | Branch menu |
| `?` | Show full keybind help |

---

### Kubernetes cluster bootstrap (Pulumi)

The `pulumi/` directory manages the full local cluster lifecycle — kind, Cilium, ArgoCD, Envoy Gateway, cert-manager, and monitoring. No hardcoded values anywhere; all config is per-user and gitignored.

#### What gets created

| Layer | Tool | How |
| --- | --- | --- |
| kind cluster + local registry | Pulumi | `pulumi up` |
| Cilium CNI + metrics-server | Pulumi | `pulumi up` |
| ArgoCD | Pulumi (Helm) | `pulumi up` |
| Cloudflare secret | Pulumi | `pulumi up` (token encrypted at rest) |
| Envoy Gateway, cert-manager, monitoring | ArgoCD | auto-synced from `k8s/` after bootstrap |
| Wildcard TLS cert, Gateway, HTTPRoutes | Pulumi | `pulumi up` (real domain values injected) |

#### Prerequisites

```sh
brew install pulumi
cd pulumi && npm install
```

#### First-time setup

```sh
cp pulumi/.env.example pulumi/.env
# edit pulumi/.env with your values
./pulumi/setup.sh
```

`.env` is gitignored — your domain, email, and Cloudflare token never touch the repo. `setup.sh` creates your Pulumi stack and encrypts the token at rest in a local `Pulumi.<name>.yaml` (also gitignored).

#### Bootstrap the cluster

```sh
cd pulumi
pulumi up
```

Pulumi previews every resource before applying and asks for confirmation. The full run takes ~5 min. When done, outputs show your URLs and the initial ArgoCD password:

```text
argocdUrl:         https://argocd.dev.example.com
argocdCredentials: admin / <generated-password>
grafanaUrl:        https://grafana.dev.example.com
hubbleUrl:         https://hubble.dev.example.com
```

ArgoCD then syncs monitoring and remaining infra from git — allow another 2-3 min for those to become healthy.

#### Tear down

```sh
pulumi destroy
```

#### Day-to-day

| Task | Command |
| --- | --- |
| Bootstrap cluster | `pulumi up` |
| Tear down cluster | `pulumi destroy` |
| Add/change a k8s app | edit `k8s/` → `git push` (ArgoCD auto-syncs) |
| Change domain / token | edit `pulumi/.env` → `./pulumi/setup.sh` → `pulumi up` |
| See ArgoCD password | `./scripts/argocd-ui.sh` |
| Build + deploy a local image | `./scripts/deploy.sh <image> <dir> <ns> <deployment>` |

---

### Kubernetes quick reference

#### kubectx / kubens

| Command | Action |
| --- | --- |
| `kubectx` | List / switch cluster context |
| `kubens` | List / switch namespace |

#### k9s — terminal Kubernetes UI

Launch with `k9s`. Navigate with arrow keys; press `?` for a full keybind reference. Type `:pods`, `:deployments`, etc. to jump directly to a resource view.

---

### delta — better git diffs

delta activates automatically — no extra commands. Every `git diff`, `git log`, `git show`, and lazygit diff view gets syntax highlighting and side-by-side mode.

| Command | What you see |
| --- | --- |
| `git diff` | Side-by-side syntax-highlighted diff |
| `git log -p` | Full patch log with highlighting |
| `git show <sha>` | Highlighted commit diff |
| `n` / `N` | Jump to next / previous change (navigate mode) |

To toggle side-by-side off temporarily:

```sh
git diff --no-pager | delta --side-by-side=false
```

---

### atuin — shell history

atuin replaces `Ctrl + R` with a full-screen fuzzy history search. History is stored in a local SQLite database and shared across all terminals automatically.

| Keybind / Command | Action |
| --- | --- |
| `Ctrl + R` | Open full-screen history search |
| Type to filter | Fuzzy search across all history |
| `Enter` | Run selected command |
| `Tab` | Paste selected command without running |
| `Ctrl + D` / `Esc` | Close without selecting |
| `atuin stats` | Show most-used commands |
| `atuin search <term>` | Search history from the CLI |

> **Note:** In the VS Code integrated terminal `Ctrl + R` may be intercepted by VS Code. Use WezTerm for the full experience — history is shared across all terminals.

---

## Commented-out items

A few installs are commented out in `scripts/install.sh` and can be enabled as needed:

- **Sketchybar** — custom macOS menu bar
- **Discord**, **Tidal**, **Logitech G Hub**
