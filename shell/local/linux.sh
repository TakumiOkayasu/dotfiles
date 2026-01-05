#!/bin/sh
# shell/local/linux.sh - Linux固有設定 (POSIX互換)
#
# 読み込み元: common.sh (プラットフォーム検出後)
# 対象: サーバー、デスクトップLinux (WSL以外)

# ============================================================================
# Linuxbrew (Homebrew on Linux)
# ============================================================================

if [ -d "/home/linuxbrew/.linuxbrew" ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# ============================================================================
# PATH追加
# ============================================================================

# snap
if [ -d "/snap/bin" ]; then
    _dotfiles_add_path "/snap/bin" append
fi

# ============================================================================
# エイリアス
# ============================================================================

# クリップボード (xclip または xsel)
if command -v xclip >/dev/null 2>&1; then
    alias pbcopy='xclip -selection clipboard'
    alias pbpaste='xclip -selection clipboard -o'
elif command -v xsel >/dev/null 2>&1; then
    alias pbcopy='xsel --clipboard --input'
    alias pbpaste='xsel --clipboard --output'
fi

# ファイルマネージャで開く
if command -v xdg-open >/dev/null 2>&1; then
    alias open='xdg-open'
    alias o='xdg-open'
    alias o.='xdg-open .'
fi

# パッケージマネージャ (検出)
if command -v apt >/dev/null 2>&1; then
    alias apt-update='sudo apt update && sudo apt upgrade'
    alias apt-clean='sudo apt autoremove && sudo apt autoclean'
elif command -v dnf >/dev/null 2>&1; then
    alias dnf-update='sudo dnf upgrade'
elif command -v pacman >/dev/null 2>&1; then
    alias pac-update='sudo pacman -Syu'
fi

# systemd
if command -v systemctl >/dev/null 2>&1; then
    alias sc='systemctl'
    alias scs='systemctl status'
    alias scr='sudo systemctl restart'
    alias sce='sudo systemctl enable'
    alias scd='sudo systemctl disable'
    alias jc='journalctl'
    alias jcf='journalctl -f'
fi

# ============================================================================
# SSH エージェント
# ============================================================================

# keychain があれば使用
if command -v keychain >/dev/null 2>&1; then
    eval "$(keychain --eval --quiet id_ed25519 id_rsa 2>/dev/null)"
elif [ -z "$SSH_AUTH_SOCK" ]; then
    # ssh-agent を起動
    eval "$(ssh-agent -s)" >/dev/null 2>&1
fi
