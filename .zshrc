# ~/.zshrc: executed by zsh for interactive shells.

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# History settings
HISTFILE=~/.zsh_history
HISTSIZE=1000
SAVEHIST=2000
setopt HIST_IGNORE_DUPS      # ignore duplicate commands
setopt HIST_IGNORE_SPACE     # ignore commands starting with space
setopt APPEND_HISTORY        # append to history file
setopt SHARE_HISTORY         # share history between sessions
setopt EXTENDED_HISTORY      # save timestamp

# Shell options
setopt AUTO_CD               # cd without typing cd
setopt CORRECT               # command correction
setopt NO_BEEP               # no beep

# enable color support
autoload -Uz colors && colors

# Completion
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# Load aliases
if [[ -f ~/.zsh_aliases ]]; then
    source ~/.zsh_aliases
fi

# Git prompt (if using git-prompt.sh)
if [[ -f ~/.git-prompt.sh ]]; then
    source ~/.git-prompt.sh
    GIT_PS1_SHOWDIRTYSTATE=true
    GIT_PS1_SHOWUNTRACKEDFILES=true
    GIT_PS1_SHOWUPSTREAM=auto
    setopt PROMPT_SUBST
    PROMPT='%F{green}%n@%m%f:%F{blue}%~%f$(__git_ps1 " (%s)")%# '
fi

# oh-my-posh (if installed)
if command -v oh-my-posh >/dev/null 2>&1; then
    eval "$(oh-my-posh init zsh --config ~/.poshthemes/sim-web.omp.json)"
fi

# Keychain (SSH agent)
if command -v keychain >/dev/null 2>&1; then
    eval "$(keychain --eval --agents ssh --quiet id_ed25519_gitlab_work id_ed25519_github_private)"
fi

# Homebrew
if [[ -f /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
elif [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# nodebrew
if [[ -d $HOME/.nodebrew ]]; then
    export PATH=$HOME/.nodebrew/current/bin:$PATH
fi

# nvm
export NVM_DIR="$HOME/.nvm"
[[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
[[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"
