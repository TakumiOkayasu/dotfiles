# config/shell/fish/aliases.fish - fish エイリアス
#
# 読み込み元: config.fish
# aliases.sh と同等の内容を fish 構文で記述

# ============================================================================
# ディレクトリ操作
# ============================================================================

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

alias md='mkdir -p'
alias rd='rmdir'

# ============================================================================
# ls (eza 優先)
# ============================================================================

if type -q eza
    alias ls='eza --group-directories-first --sort=name'
    alias ll='eza -alF --git --group-directories-first --sort=name'
    alias la='eza -a --group-directories-first --sort=name'
    alias l='eza -F --group-directories-first --sort=name'
    alias lt='eza --tree --level=2 --group-directories-first --sort=name'
    alias lla='eza -la --git --group-directories-first --sort=name'
else
    alias ll='ls -alF'
    alias la='ls -A'
    alias l='ls -CF'
    alias lla='ls -la'
end

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

alias d='docker'
alias dc='docker compose'
alias dp='docker ps'
alias dpa='docker ps -a'
alias dps='docker ps'
alias dpsa='docker ps -a'
alias di='docker images'
alias dls='docker logs'
alias dex='docker exec -it'
alias dlog='docker logs -f'

# ============================================================================
# Kubernetes
# ============================================================================

if type -q kubectl
    alias k='kubectl'
    alias kgp='kubectl get pods'
    alias kgs='kubectl get services'
    alias kgd='kubectl get deployments'
    alias klog='kubectl logs -f'
    alias kex='kubectl exec -it'
end

# ============================================================================
# 便利コマンド
# ============================================================================

alias pwdc='pwd | tr -d "\n"'
alias h='history'
alias hg='history | grep'
alias df='df -h'
alias du='du -h'
alias dus='du -sh'
alias psg='ps aux | grep'
alias pshttpd='ps aux | grep httpd'
alias ports='ss -tulanp'
alias now='date +"%Y-%m-%d %H:%M:%S"'
alias today='date +"%Y-%m-%d"'
# localip: aliases.sh の実装が POSIX 構文に依存するため fish 版では省略

# ============================================================================
# 開発関連
# ============================================================================

alias py='python3'
alias pip='pip3'
alias venv='python3 -m venv'

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

if type -q code
    alias c='code'
    alias c.='code .'
end

# ============================================================================
# Claude Code
# ============================================================================

if type -q claude
    alias cc='claude'
    alias ccr='claude --resume'
    alias ccc='claude --continue'
end

# ============================================================================
# その他
# ============================================================================

alias weather='curl -s "wttr.in?format=3"'
alias myip='curl -s ifconfig.me'
