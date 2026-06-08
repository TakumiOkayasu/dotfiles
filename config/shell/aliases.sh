#!/bin/sh
# shell/aliases.sh - 共通エイリアス (POSIX互換)
#
# 読み込み元: common.sh
# 注意: シェル固有のエイリアスは各シェルの設定ファイルに記述

# ============================================================================
# ディレクトリ操作
# ============================================================================

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

alias md='mkdir -p'
alias rd='rmdir'

# ============================================================================
# ls (環境に応じて色付け)
# ============================================================================

# eza > GNU ls > BSD ls の優先順位で設定
if command -v eza >/dev/null 2>&1; then
    alias ls='eza --group-directories-first --sort=name'
    alias ll='eza -alF --git --group-directories-first --sort=name'
    alias la='eza -a --group-directories-first --sort=name'
    alias l='eza -F --group-directories-first --sort=name'
    alias lt='eza --tree --level=2 --group-directories-first --sort=name'
    alias lla='eza -la --git --group-directories-first --sort=name'
elif command -v gls >/dev/null 2>&1; then
    # GNU ls via Homebrew (macOS with coreutils)
    alias ls='gls --color=auto --group-directories-first'
    alias ll='gls -alF --color=auto --group-directories-first'
    alias la='gls -A --color=auto --group-directories-first'
    alias l='gls -CF --color=auto --group-directories-first'
    alias lla='gls -alh --color=auto --group-directories-first --time-style=long-iso'
elif ls --color=auto / >/dev/null 2>&1; then
    # GNU ls (Linux/WSL)
    alias ls='ls --color=auto --group-directories-first'
    alias ll='ls -alF --color=auto --group-directories-first'
    alias la='ls -A --color=auto --group-directories-first'
    alias l='ls -CF --color=auto --group-directories-first'
    alias lla='ls -alXv --human-readable --time-style=long-iso --group-directories-first --color=auto'
elif ls -G / >/dev/null 2>&1; then
    # BSD ls (macOS) - --group-directories-first 非対応
    alias ls='ls -G'
    alias ll='ls -alFG'
    alias la='ls -AG'
    alias l='ls -CFG'
    alias lla='ls -laG'
else
    alias ll='ls -alF'
    alias la='ls -A'
    alias l='ls -CF'
    alias lla='ls -la'
fi

# ============================================================================
# grep (カラー)
# ============================================================================

alias grep='grep --color=auto'
alias fgrep='grep -F --color=auto'
alias egrep='grep -E --color=auto'

# ============================================================================
# 安全なファイル操作
# ============================================================================

alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'

# ============================================================================
# Git
# ============================================================================

alias g='git'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
alias gco='git checkout'
alias gb='git branch'
alias glog='git log --oneline --graph --decorate'

# ============================================================================
# Docker
# ============================================================================

_dotfiles_container_cli='docker'
alias d="$_dotfiles_container_cli"
alias dc="$_dotfiles_container_cli compose"
alias dp="$_dotfiles_container_cli ps"
alias dpa="$_dotfiles_container_cli ps -a"
alias dps="$_dotfiles_container_cli ps"
alias dpsa="$_dotfiles_container_cli ps -a"
alias di="$_dotfiles_container_cli images"
alias dls="$_dotfiles_container_cli logs"
alias dex="$_dotfiles_container_cli exec -it"
alias dlog="$_dotfiles_container_cli logs -f"
unset _dotfiles_container_cli

# ============================================================================
# Kubernetes
# ============================================================================

if command -v kubectl >/dev/null 2>&1; then
    alias k='kubectl'
    alias kgp='kubectl get pods'
    alias kgs='kubectl get services'
    alias kgd='kubectl get deployments'
    alias klog='kubectl logs -f'
    alias kex='kubectl exec -it'
fi

# ============================================================================
# 便利コマンド
# ============================================================================

# 現在のパスをコピー
alias pwdc='pwd | tr -d "\n"'

# 履歴検索
alias h='history'
alias hg='history | grep'

# ディスク使用量
alias df='df -h'
alias du='du -h'
alias dus='du -sh'

# プロセス
alias psg='ps aux | grep'
alias pshttpd='ps aux | grep httpd'

# ネットワーク
alias ports='netstat -tulanp 2>/dev/null || ss -tulanp'

# 日時
alias now='date +"%Y-%m-%d %H:%M:%S"'
alias today='date +"%Y-%m-%d"'

# ============================================================================
# 開発関連
# ============================================================================

# Python
alias py='python3'
alias pip='pip3'
alias venv='python3 -m venv'
alias activate='source ./venv/bin/activate 2>/dev/null || source ./.venv/bin/activate'

# Node.js
alias ni='npm install'
alias nr='npm run'
alias ns='npm start'
alias nt='npm test'

# ============================================================================
# エディタ
# ============================================================================

alias v='vim'
alias vi='vim'

if command -v code >/dev/null 2>&1; then
    alias c='code'
    alias c.='code .'
fi

# ============================================================================
# Claude Code
# ============================================================================

if command -v claude >/dev/null 2>&1; then
    alias cc='claude'
    alias ccr='claude --resume'
    alias ccc='claude --continue'
fi

# ============================================================================
# その他
# ============================================================================

# 天気 (wttr.in)
alias weather='curl -s "wttr.in?format=3"'

# グローバルIP
alias myip='curl -s ifconfig.me'

# ローカルIP
alias localip="ip route get 1 2>/dev/null | awk '{print \$7}' || ipconfig getifaddr en0 2>/dev/null"

# ============================================================================
# ローカルエイリアス
# ============================================================================

if [ -n "$DOTFILES_DIR" ] && [ -f "$DOTFILES_DIR/config/shell/aliases.local" ]; then
    . "$DOTFILES_DIR/config/shell/aliases.local"
fi

if [ -f "$HOME/.aliases.local" ]; then
    . "$HOME/.aliases.local"
fi
