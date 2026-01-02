# ==============================================================================
# 基本設定
# ==============================================================================

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# Shell options
shopt -s histappend    # append to the history file, don't overwrite it
shopt -s checkwinsize  # check the window size after each command
#shopt -s globstar     # pattern "**" matches all files and zero or more directories

# History settings
HISTCONTROL=ignoreboth
HISTSIZE=1000
HISTFILESIZE=2000

# ==============================================================================
# プロンプト設定
# ==============================================================================

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability
#force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
        color_prompt=yes
    else
        color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# ==============================================================================
# カラー設定・エイリアス
# ==============================================================================

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'
    #alias grep='grep --color=auto'
    #alias fgrep='fgrep --color=auto'
    #alias egrep='egrep --color=auto'
fi

if [ -f ~/.shell_aliases ]; then
    source ~/.shell_aliases
fi

# ==============================================================================
# Bash補完
# ==============================================================================

# enable programmable completion features
if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    fi
fi

# ==============================================================================
# Git設定
# ==============================================================================

_setup_git_prompt() {
    local git_completion="$HOME/.git-completion.bash"
    local git_prompt="$HOME/.git-prompt.sh"
    
    [ -f "$git_completion" ] && source "$git_completion"
    [ -f "$git_prompt" ] && source "$git_prompt"
    
    if [ -f "$git_prompt" ]; then
        GIT_PS1_SHOWDIRTYSTATE=true
        GIT_PS1_SHOWUNTRACKEDFILES=true
        GIT_PS1_SHOWUPSTREAM=auto
        unset PROMPT_COMMAND
    fi
}

_setup_git_prompt
unset -f _setup_git_prompt

# ==============================================================================
# oh-my-posh設定
# ==============================================================================

_setup_oh_my_posh() {
    local theme="sim-web.omp.json"
    local config="$HOME/.poshthemes/$theme"
    local cache_dir="$HOME/.cache/oh-my-posh"
    
    # キャッシュディレクトリの確保
    mkdir -p "$cache_dir"
    
    # 初期化試行(エラー時は自動修復)
    if ! eval "$(oh-my-posh init bash --config "$config")" 2>/dev/null; then
        rm -rf "$cache_dir"
        mkdir -p "$cache_dir"
        eval "$(oh-my-posh init bash --config "$config")"
    fi
}

_setup_oh_my_posh
unset -f _setup_oh_my_posh

# ==============================================================================
# SSH鍵管理(Keychain)
# ==============================================================================

_setup_keychain() {
    if command -v keychain >/dev/null 2>&1; then
        eval "$(keychain --eval --agents ssh --quiet id_ed25519_gitlab_work id_ed25519_github_private)"
    fi
}

_setup_keychain
unset -f _setup_keychain

# ==============================================================================
# 開発環境設定
# ==============================================================================

# User local bin
if [ -d "$HOME/.local/bin" ]; then
    export PATH="$HOME/.local/bin:$PATH"
fi

# Homebrew
if [ -f /home/linuxbrew/.linuxbrew/bin/brew ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# Nodebrew
if [ -d "$HOME/.nodebrew/current/bin" ]; then
    export PATH="$HOME/.nodebrew/current/bin:$PATH"
fi

# NVM (Node Version Manager)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# GitHub Token
export GITHUB_TOKEN=$(pass github/token)

# Rust
. "$HOME/.cargo/env"

# Zig
export PATH="/opt/zig:$PATH"

# dotfiles bin (このファイルからの相対位置で検出)
_setup_dotfiles_bin() {
    local bashrc_path="${BASH_SOURCE[0]}"
    # シンボリックリンクを解決
    while [[ -L "$bashrc_path" ]]; do
        bashrc_path="$(readlink "$bashrc_path")"
    done
    local dotfiles_dir="$(cd "$(dirname "$bashrc_path")" && pwd)"
    local bin_dir="$dotfiles_dir/bin"
    if [[ -d "$bin_dir" ]]; then
        export DOTFILES_BIN="$bin_dir"
        export PATH="$DOTFILES_BIN:$PATH"
    fi
}
_setup_dotfiles_bin
unset -f _setup_dotfiles_bin
