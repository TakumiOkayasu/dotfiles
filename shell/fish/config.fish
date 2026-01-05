# shell/fish/config.fish - fish固有設定
#
# 配置先: ~/.config/fish/config.fish (シンボリックリンク)
# 読み込み: fish起動時

# ============================================================================
# DOTFILES_DIR 検出
# ============================================================================

# このファイルの場所から dotfiles ルートを検出
set -l this_file (status filename)
set -l shell_dir (dirname (dirname (realpath $this_file)))
set -gx DOTFILES_DIR (dirname $shell_dir)

# ============================================================================
# 共通設定の読み込み (bass 経由)
# ============================================================================

# bass がインストールされていれば POSIX スクリプトを読み込める
if type -q bass
    bass source "$DOTFILES_DIR/shell/common.sh"
else
    # bass がない場合は手動で PATH などを設定
    
    # プラットフォーム検出
    if test -f /proc/sys/fs/binfmt_misc/WSLInterop; or set -q WSL_DISTRO_NAME
        set -gx DOTFILES_PLATFORM "wsl"
    else if test (uname -s) = "Darwin"
        set -gx DOTFILES_PLATFORM "macos"
    else
        set -gx DOTFILES_PLATFORM "linux"
    end
    
    # PATH 設定
    fish_add_path --path "$DOTFILES_DIR/bin"
    fish_add_path --path "$HOME/.local/bin"
    fish_add_path --path "$HOME/bin"
    fish_add_path --path "$HOME/.cargo/bin"
    fish_add_path --path "$HOME/go/bin"
    
    # 環境変数
    set -gx EDITOR "code --wait"
    set -gx LANG "ja_JP.UTF-8"
    set -gx PAGER "less"
    set -gx LESS "-R -F -X"
end

# ============================================================================
# プラットフォーム固有設定
# ============================================================================

switch $DOTFILES_PLATFORM
    case "wsl"
        # Windows ホームディレクトリ
        set -l win_user (cmd.exe /c "echo %USERNAME%" 2>/dev/null | string trim)
        set -gx WIN_HOME "/mnt/c/Users/$win_user"
        
        # エイリアス
        alias open='explorer.exe'
        alias pbcopy='clip.exe'
        alias pbpaste='powershell.exe -command "Get-Clipboard"'
        
    case "macos"
        # Homebrew
        if test -d /opt/homebrew
            eval (/opt/homebrew/bin/brew shellenv)
        else if test -d /usr/local/Homebrew
            eval (/usr/local/bin/brew shellenv)
        end
        
        alias o='open'
        alias o.='open .'
        
    case "linux"
        # xdg-open
        if type -q xdg-open
            alias open='xdg-open'
        end
        
        # クリップボード
        if type -q xclip
            alias pbcopy='xclip -selection clipboard'
            alias pbpaste='xclip -selection clipboard -o'
        else if type -q xsel
            alias pbcopy='xsel --clipboard --input'
            alias pbpaste='xsel --clipboard --output'
        end
end

# ============================================================================
# エイリアス
# ============================================================================

# ディレクトリ操作
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias md='mkdir -p'

# ls (eza/exa 優先)
if type -q eza
    alias ls='eza'
    alias ll='eza -alF --git'
    alias la='eza -a'
    alias lt='eza --tree --level=2'
else if type -q exa
    alias ls='exa'
    alias ll='exa -alF --git'
    alias la='exa -a'
    alias lt='exa --tree --level=2'
else
    alias ll='ls -alF'
    alias la='ls -A'
end

# Git
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

# Docker
alias d='docker'
alias dc='docker compose'
alias dps='docker ps'
alias dpsa='docker ps -a'

# その他
alias v='vim'
alias c='code'
alias c.='code .'

# Claude Code
if type -q claude
    alias cc='claude'
    alias ccr='claude --resume'
    alias ccc='claude --continue'
end

# ============================================================================
# プロンプト
# ============================================================================

# oh-my-posh
if type -q oh-my-posh
    set -l theme_name "sim-web.omp.json"
    set -l config ""
    
    for dir in "$HOME/.poshthemes" "$DOTFILES_DIR/poshthemes"
        if test -f "$dir/$theme_name"
            set config "$dir/$theme_name"
            break
        end
    end
    
    if test -n "$config"
        oh-my-posh init fish --config "$config" | source
    end
end

# ============================================================================
# 便利関数
# ============================================================================

# ディレクトリ作成して移動
function mkcd
    mkdir -p $argv[1]; and cd $argv[1]
end

# ============================================================================
# ローカル設定 (Git管理外)
# ============================================================================

if test -f "$HOME/.config/fish/local.fish"
    source "$HOME/.config/fish/local.fish"
end
