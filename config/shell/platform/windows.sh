#!/bin/sh
# shell/platform/windows.sh - Git Bash (MINGW/MSYS/Cygwin) 固有設定 (POSIX互換)
#
# 読み込み元: common.sh (プラットフォーム検出後)
# 対象: Git Bash on Windows (非WSL)

# ============================================================================
# Git SSH (環境別に明示指定)
# ============================================================================

export GIT_SSH_COMMAND="ssh"

# ============================================================================
# Windows連携
# ============================================================================

# Windowsホームディレクトリ (common.sh の _dotfiles_detect_win_home を使用)
WIN_HOME="${WIN_HOME:-$(_dotfiles_detect_win_home)}"
if [ -n "$WIN_HOME" ]; then
    WIN_USER="${WIN_USER:-$(basename "$WIN_HOME")}"
    export WIN_USER WIN_HOME
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

alias open='explorer.exe'
alias e.='explorer.exe .'
