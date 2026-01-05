# ~/.profile - 共通シェル設定
# prezto/oh-my-posh等から source して使用
#
# 使い方:
#   zsh:  ~/.zprofile または ~/.zshrc に追加
#         [[ -f ~/.profile ]] && source ~/.profile
#   bash: ~/.bash_profile または ~/.bashrc に追加
#         [[ -f ~/.profile ]] && source ~/.profile

# ============================================================================
# PATH設定
# ============================================================================

# dotfiles/bin
if [[ -d "$HOME/prog/dotfile-work/bin" ]]; then
    export PATH="$HOME/prog/dotfile-work/bin:$PATH"
fi

# Homebrew (macOS)
if [[ -d "/opt/homebrew/bin" ]]; then
    export PATH="/opt/homebrew/bin:$PATH"
fi

# Linuxbrew
if [[ -d "/home/linuxbrew/.linuxbrew/bin" ]]; then
    export PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"
fi

# ============================================================================
# 環境変数
# ============================================================================

export EDITOR="code --wait"
export LANG="ja_JP.UTF-8"
export LC_ALL="ja_JP.UTF-8"

# ============================================================================
# エイリアス読み込み
# ============================================================================

if [[ -f "$HOME/.shell_aliases" ]]; then
    source "$HOME/.shell_aliases"
fi

# ============================================================================
# .bashrc 読み込み (bash の場合)
# ============================================================================

if [ -n "$BASH_VERSION" ]; then
    if [ -f "$HOME/.bashrc" ]; then
        . "$HOME/.bashrc"
    fi
fi

