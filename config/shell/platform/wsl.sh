#!/bin/sh
# shell/platform/wsl.sh - WSL固有設定 (POSIX互換)
#
# 読み込み元: common.sh (プラットフォーム検出後)

# ============================================================================
# Windows連携
# ============================================================================

# Claude CodeがWindowsプロファイル検出でpowershell.exeを繰り返し起動するのを防ぐ
# ref: https://github.com/anthropics/claude-code/issues/14352
export CLAUDE_CODE_SKIP_WINDOWS_PROFILE=1

# Windowsホームディレクトリ (common.sh の _dotfiles_detect_win_home を使用)
WIN_HOME="${WIN_HOME:-$(_dotfiles_detect_win_home)}"
if [ -n "$WIN_HOME" ]; then
    WIN_USER="${WIN_USER:-$(basename "$WIN_HOME")}"
    export WIN_USER WIN_HOME
    # USERPROFILE: WSLでは未設定のため補完
    export USERPROFILE="${USERPROFILE:-$WIN_HOME}"
fi

# ============================================================================
# PATH追加 (Windows側のツール)
# ============================================================================

# Visual Studio Code (Windows版)
if [ -n "${WIN_HOME:-}" ]; then
    _dotfiles_add_path "$WIN_HOME/AppData/Local/Programs/Microsoft VS Code/bin" append
fi

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

# USE_VCXSRV=1 で VcXsrv を優先 (WSLg を迂回)
# ~/.local.sh 等で export USE_VCXSRV=1 を設定
if [ "${USE_VCXSRV:-0}" = "1" ]; then
    _wsl_host_ip="$(ip route show default 2>/dev/null | awk '{print $3}')"
    export DISPLAY="${_wsl_host_ip}:0"
    unset _wsl_host_ip
elif [ -z "$DISPLAY" ] && [ -z "$WAYLAND_DISPLAY" ]; then
    # WSLg が無効な場合のフォールバック
    if grep -qi "microsoft.*WSL2" /proc/version 2>/dev/null; then
        _wsl_ns_ip="$(grep nameserver /etc/resolv.conf | awk '{print $2}')"
        export DISPLAY="${_wsl_ns_ip}:0"
        unset _wsl_ns_ip
    else
        # WSL1
        export DISPLAY=":0"
    fi
fi

# ============================================================================
# カーソルサイズ (WSLg/GTKの二重スケーリング防止)
# ============================================================================

export XCURSOR_SIZE=24
export XCURSOR_THEME=Adwaita
export GDK_SCALE=1
export GDK_DPI_SCALE=1
# GTK4: dconf/gsettings でカーソルサイズを指定
if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface cursor-size 24 2>/dev/null
    gsettings set org.gnome.desktop.interface cursor-theme Adwaita 2>/dev/null
fi
# X11: Xリソースでカーソルサイズを指定 (GTK4設定ファイルと併用)
if command -v xrdb >/dev/null 2>&1 && [ -n "$DISPLAY" ]; then
    echo "Xcursor.size: 24" | xrdb -merge 2>/dev/null
fi

# ============================================================================
# 日本語入力 (fcitx5)
# ============================================================================

if command -v fcitx5 >/dev/null 2>&1; then
    export GTK_IM_MODULE=fcitx
    export QT_IM_MODULE=fcitx
    export XMODIFIERS=@im=fcitx
    export INPUT_METHOD=fcitx
    # fcitx5 がまだ起動していなければバックグラウンドで起動
    if ! pgrep -x fcitx5 >/dev/null 2>&1; then
        fcitx5 --disable=wayland -d -r >/dev/null 2>&1
    fi
fi

# ============================================================================
# Git SSH (環境別に明示指定)
# ============================================================================

export GIT_SSH_COMMAND="/usr/bin/ssh"

# ============================================================================
# GPG/SSH エージェント (Windows側と共有する場合)
# ============================================================================

# Windows側の gpg-agent を使用する場合 (npiperelay 経由)
# 必要に応じてコメント解除
# if command -v npiperelay.exe >/dev/null 2>&1; then
#     export GPG_AGENT_SOCK="$HOME/.gnupg/S.gpg-agent"
# fi
