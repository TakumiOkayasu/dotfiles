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

# eza/exa > GNU ls > BSD ls の優先順位で設定
if command -v eza >/dev/null 2>&1; then
    alias ls='eza'
    alias ll='eza -alF --git'
    alias la='eza -a'
    alias l='eza -F'
    alias lt='eza --tree --level=2'
    alias lla='eza -la --git'
elif command -v exa >/dev/null 2>&1; then
    alias ls='exa'
    alias ll='exa -alF --git'
    alias la='exa -a'
    alias l='exa -F'
    alias lt='exa --tree --level=2'
    alias lla='exa -la --git'
elif ls --color=auto / >/dev/null 2>&1; then
    # GNU ls
    alias ls='ls --color=auto'
    alias ll='ls -alF --color=auto'
    alias la='ls -A --color=auto'
    alias l='ls -CF --color=auto'
    alias lla='ls -la --color=auto'
elif ls -G / >/dev/null 2>&1; then
    # BSD ls (macOS)
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
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

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

alias d='docker'
alias dc='docker compose'
alias dps='docker ps'
alias dpsa='docker ps -a'
alias di='docker images'
alias dex='docker exec -it'
alias dlog='docker logs -f'

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
# ローカル/カスタムエイリアス
# ============================================================================

# shell/aliases.local (dotfiles管理)
if [ -f "$DOTFILES_DIR/shell/aliases.local" ]; then
    . "$DOTFILES_DIR/shell/aliases.local"
fi

# ~/.aliases.local (Git管理外、マシン固有)
if [ -f "$HOME/.aliases.local" ]; then
    . "$HOME/.aliases.local"
fi
