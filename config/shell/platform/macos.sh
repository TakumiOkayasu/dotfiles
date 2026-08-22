#!/bin/sh
# shell/platform/macos.sh - macOS固有設定 (POSIX互換)
#
# 読み込み元: common.sh (プラットフォーム検出後)

# ============================================================================
# Git SSH (環境別に明示指定)
# ============================================================================

export GIT_SSH_COMMAND="/usr/bin/ssh"

# ============================================================================
# Homebrew
# ============================================================================

# Apple Silicon
if [ -d "/opt/homebrew" ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
# Intel Mac
elif [ -d "/usr/local/Homebrew" ]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi

# Homebrew の補完 (bash/zsh で使用)
if command -v brew >/dev/null 2>&1; then
    HOMEBREW_PREFIX="$(brew --prefix)"
    export HOMEBREW_PREFIX
fi

# ============================================================================
# PATH追加
# ============================================================================

# GNU coreutils (Homebrew)
if [ -d "$HOMEBREW_PREFIX/opt/coreutils/libexec/gnubin" ]; then
    _dotfiles_add_path "$HOMEBREW_PREFIX/opt/coreutils/libexec/gnubin"
fi

# GNU grep
if [ -d "$HOMEBREW_PREFIX/opt/grep/libexec/gnubin" ]; then
    _dotfiles_add_path "$HOMEBREW_PREFIX/opt/grep/libexec/gnubin"
fi

# GNU sed
if [ -d "$HOMEBREW_PREFIX/opt/gnu-sed/libexec/gnubin" ]; then
    _dotfiles_add_path "$HOMEBREW_PREFIX/opt/gnu-sed/libexec/gnubin"
fi

# ============================================================================
# エイリアス
# ============================================================================

# Finder で開く
alias o='open'
alias o.='open .'
alias oo='open -a'

# アプリケーション
alias chrome='open -a "Google Chrome"'
alias safari='open -a Safari'
alias finder='open -a Finder'

# クリップボード (macOS標準)
# pbcopy, pbpaste は標準で使える

# Dock 再起動
alias dock-restart='killall Dock'

# DNS キャッシュクリア
alias flush-dns='sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder'

# ============================================================================
# macOS固有の環境変数
# ============================================================================

# Homebrew で入れた OpenSSL
if [ -d "$HOMEBREW_PREFIX/opt/openssl@3" ]; then
    export LDFLAGS="-L$HOMEBREW_PREFIX/opt/openssl@3/lib"
    export CPPFLAGS="-I$HOMEBREW_PREFIX/opt/openssl@3/include"
    export PKG_CONFIG_PATH="$HOMEBREW_PREFIX/opt/openssl@3/lib/pkgconfig"
fi
