#!/bin/sh
# config/shell/common.sh - 全シェル共通設定 (POSIX互換)
#
# 読み込み元: bashrc, zshrc, config.fish (bass経由)
# 内容: PATH, 環境変数, プラットフォーム検出
#
# 注意: POSIX sh 互換を維持すること
#   - [[ ]] ではなく [ ] を使用
#   - 配列を使用しない
#   - function キーワードを使用しない
#   - local は source 元 (bash/zsh) 専用の許容例外 (POSIX sh 単独実行は想定しない)

# SC1090/SC1091: 動的パス/外部ファイルの source は追跡不可を許容
# SC3043: local は source 元 (bash/zsh) が対応するため使用 (POSIX sh 単独実行はしない)
# shellcheck disable=SC1090,SC1091,SC3043

# ============================================================================
# 二重読み込み防止
# ============================================================================

if [ -n "$DOTFILES_LOADED" ]; then
    # source されていれば return、直接実行なら exit (静的解析は後者を到達不能と誤検出)
    # shellcheck disable=SC2317
    return 0 2>/dev/null || exit 0
fi
DOTFILES_LOADED=1

# ============================================================================
# dotfiles ディレクトリ検出
# ============================================================================

# このファイルからの相対パスで dotfiles ルートを検出
_dotfiles_detect_root() {
    local this_file="$1"

    # シンボリックリンクを解決
    while [ -L "$this_file" ]; do
        local dir
        dir="$(cd -P "$(dirname "$this_file")" && pwd)"
        this_file="$(readlink "$this_file")"
        case "$this_file" in
            /*) ;;
            *) this_file="$dir/$this_file" ;;
        esac
    done

    # config/shell/ の親の親ディレクトリが dotfiles ルート
    local shell_dir
    shell_dir="$(cd -P "$(dirname "$this_file")" && pwd)"
    dirname "$(dirname "$shell_dir")"
}

# DOTFILES_DIR が未設定なら検出
if [ -z "$DOTFILES_DIR" ]; then
    # 呼び出し元によって検出方法を変える
    # SC2128: bash では $BASH_SOURCE 先頭要素 (=このファイル) で十分
    # shellcheck disable=SC2128
    if [ -n "$BASH_SOURCE" ]; then
        DOTFILES_DIR="$(_dotfiles_detect_root "$BASH_SOURCE")"
    elif [ -n "$ZSH_VERSION" ]; then
        # SC2296: ${(%):-%x} は zsh 固有 (このパスは zsh でのみ実行される)
        # shellcheck disable=SC2296
        DOTFILES_DIR="$(_dotfiles_detect_root "${(%):-%x}")"
    else
        # フォールバック: よくある場所を探す
        for dir in "$HOME/dotfiles" "$HOME/prog/dotfile-work" "$HOME/.dotfiles"; do
            if [ -d "$dir/config/shell" ]; then
                DOTFILES_DIR="$dir"
                break
            fi
        done
    fi
fi

export DOTFILES_DIR

# ============================================================================
# プラットフォーム検出
# ============================================================================

_dotfiles_detect_platform() {
    # WSL検出
    if [ -f /proc/sys/fs/binfmt_misc/WSLInterop ] || \
       [ -n "$WSL_DISTRO_NAME" ] || \
       grep -qi microsoft /proc/version 2>/dev/null; then
        echo "wsl"
        return
    fi

    # OS検出
    case "$(uname -s)" in
        Darwin)
            echo "macos"
            ;;
        Linux)
            echo "linux"
            ;;
        CYGWIN*|MINGW*|MSYS*)
            echo "windows"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

DOTFILES_PLATFORM="$(_dotfiles_detect_platform)"
export DOTFILES_PLATFORM

# ============================================================================
# Windows連携ユーティリティ (WSL/Git Bash/Cygwin共通)
# ============================================================================

# Windowsホームディレクトリ検出 (Unix形式パスを返す)
# local/windows.sh, local/wsl.sh から呼ばれる (静的解析では未検出)
# SC2329 (>=0.10) / SC2317 (0.9 は本体を到達不能と誤検出) の両方を抑制する
# shellcheck disable=SC2317,SC2329
_dotfiles_detect_win_home() {
    # 既に設定済みならそのまま返す
    [ -n "${WIN_HOME:-}" ] && echo "$WIN_HOME" && return 0

    case "$DOTFILES_PLATFORM" in
        wsl)
            # wslpath が最も確実
            if command -v wslpath >/dev/null 2>&1; then
                _dw_profile=$(cmd.exe /c "echo %USERPROFILE%" 2>/dev/null | tr -d '\r')
                if [ -n "$_dw_profile" ]; then
                    _dw_result=$(wslpath "$_dw_profile" 2>/dev/null)
                    unset _dw_profile
                    [ -n "$_dw_result" ] && echo "$_dw_result" && unset _dw_result && return 0
                    unset _dw_result
                fi
                unset _dw_profile
            fi
            # フォールバック: cmd.exe でユーザー名取得
            _dw_user=$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r' 2>/dev/null) || _dw_user="$(whoami)"
            if [ -d "/mnt/c/Users/$_dw_user" ]; then
                echo "/mnt/c/Users/$_dw_user" && unset _dw_user && return 0
            fi
            unset _dw_user
            ;;
        windows)
            # cygpath (Git Bash/MSYS/Cygwin)
            if command -v cygpath >/dev/null 2>&1 && [ -n "${USERPROFILE:-}" ]; then
                cygpath "$USERPROFILE" 2>/dev/null && return 0
            fi
            # フォールバック: 環境変数から推定
            _dw_user="${USERNAME:-$(whoami)}"
            if [ -d "/c/Users/$_dw_user" ]; then
                echo "/c/Users/$_dw_user" && unset _dw_user && return 0
            fi
            unset _dw_user
            ;;
    esac
    return 1
}

# ============================================================================
# PATH設定
# ============================================================================

# パスを追加 (重複チェック付き)
_dotfiles_add_path() {
    local new_path="$1"
    local position="${2:-prepend}"  # prepend or append

    [ ! -d "$new_path" ] && return

    case ":$PATH:" in
        *":$new_path:"*)
            # 既に含まれている
            return
            ;;
    esac

    if [ "$position" = "append" ]; then
        PATH="$PATH:$new_path"
    else
        PATH="$new_path:$PATH"
    fi
}

# dotfiles/bin
_dotfiles_add_path "$DOTFILES_DIR/bin"

# ユーザーローカル
_dotfiles_add_path "$HOME/.local/bin"
_dotfiles_add_path "$HOME/bin"

export PATH

# ============================================================================
# 環境変数
# ============================================================================

# エディタ (EDITOR / VISUAL)
if command -v code >/dev/null 2>&1; then
    export EDITOR="code --wait"
elif command -v vim >/dev/null 2>&1; then
    export EDITOR="vim"
elif command -v vi >/dev/null 2>&1; then
    export EDITOR="vim"
fi
export VISUAL="$EDITOR"

# ロケール
export LANG="${LANG:-ja_JP.UTF-8}"
export LC_ALL="${LC_ALL:-ja_JP.UTF-8}"
export LC_CTYPE="${LC_CTYPE:-ja_JP.UTF-8}"
export LC_NUMERIC="${LC_NUMERIC:-ja_JP.UTF-8}"
export LC_TIME="${LC_TIME:-ja_JP.UTF-8}"
export LC_COLLATE="${LC_COLLATE:-ja_JP.UTF-8}"
export LC_MONETARY="${LC_MONETARY:-ja_JP.UTF-8}"
export LC_MESSAGES="${LC_MESSAGES:-ja_JP.UTF-8}"
export LC_PAPER="${LC_PAPER:-ja_JP.UTF-8}"
export LC_NAME="${LC_NAME:-ja_JP.UTF-8}"
export LC_ADDRESS="${LC_ADDRESS:-ja_JP.UTF-8}"
export LC_TELEPHONE="${LC_TELEPHONE:-ja_JP.UTF-8}"
export LC_MEASUREMENT="${LC_MEASUREMENT:-ja_JP.UTF-8}"
export LC_IDENTIFICATION="${LC_IDENTIFICATION:-ja_JP.UTF-8}"

# ページャー
export PAGER="less"
export LESS="-R -F -X"

# ============================================================================
# ローカル設定 (Git管理外、プラットフォーム設定より先に読み込む)
# ============================================================================

if [ -f "$HOME/.local.sh" ]; then
    . "$HOME/.local.sh"
fi

# ============================================================================
# プラットフォーム固有設定の読み込み
# ============================================================================

_dotfiles_load_platform() {
    local platform_file="$DOTFILES_DIR/config/shell/local/${DOTFILES_PLATFORM}.sh"
    if [ -f "$platform_file" ]; then
        . "$platform_file"
    fi
}

_dotfiles_load_platform

# ============================================================================
# エイリアス読み込み
# ============================================================================

if [ -f "$DOTFILES_DIR/config/shell/aliases.sh" ]; then
    . "$DOTFILES_DIR/config/shell/aliases.sh"
fi

# ============================================================================
# クリーンアップ (内部関数を削除)
# ============================================================================

unset -f _dotfiles_detect_root
unset -f _dotfiles_detect_platform
unset -f _dotfiles_detect_win_home
unset -f _dotfiles_add_path
unset -f _dotfiles_load_platform
