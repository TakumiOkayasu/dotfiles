#!/bin/sh
# shell/local/wsl.sh - WSL固有設定 (POSIX互換)
#
# 読み込み元: common.sh (プラットフォーム検出後)

# ============================================================================
# Windows連携
# ============================================================================

# Windowsホームディレクトリ
if [ -d "/mnt/c/Users" ]; then
    WIN_USER="${WIN_USER:-$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r')}"
    WIN_HOME="/mnt/c/Users/$WIN_USER"
    export WIN_USER WIN_HOME
fi

# ============================================================================
# PATH追加 (Windows側のツール)
# ============================================================================

# Visual Studio Code (Windows版)
_dotfiles_add_path "/mnt/c/Users/$WIN_USER/AppData/Local/Programs/Microsoft VS Code/bin" append

# ============================================================================
# エイリアス
# ============================================================================

# Windows側でエクスプローラーを開く
alias open='explorer.exe'
alias e.='explorer.exe .'

# クリップボード
alias pbcopy='clip.exe'
alias pbpaste='powershell.exe -command "Get-Clipboard"'

# Windows側のコマンド
alias cmd='cmd.exe /c'
alias psh='powershell.exe -Command'

# ============================================================================
# WSL固有の設定
# ============================================================================

# umask (Windows側との権限の整合性)
umask 022

# ============================================================================
# Docker Desktop WSL統合
# ============================================================================

# Docker Desktop が WSL 統合を使用している場合のパス
if [ -d "/mnt/wsl/docker-desktop/cli-tools/usr/bin" ]; then
    _dotfiles_add_path "/mnt/wsl/docker-desktop/cli-tools/usr/bin" append
fi

# ============================================================================
# X Server (GUI アプリ用)
# ============================================================================

# WSLg が有効でない場合の VcXsrv/X410 設定
if [ -z "$DISPLAY" ] && [ -z "$WAYLAND_DISPLAY" ]; then
    # WSL2 の場合は Windows ホストの IP を使用
    if grep -qi "microsoft.*WSL2" /proc/version 2>/dev/null; then
        export DISPLAY="$(cat /etc/resolv.conf | grep nameserver | awk '{print $2}'):0"
    else
        # WSL1
        export DISPLAY=":0"
    fi
fi

# ============================================================================
# GPG/SSH エージェント (Windows側と共有する場合)
# ============================================================================

# Windows側の gpg-agent を使用する場合 (npiperelay 経由)
# 必要に応じてコメント解除
# if command -v npiperelay.exe >/dev/null 2>&1; then
#     export GPG_AGENT_SOCK="$HOME/.gnupg/S.gpg-agent"
# fi
