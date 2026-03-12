# config/shell/fish/config.fish - fish固有設定
#
# 配置先: ~/.config/fish/config.fish (シンボリックリンク)
# 読み込み: fish起動時

# ============================================================================
# DOTFILES_DIR 検出
# ============================================================================

set -l this_file (status filename)
set -l config_dir (dirname (dirname (dirname (realpath $this_file))))
set -gx DOTFILES_DIR (dirname $config_dir)

# ============================================================================
# SSH Agent 自動起動
# ============================================================================

if test -f $DOTFILES_DIR/config/shell/fish/ssh-agent.fish
    source $DOTFILES_DIR/config/shell/fish/ssh-agent.fish
end

# ============================================================================
# 共通設定の読み込み (bass 経由)
# ============================================================================

# bass がインストールされていれば POSIX スクリプトを読み込める
# ~/.shell_common があれば優先 (install.sh --shell-common でインストール)
if type -q bass
    if test -f "$HOME/.shell_common"
        bass source "$HOME/.shell_common"
    else
        bass source "$DOTFILES_DIR/config/shell/common.sh"
    end
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

if test -f $DOTFILES_DIR/config/shell/fish/aliases.fish
    source $DOTFILES_DIR/config/shell/fish/aliases.fish
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

# ============================================================================
# Homebrew (Linux/WSL環境のみ)
# ============================================================================
# Linuxbrew がインストールされていれば環境変数を設定

if test -x "/home/linuxbrew/.linuxbrew/bin/brew"
    eval (/home/linuxbrew/.linuxbrew/bin/brew shellenv)
end

# ============================================================================
# モダンツール (fzf, zoxide)
# ============================================================================

# fzf: Ctrl+R 履歴検索, Ctrl+T ファイル検索
if type -q fzf
    fzf --fish 2>/dev/null | source
end

# zoxide: スマート cd (z コマンド)
if type -q zoxide
    zoxide init fish | source
end
