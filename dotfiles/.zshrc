if [[ "$TERM_PROGRAM" != "vscode" ]]; then
  if command -v fastfetch &>/dev/null; then
    fastfetch
  fi
fi

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
source /opt/homebrew/share/powerlevel10k/powerlevel10k.zsh-theme

[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# history setup
HISTFILE=$HOME/.zhistory
SAVEHIST=1000
HISTSIZE=1000
setopt share_history
setopt hist_expire_dups_first
setopt hist_ignore_dups
setopt hist_verify

# completion using arrow keys (based on history)
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward

bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line


source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

alias ls="eza --icons=always"

# ---- Go ----
export GOPATH="$HOME/go"
export PATH="$PATH:$GOPATH/bin"

# ---- nvm (Node Version Manager) ----
export NVM_DIR="$HOME/.nvm"
[[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
[[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"

# ---- pyenv (Python Version Manager) ----
export PYENV_ROOT="$HOME/.pyenv"
[[ -d "$PYENV_ROOT/bin" ]] && export PATH="$PYENV_ROOT/bin:$PATH"
command -v pyenv &>/dev/null && eval "$(pyenv init -)"

# ---- Atuin (shell history) ----
command -v atuin &>/dev/null && eval "$(atuin init zsh)"

# Shell completions (must run before tools that use compdef, e.g. zoxide)
autoload -Uz compinit && compinit
command -v kubectl &>/dev/null && source <(kubectl completion zsh)
command -v gh     &>/dev/null && source <(gh completion -s zsh)
source <(fzf --zsh)

# ---- Zoxide (better cd) ----
eval "$(zoxide init zsh)"

alias cd="z"
alias jb="z ${HOME}/Development/github.com/jbetancur"
