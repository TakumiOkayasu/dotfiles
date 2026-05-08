#!/bin/sh
#
# dotfiles インストーラー (POSIX sh互換)
# dotfilesのシンボリックリンクをホームディレクトリに作成します
#
# 使い方:
#   ./install.sh              # 対話モード(デフォルト)
#   ./install.sh -f           # 全ファイルを強制インストール
#   ./install.sh -n           # ドライラン(プレビューのみ)
#   ./install.sh -u           # アンインストール
#

set -eu

# 一時ファイル cleanup
_TMPFILES=""
cleanup_tmpfiles() {
    for _f in $_TMPFILES; do
        rm -f "$_f"
    done
}
trap cleanup_tmpfiles EXIT INT TERM

# ============================================================================
# 定数・設定
# ============================================================================

# スクリプトのディレクトリを取得
DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

# モードフラグ
MODE_INTERACTIVE=true
MODE_DRY_RUN=false
MODE_UNINSTALL=false

# カウンター
COUNT_CREATED=0
COUNT_SKIPPED=0
COUNT_BACKUP=0
COUNT_REMOVED=0
COUNT_ERROR=0

# 選択状態
SHELL_SELECTED=false
SHELL_TYPE=""  # bash, zsh, fish, all
SHELL_COMPONENTS=""  # full, append
BIN_SELECTED=false
CLAUDE_SELECTED=false
CODEX_SELECTED=false
GITCONFIG_VARIANT=""

# アンインストール対象
UNINSTALL_SHELL=false
UNINSTALL_GIT=false
UNINSTALL_VIM=false
UNINSTALL_BIN=false
UNINSTALL_CLAUDE=false
UNINSTALL_CODEX=false

# vendor スキル
VENDOR_SKILLS="composition-patterns react-best-practices web-design-guidelines"

# 追記モード用マーカー
DOTWORK_MARKER_BEGIN="# === dotfile-work: BEGIN ==="
DOTWORK_MARKER_END="# === dotfile-work: END ==="

# ============================================================================
# カラー出力
# ============================================================================

if [ -t 1 ]; then
    COLOR_GREEN=$(printf '\033[0;32m')
    COLOR_YELLOW=$(printf '\033[0;33m')
    COLOR_RED=$(printf '\033[0;31m')
    COLOR_BLUE=$(printf '\033[0;34m')
    COLOR_CYAN=$(printf '\033[0;36m')
    COLOR_BOLD=$(printf '\033[1m')
    COLOR_RESET=$(printf '\033[0m')
else
    COLOR_GREEN=''
    COLOR_YELLOW=''
    COLOR_RED=''
    COLOR_BLUE=''
    COLOR_CYAN=''
    COLOR_BOLD=''
    COLOR_RESET=''
fi

# ============================================================================
# ユーティリティ関数
# ============================================================================

# パスを正規化 (クロスプラットフォーム対応)
canonicalize_path() {
    [ -z "$1" ] && return 0
    readlink -f "$1" 2>/dev/null || realpath "$1" 2>/dev/null || {
        # macOS BSD fallback: ディレクトリ部分を解決
        _cp_dir=$(cd -P "$(dirname "$1")" 2>/dev/null && pwd -P) || { echo "$1"; return; }
        echo "${_cp_dir}/$(basename "$1")"
    }
}

die() {
    printf "${COLOR_RED}エラー:${COLOR_RESET} %s\n" "$1" >&2
    exit "${2:-1}"
}

print_success() { printf "${COLOR_GREEN}✓${COLOR_RESET} %s\n" "$1"; }
print_skip()    { printf "${COLOR_YELLOW}○${COLOR_RESET} %s\n" "$1"; }
print_error()   { printf "${COLOR_RED}✗${COLOR_RESET} %s\n" "$1"; }
print_info()    { printf "${COLOR_BLUE}→${COLOR_RESET} %s\n" "$1"; }
print_header()  { printf "\n${COLOR_BOLD}${COLOR_CYAN}%s${COLOR_RESET}\n" "$1"; }

# 必須コマンドの確認
check_requirements() {
    for cmd in git ln mkdir rm mv; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            die "必須コマンドが見つかりません: $cmd"
        fi
    done
}

# ディレクトリ作成
ensure_dir() {
    dir="$1"

    # シンボリックリンクの場合は削除(壊れたリンクも含む)
    if [ -L "$dir" ]; then
        if [ "$MODE_DRY_RUN" = "true" ]; then
            print_info "[ドライラン] 既存リンク削除: $dir"
        else
            rm "$dir" 2>/dev/null || true
        fi
    fi

    if [ ! -d "$dir" ]; then
        if [ "$MODE_DRY_RUN" = "true" ]; then
            print_info "[ドライラン] ディレクトリ作成: $dir"
        else
            if ! mkdir -p "$dir" 2>/dev/null; then
                print_error "ディレクトリ作成失敗: $dir"
                COUNT_ERROR=$((COUNT_ERROR + 1))
                return 1
            fi
        fi
    fi
    return 0
}

# プラットフォーム検出
detect_platform() {
    if [ -f /proc/sys/fs/binfmt_misc/WSLInterop ] || [ -n "${WSL_DISTRO_NAME:-}" ] || grep -qi microsoft /proc/version 2>/dev/null; then
        echo "wsl"
    elif [ "$(uname)" = "Darwin" ]; then
        echo "macos"
    else
        case "$(uname -s)" in
            CYGWIN*|MINGW*|MSYS*) echo "windows" ;;
            *) echo "linux" ;;
        esac
    fi
}

# 現在のシェルを検出
detect_current_shell() {
    shell_path="${SHELL:-}"
    case "$shell_path" in
        */bash) echo "bash" ;;
        */zsh)  echo "zsh" ;;
        */fish) echo "fish" ;;
        *)      echo "bash" ;;
    esac
}

# シェルのrcファイル名を返す (メニュー表示用)
get_shell_rc_display() {
    case "$1" in
        bash) echo "~/.bashrc" ;;
        zsh)  echo "~/.zshrc" ;;
        fish) echo "~/.config/fish/config.fish" ;;
        all)  echo "~/.bashrc, ~/.zshrc, config.fish" ;;
        *)    echo "~/.bashrc" ;;
    esac
}

# ============================================================================
# シンボリックリンク操作
# ============================================================================

create_link() {
    src="${DOTFILES_DIR}/$1"
    dest="$2"

    if [ ! -e "$src" ]; then
        print_skip "スキップ: $src (ファイルが存在しません)"
        COUNT_SKIPPED=$((COUNT_SKIPPED + 1))
        return 0
    fi

    dest_dir="$(dirname "$dest")"

    if [ "$MODE_DRY_RUN" = "true" ]; then
        print_info "[ドライラン] 作成: $dest -> $src"
        COUNT_CREATED=$((COUNT_CREATED + 1))
        if [ -e "$dest" ] && [ ! -L "$dest" ]; then
            print_info "[ドライラン] バックアップ: $dest -> ${dest}.bak"
            COUNT_BACKUP=$((COUNT_BACKUP + 1))
        fi
        return 0
    fi

    # ディレクトリ確保
    if ! ensure_dir "$dest_dir"; then
        return 1
    fi

    # 既存ファイルの処理
    if [ -L "$dest" ]; then
        if ! rm "$dest" 2>/dev/null; then
            print_error "既存リンク削除失敗: $dest"
            COUNT_ERROR=$((COUNT_ERROR + 1))
            return 1
        fi
    elif [ -e "$dest" ]; then
        print_info "バックアップ: $dest -> ${dest}.bak"
        if ! mv "$dest" "${dest}.bak" 2>/dev/null; then
            print_error "バックアップ失敗: $dest"
            COUNT_ERROR=$((COUNT_ERROR + 1))
            return 1
        fi
        COUNT_BACKUP=$((COUNT_BACKUP + 1))
    fi

    # リンク作成
    if ln -s "$src" "$dest" 2>/dev/null; then
        print_success "作成: $dest"
        echo "         -> $src"
        COUNT_CREATED=$((COUNT_CREATED + 1))
    else
        print_error "リンク作成失敗: $dest"
        COUNT_ERROR=$((COUNT_ERROR + 1))
        return 1
    fi
}

remove_link() {
    src="${DOTFILES_DIR}/$1"
    dest="$2"

    # ファイルが存在しない場合はスキップ
    if [ ! -e "$dest" ] && [ ! -L "$dest" ]; then
        return 0
    fi

    if [ ! -L "$dest" ]; then
        print_skip "スキップ: $dest (シンボリックリンクではありません)"
        COUNT_SKIPPED=$((COUNT_SKIPPED + 1))
        return 0
    fi

    target="$(readlink "$dest" 2>/dev/null)" || true

    # このdotfilesへのリンクのみ削除 (正規化パスで比較、クロスプラットフォーム対応)
    resolved_target="$(canonicalize_path "$target")"
    resolved_src="$(canonicalize_path "$src")"
    if [ "$resolved_target" != "$resolved_src" ]; then
        print_skip "スキップ: $dest (別の場所を指しています)"
        COUNT_SKIPPED=$((COUNT_SKIPPED + 1))
        return 0
    fi

    if [ "$MODE_DRY_RUN" = "true" ]; then
        print_info "[ドライラン] 削除: $dest"
        return 0
    fi

    if rm "$dest" 2>/dev/null; then
        print_success "削除: $dest"
        COUNT_REMOVED=$((COUNT_REMOVED + 1))

        # バックアップがあれば復元
        if [ -e "${dest}.bak" ]; then
            if mv "${dest}.bak" "$dest" 2>/dev/null; then
                print_info "復元: ${dest}.bak -> $dest"
            else
                print_error "復元失敗: ${dest}.bak"
            fi
        fi
    else
        print_error "削除失敗: $dest"
        COUNT_ERROR=$((COUNT_ERROR + 1))
        return 1
    fi
}

# ============================================================================
# ファイル定義
# ============================================================================

# Git設定ファイル
install_git_files() {
    create_link "config/git/.git-completion.bash" "${HOME}/.git-completion.bash"
    create_link "config/git/.git-prompt.sh" "${HOME}/.git-prompt.sh"

    # Git for Windows用プロンプト設定
    ensure_dir "${HOME}/.config/git"
    create_link "config/git/.git-prompt.sh" "${HOME}/.config/git/.git-prompt.sh"

    # グローバル gitattributes (改行コード LF 固定)
    create_link "config/git/.gitattributes" "${HOME}/.config/git/.gitattributes"
}

uninstall_git_files() {
    remove_link "config/git/.git-completion.bash" "${HOME}/.git-completion.bash"
    remove_link "config/git/.git-prompt.sh" "${HOME}/.git-prompt.sh"
    remove_link "config/git/.git-prompt.sh" "${HOME}/.config/git/.git-prompt.sh"
    remove_link "config/git/.gitattributes" "${HOME}/.config/git/.gitattributes"
}

# Gitignore設定 (base + work/privateを結合)
install_gitignore() {
    if [ -z "$GITCONFIG_VARIANT" ]; then
        return 0
    fi

    target="${HOME}/.gitignore"
    base="${DOTFILES_DIR}/config/git/.gitignore.common"
    variant="${DOTFILES_DIR}/config/git/.gitignore.${GITCONFIG_VARIANT}"

    if [ "$MODE_DRY_RUN" = "true" ]; then
        printf "%s[DRY-RUN]%s Would create: %s (base + %s)\n" "$COLOR_YELLOW" "$COLOR_RESET" "$target" "$GITCONFIG_VARIANT"
        return 0
    fi

    # 既存ファイルをバックアップ（シンボリックリンクの場合は削除）
    if [ -f "$target" ] || [ -L "$target" ]; then
        if [ -L "$target" ]; then
            rm "$target"
        else
            mv "$target" "${target}.bak"
            printf "%s[BACKUP]%s %s -> %s.bak\n" "$COLOR_YELLOW" "$COLOR_RESET" "$target" "$target"
        fi
    fi

    # variant ファイルの存在チェック
    if [ ! -f "$variant" ]; then
        printf "%s[ERROR]%s variant not found: %s\n" "$COLOR_RED" "$COLOR_RESET" "$variant"
        return 1
    fi

    # 結合してコピー
    cat "$base" "$variant" > "$target"
    printf "%s[CREATE]%s %s (base + %s)\n" "$COLOR_GREEN" "$COLOR_RESET" "$target" "$GITCONFIG_VARIANT"
}

uninstall_gitignore() {
    target="${HOME}/.gitignore"

    if [ -f "$target" ]; then
        rm "$target"
        printf "%s[REMOVE]%s %s\n" "$COLOR_RED" "$COLOR_RESET" "$target"
    fi

    # バックアップがあれば復元
    if [ -f "${target}.bak" ]; then
        mv "${target}.bak" "$target"
        printf "%s[RESTORE]%s %s.bak -> %s\n" "$COLOR_GREEN" "$COLOR_RESET" "$target" "$target"
    fi
}

# Vim設定ファイル
install_vim_files() {
    create_link "config/vim/.vimrc" "${HOME}/.vimrc"
}

uninstall_vim_files() {
    remove_link "config/vim/.vimrc" "${HOME}/.vimrc"
}

# ============================================================================
# シェル設定
# ============================================================================

select_shell_type() {
    if [ -n "$SHELL_TYPE" ]; then
        return 0
    fi

    current_shell=$(detect_current_shell)

    echo ""
    printf "${COLOR_BOLD}シェル設定を選択:${COLOR_RESET}\n"
    printf "  ${COLOR_BOLD}1)${COLOR_RESET} bash のみ\n"
    printf "  ${COLOR_BOLD}2)${COLOR_RESET} zsh のみ\n"
    printf "  ${COLOR_BOLD}3)${COLOR_RESET} fish のみ\n"
    printf "  ${COLOR_BOLD}4)${COLOR_RESET} すべて (bash + zsh + fish)\n"
    printf "  ${COLOR_BOLD}5)${COLOR_RESET} 現在のシェル (%s) のみ\n" "$current_shell"
    echo ""
    printf "選択 (1-5) [5]: "
    read -r choice

    case "$choice" in
        1) SHELL_TYPE="bash" ;;
        2) SHELL_TYPE="zsh" ;;
        3) SHELL_TYPE="fish" ;;
        4) SHELL_TYPE="all" ;;
        5|"") SHELL_TYPE="$current_shell" ;;
        *)
            print_error "無効な選択です。現在のシェルを使用します"
            SHELL_TYPE="$current_shell"
            ;;
    esac

    print_success "シェル設定: ${SHELL_TYPE}"
}

# シェルコンポーネント選択
select_shell_components() {
    echo ""
    printf "${COLOR_BOLD}インストールする内容を選択:${COLOR_RESET}\n"
    shell_rc=$(get_shell_rc_display "$SHELL_TYPE")
    printf "  ${COLOR_BOLD}1)${COLOR_RESET} フルセット (既存設定を置き換え) ${COLOR_RED}⚠ 破壊的${COLOR_RESET}\n"
    printf "     → %s 等をリポジトリのものに置換 (既存は .bak にバックアップ)\n" "$shell_rc"
    printf "  ${COLOR_BOLD}2)${COLOR_RESET} 追記モード (既存設定を保持) ${COLOR_GREEN}★推奨${COLOR_RESET}\n"
    printf "     → 既存の %s にsource行を自動挿入\n" "$shell_rc"
    echo ""
    printf "選択 (1-2) [2]: "
    read -r choice

    case "$choice" in
        1)
            SHELL_COMPONENTS="full"
            print_success "フルセットを選択しました"
            ;;
        2|"")
            SHELL_COMPONENTS="append"
            print_success "追記モードを選択しました"
            ;;
        *)
            print_error "無効な選択です。追記モードを使用します"
            SHELL_COMPONENTS="append"
            ;;
    esac
}

install_shell_config() {
    if [ "$SHELL_SELECTED" != "true" ]; then
        return 0
    fi

    print_header "シェル設定をインストール"

    case "$SHELL_COMPONENTS" in
        full)
            install_shell_full
            ;;
        append)
            install_shell_append
            ;;
    esac
}

# フルセットインストール (従来の動作)
install_shell_full() {
    case "$SHELL_TYPE" in
        bash)
            create_link "config/shell/bash/bashrc" "${HOME}/.bashrc"
            create_link "config/shell/bash/bash_profile" "${HOME}/.bash_profile"
            ;;
        zsh)
            create_link "config/shell/zsh/zshrc" "${HOME}/.zshrc"
            create_link "config/shell/zsh/zprofile" "${HOME}/.zprofile"
            ;;
        fish)
            ensure_dir "${HOME}/.config/fish"
            create_link "config/shell/fish/config.fish" "${HOME}/.config/fish/config.fish"
            ;;
        all)
            create_link "config/shell/bash/bashrc" "${HOME}/.bashrc"
            create_link "config/shell/bash/bash_profile" "${HOME}/.bash_profile"
            create_link "config/shell/zsh/zshrc" "${HOME}/.zshrc"
            create_link "config/shell/zsh/zprofile" "${HOME}/.zprofile"
            ensure_dir "${HOME}/.config/fish"
            create_link "config/shell/fish/config.fish" "${HOME}/.config/fish/config.fish"
            ;;
    esac
}

# ============================================================================
# 追記モード
# ============================================================================

# rcファイルにsourceブロックを挿入 (bash/zsh用)
inject_source_block() {
    target_rc="$1"

    if [ ! -f "$target_rc" ]; then
        print_skip "スキップ: $target_rc (ファイルが存在しません)"
        return 0
    fi

    # 冪等性: マーカーが既に存在すればスキップ
    if grep -qF "$DOTWORK_MARKER_BEGIN" "$target_rc" 2>/dev/null; then
        print_skip "スキップ: $target_rc (source行は挿入済み)"
        COUNT_SKIPPED=$((COUNT_SKIPPED + 1))
        return 0
    fi

    if [ "$MODE_DRY_RUN" = "true" ]; then
        print_info "[ドライラン] source行を挿入: $target_rc"
        COUNT_CREATED=$((COUNT_CREATED + 1))
        return 0
    fi

    # 末尾に改行があるか確認し、なければ追加
    if [ -s "$target_rc" ]; then
        tail_char=$(tail -c 1 "$target_rc" 2>/dev/null | wc -l)
        if [ "$tail_char" -eq 0 ]; then
            printf '\n' >> "$target_rc"
        fi
    fi

    cat >> "$target_rc" << EOF

$DOTWORK_MARKER_BEGIN
[ -f "\$HOME/.shell_common" ] && . "\$HOME/.shell_common"
$DOTWORK_MARKER_END
EOF

    print_success "source行を挿入: $target_rc"
    COUNT_CREATED=$((COUNT_CREATED + 1))
}

# 追記モード: rcファイルにsourceブロックを挿入 (fish用)
inject_source_block_fish() {
    target_rc="$1"

    if [ ! -f "$target_rc" ]; then
        print_skip "スキップ: $target_rc (ファイルが存在しません)"
        return 0
    fi

    if grep -qF "$DOTWORK_MARKER_BEGIN" "$target_rc" 2>/dev/null; then
        print_skip "スキップ: $target_rc (source行は挿入済み)"
        COUNT_SKIPPED=$((COUNT_SKIPPED + 1))
        return 0
    fi

    if [ "$MODE_DRY_RUN" = "true" ]; then
        print_info "[ドライラン] source行を挿入: $target_rc"
        COUNT_CREATED=$((COUNT_CREATED + 1))
        return 0
    fi

    if [ -s "$target_rc" ]; then
        tail_char=$(tail -c 1 "$target_rc" 2>/dev/null | wc -l)
        if [ "$tail_char" -eq 0 ]; then
            printf '\n' >> "$target_rc"
        fi
    fi

    cat >> "$target_rc" << EOF

$DOTWORK_MARKER_BEGIN
bass source "\$HOME/.shell_common"
$DOTWORK_MARKER_END
EOF

    print_success "source行を挿入: $target_rc"
    print_info "注意: fishでは bass プラグインが必要です (fisher install edc/bass)"
    COUNT_CREATED=$((COUNT_CREATED + 1))
}

# 追記モード: rcファイルからsourceブロックを削除
remove_source_block() {
    target_rc="$1"

    if [ ! -f "$target_rc" ]; then
        return 0
    fi

    if ! grep -qF "$DOTWORK_MARKER_BEGIN" "$target_rc" 2>/dev/null; then
        return 0
    fi

    if [ "$MODE_DRY_RUN" = "true" ]; then
        print_info "[ドライラン] source行を削除: $target_rc"
        return 0
    fi

    # 一時ファイル経由で書き換え (sed -i はPOSIX非準拠)
    tmp_file="${target_rc}.dotwork_tmp"
    in_block=false
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            *"$DOTWORK_MARKER_BEGIN"*)
                in_block=true
                continue
                ;;
            *"$DOTWORK_MARKER_END"*)
                in_block=false
                continue
                ;;
        esac
        if [ "$in_block" = "false" ]; then
            printf '%s\n' "$line"
        fi
    done < "$target_rc" > "$tmp_file"

    mv "$tmp_file" "$target_rc"

    print_success "source行を削除: $target_rc"
    COUNT_REMOVED=$((COUNT_REMOVED + 1))
}

# 追記モードインストール
install_shell_append() {
    # ~/.shell_common のシンボリックリンクを作成
    create_link "config/shell/common.sh" "${HOME}/.shell_common"

    # 選択シェルのrcファイルにsourceブロックを挿入
    case "$SHELL_TYPE" in
        bash)
            inject_source_block "${HOME}/.bashrc"
            ;;
        zsh)
            inject_source_block "${HOME}/.zshrc"
            ;;
        fish)
            ensure_dir "${HOME}/.config/fish"
            inject_source_block_fish "${HOME}/.config/fish/config.fish"
            ;;
        all)
            inject_source_block "${HOME}/.bashrc"
            inject_source_block "${HOME}/.zshrc"
            ensure_dir "${HOME}/.config/fish"
            inject_source_block_fish "${HOME}/.config/fish/config.fish"
            ;;
    esac
}

uninstall_shell_config() {
    print_header "シェル設定をアンインストール"

    # フルセットのリンク削除
    remove_link "config/shell/bash/bashrc" "${HOME}/.bashrc"
    remove_link "config/shell/bash/bash_profile" "${HOME}/.bash_profile"
    remove_link "config/shell/zsh/zshrc" "${HOME}/.zshrc"
    remove_link "config/shell/zsh/zprofile" "${HOME}/.zprofile"
    remove_link "config/shell/fish/config.fish" "${HOME}/.config/fish/config.fish"

    # 追記モードのクリーンアップ
    remove_link "config/shell/common.sh" "${HOME}/.shell_common"
    remove_source_block "${HOME}/.bashrc"
    remove_source_block "${HOME}/.zshrc"
    remove_source_block "${HOME}/.config/fish/config.fish"
}

# ============================================================================
# CLIツール (bin/)
# ============================================================================

install_bin_files() {
    if [ "$BIN_SELECTED" != "true" ]; then
        return 0
    fi

    print_header "CLIツールをインストール"

    ensure_dir "${HOME}/.local/bin"

    for bin_file in "$DOTFILES_DIR"/bin/*; do
        [ ! -f "$bin_file" ] && continue
        bin_name=$(basename "$bin_file")
        create_link "bin/$bin_name" "${HOME}/.local/bin/$bin_name"
    done
}

uninstall_bin_files() {
    for bin_file in "$DOTFILES_DIR"/bin/*; do
        [ ! -f "$bin_file" ] && continue
        bin_name=$(basename "$bin_file")
        remove_link "bin/$bin_name" "${HOME}/.local/bin/$bin_name"
    done
}

# ============================================================================
# .gitconfig選択
# ============================================================================

select_gitconfig_variant() {
    if [ -n "$GITCONFIG_VARIANT" ]; then
        return 0
    fi

    echo ""
    printf "${COLOR_BOLD}.gitconfigの環境を選択:${COLOR_RESET}\n"
    printf "  ${COLOR_BOLD}1)${COLOR_RESET} プライベート用 (macOS: /Users/...)\n"
    printf "  ${COLOR_BOLD}2)${COLOR_RESET} 仕事用 (Linux: /home/...)\n"
    echo ""
    printf "選択 (1/2): "
    read -r choice

    case "$choice" in
        1) GITCONFIG_VARIANT="private" ;;
        2) GITCONFIG_VARIANT="work" ;;
        *)
            print_error "無効な選択です。プライベート用を使用します"
            GITCONFIG_VARIANT="private"
            ;;
    esac

    print_success ".gitconfig: ${GITCONFIG_VARIANT} を選択しました"
}

install_gitconfig() {
    if [ -z "$GITCONFIG_VARIANT" ]; then
        return 0
    fi

    # 共通設定（work/privateから include される）
    create_link "config/git/.gitconfig.common" "${HOME}/.gitconfig.common"
    # 環境固有設定
    create_link "config/git/.gitconfig.${GITCONFIG_VARIANT}" "${HOME}/.gitconfig"
}

uninstall_gitconfig() {
    # 共通設定
    remove_link "config/git/.gitconfig.common" "${HOME}/.gitconfig.common"
    # 環境固有設定
    target=$(readlink "${HOME}/.gitconfig" 2>/dev/null) || true
    case "$target" in
        */.gitconfig.work)   remove_link "config/git/.gitconfig.work" "${HOME}/.gitconfig" ;;
        */.gitconfig.private) remove_link "config/git/.gitconfig.private" "${HOME}/.gitconfig" ;;
    esac
}

# ============================================================================
# Claude設定
# ============================================================================

# DOTFILES_DIR向きの壊れたシンボリックリンクか判定
# return 0 = stale, return 1 = not stale
# DOTFILES_DIR を指すシンボリックリンクのうち、git管理外のものを判定
# (壊れたリンク or リンク先がgit ls-filesに含まれない)
_is_stale_link() {
    [ ! -L "$1" ] && return 1
    _sl_target=$(readlink "$1" 2>/dev/null) || return 1
    _sl_target=$(canonicalize_path "$_sl_target")
    case "$_sl_target" in "${_csl_dotfiles}"/*) ;; *) return 1 ;; esac
    # 壊れたリンク → stale
    [ ! -e "$1" ] && return 0
    # リンク先がgit管理下にあるか確認
    _sl_relative="${_sl_target#"${_csl_dotfiles}"/}"
    (cd "$DOTFILES_DIR" && git ls-files --error-unmatch "$_sl_relative" >/dev/null 2>&1) && return 1
    return 0
}

# 古いリンク/ディレクトリを削除 (ドライラン対応・エラー報告付き)
# $1: パス, $2: メッセージ, $3: "rf"でrm -rf使用
_remove_stale() {
    if [ "$MODE_DRY_RUN" = "true" ]; then
        print_info "[ドライラン] 削除: $2"
        return 0
    fi
    _rs_ok=false
    if [ "${3:-}" = "rf" ]; then
        rm -rf "$1" 2>/dev/null && _rs_ok=true
    else
        rm "$1" 2>/dev/null && _rs_ok=true
    fi
    if [ "$_rs_ok" = "true" ]; then
        print_info "削除: $2"
    else
        print_error "削除失敗: $2"
        COUNT_ERROR=$((COUNT_ERROR + 1))
    fi
}

# ~/.claude/ 配下の孤立シンボリックリンクをクリーンアップ
cleanup_stale_claude_links() {
    _csl_dotfiles=$(canonicalize_path "$DOTFILES_DIR")
    for _dir in commands hooks skills rules; do
        _target_dir="${HOME}/.claude/${_dir}"
        [ ! -d "$_target_dir" ] && continue
        for _entry in "$_target_dir"/*; do
            if [ -L "$_entry" ]; then
                # フラットリンク (commands/, hooks/)
                _is_stale_link "$_entry" || continue
                _name=$(basename "$_entry")
                _remove_stale "$_entry" "古い${_dir}: $_name"
            elif [ -d "$_entry" ]; then
                # ディレクトリ (skills/)
                _name=$(basename "$_entry")
                # 旧4ティア構造
                case "$_name" in
                    1-core|2-domain|3-task|4-utility)
                        _remove_stale "$_entry" "旧スキル構造: $_name" rf
                        continue
                        ;;
                esac
                # 中身が全てDOTFILES_DIR向き壊れたリンク → ディレクトリごと削除
                # 空ディレクトリはスキップ（手動作成の可能性）
                _has_entries=false
                _all_stale=true
                for _f in "$_entry"/*; do
                    [ ! -L "$_f" ] && [ ! -e "$_f" ] && continue
                    _has_entries=true
                    _is_stale_link "$_f" || { _all_stale=false; break; }
                done
                [ "$_has_entries" = "true" ] && [ "$_all_stale" = "true" ] || continue
                _remove_stale "$_entry" "古い${_dir}: $_name" rf
            fi
        done
    done
}

# ~/.codex/ 配下の孤立シンボリックリンクをクリーンアップ
cleanup_stale_codex_links() {
    _csl_dotfiles=$(canonicalize_path "$DOTFILES_DIR")
    for _dir in bin hooks prompts rules skills; do
        _target_dir="${HOME}/.codex/${_dir}"
        [ ! -d "$_target_dir" ] && continue
        for _entry in "$_target_dir"/*; do
            if [ -L "$_entry" ]; then
                _is_stale_link "$_entry" || continue
                _name=$(basename "$_entry")
                _remove_stale "$_entry" "古いCodex ${_dir}: $_name"
            elif [ -d "$_entry" ]; then
                _name=$(basename "$_entry")
                _has_entries=false
                _all_stale=true
                for _f in "$_entry"/*; do
                    [ ! -L "$_f" ] && [ ! -e "$_f" ] && continue
                    _has_entries=true
                    _is_stale_link "$_f" || { _all_stale=false; break; }
                done
                [ "$_has_entries" = "true" ] && [ "$_all_stale" = "true" ] || continue
                _remove_stale "$_entry" "古いCodex ${_dir}: $_name" rf
            fi
        done
    done
}

install_claude_config() {
    if [ "$CLAUDE_SELECTED" != "true" ]; then
        return 0
    fi

    print_header "Claude設定をインストール"

    # ベースディレクトリ作成
    ensure_dir "${HOME}/.claude"
    ensure_dir "${HOME}/.claude/bin"
    ensure_dir "${HOME}/.claude/hooks"
    ensure_dir "${HOME}/.claude/skills"
    ensure_dir "${HOME}/.claude/rules"

    # 孤立シンボリックリンクをクリーンアップ
    cleanup_stale_claude_links

    # claude/ 内のファイルを取得してリンク
    if [ -d "${DOTFILES_DIR}/claude" ]; then
        _claude_filelist=$(mktemp)
        _TMPFILES="$_TMPFILES $_claude_filelist"
        (cd "$DOTFILES_DIR" && git ls-files claude/ 2>/dev/null) > "$_claude_filelist"

        while IFS= read -r file; do
            [ -z "$file" ] && continue

            relative="${file#claude/}"

            # CLAUDE.md は除外 (プロジェクトローカル用)
            case "$relative" in
                CLAUDE.md)
                    continue
                    ;;
            esac

            # 配置先パスを計算
            # global_CLAUDE.md は CLAUDE.md にリネーム
            case "$relative" in
                global_CLAUDE.md)
                    relative="CLAUDE.md"
                    ;;
            esac
            dest="${HOME}/.claude/${relative}"

            # 配置先の親ディレクトリを作成
            dest_dir=$(dirname "$dest")
            ensure_dir "$dest_dir"

            create_link "$file" "$dest"
        done < "$_claude_filelist"

        rm -f "$_claude_filelist"
    fi

    # --- vendor スキル ---
    _vendor_dir="${HOME}/.claude/vendor"
    _agent_skills_repo="https://github.com/vercel-labs/agent-skills.git"
    _agent_skills_dir="${_vendor_dir}/agent-skills"
    ensure_dir "$_vendor_dir"

    if [ ! -d "$_agent_skills_dir/.git" ]; then
        if [ "$MODE_DRY_RUN" = "true" ]; then
            print_info "[ドライラン] vendor: agent-skills を取得"
        else
            if git clone --depth 1 --quiet "$_agent_skills_repo" "$_agent_skills_dir" 2>/dev/null; then
                print_success "取得: vendor/agent-skills"
            else
                print_skip "vendor/agent-skills の取得に失敗（オフライン？）"
            fi
        fi
    fi

    if [ -d "$_agent_skills_dir/skills" ]; then
        for _skill in $VENDOR_SKILLS; do
            _src="${_agent_skills_dir}/skills/${_skill}"
            _dest="${HOME}/.claude/skills/${_skill}"
            # 壊れた symlink を除去
            if [ -L "$_dest" ] && [ ! -e "$_dest" ]; then
                rm "$_dest" 2>/dev/null
            fi
            if [ -e "$_src" ] && [ ! -e "$_dest" ]; then
                if [ "$MODE_DRY_RUN" = "true" ]; then
                    print_info "[ドライラン] リンク: ~/.claude/skills/${_skill}"
                else
                    ln -s "$_src" "$_dest" &&
                        print_success "作成: ~/.claude/skills/${_skill}" ||
                        print_error "リンク作成失敗: ${_skill}"
                fi
            fi
        done
    fi
}

uninstall_claude_config() {
    print_header "Claude設定をアンインストール"

    # 孤立シンボリックリンクをクリーンアップ (git管理外の旧ファイル)
    cleanup_stale_claude_links

    if [ -d "${DOTFILES_DIR}/claude" ]; then
        _claude_filelist=$(mktemp)
        _TMPFILES="$_TMPFILES $_claude_filelist"
        (cd "$DOTFILES_DIR" && git ls-files claude/ 2>/dev/null) > "$_claude_filelist"

        while IFS= read -r file; do
            [ -z "$file" ] && continue

            relative="${file#claude/}"

            # CLAUDE.md は除外 (プロジェクトローカル用)
            case "$relative" in
                CLAUDE.md)
                    continue
                    ;;
            esac

            # global_CLAUDE.md は CLAUDE.md にリネーム
            case "$relative" in
                global_CLAUDE.md)
                    relative="CLAUDE.md"
                    ;;
            esac
            dest="${HOME}/.claude/${relative}"
            remove_link "$file" "$dest"
        done < "$_claude_filelist"

        rm -f "$_claude_filelist"

        # vendor スキルのシンボリックリンク削除
        for _skill in $VENDOR_SKILLS; do
            _dest="${HOME}/.claude/skills/${_skill}"
            if [ -L "$_dest" ]; then
                if [ "$MODE_DRY_RUN" = "true" ]; then
                    print_info "[ドライラン] 削除: ~/.claude/skills/${_skill}"
                else
                    rm "$_dest" && print_success "削除: ~/.claude/skills/${_skill}"
                fi
            fi
        done
        if [ -d "${HOME}/.claude/vendor/agent-skills" ]; then
            if [ "$MODE_DRY_RUN" = "true" ]; then
                print_info "[ドライラン] 削除: ~/.claude/vendor/agent-skills"
            else
                rm -rf "${HOME}/.claude/vendor/agent-skills" && print_success "削除: ~/.claude/vendor/agent-skills"
                rmdir "${HOME}/.claude/vendor" 2>/dev/null || true
            fi
        fi

        # dotfiles が作成した空ディレクトリを削除 (深い順、ネスト対応)
        # ~/.claude/ 自体は Claude Code のデータがあるため削除しない
        _empty_count=$(find "${HOME}/.claude" -mindepth 1 -depth -type d 2>/dev/null \
            | while IFS= read -r _dir; do rmdir "$_dir" 2>/dev/null && echo x; done \
            | wc -l)
        [ "$_empty_count" -gt 0 ] && print_success "空ディレクトリ削除: .claude/ 配下 ${_empty_count} 件"
    fi
}

# ============================================================================
# Codex設定
# ============================================================================

install_codex_config() {
    if [ "$CODEX_SELECTED" != "true" ]; then
        return 0
    fi

    print_header "Codex設定をインストール"

    ensure_dir "${HOME}/.codex"
    ensure_dir "${HOME}/.codex/bin"
    ensure_dir "${HOME}/.codex/hooks"
    ensure_dir "${HOME}/.codex/prompts"
    ensure_dir "${HOME}/.codex/rules"
    ensure_dir "${HOME}/.codex/skills"

    cleanup_stale_codex_links

    if [ -d "${DOTFILES_DIR}/codex" ]; then
        _codex_filelist=$(mktemp)
        _TMPFILES="$_TMPFILES $_codex_filelist"
        (cd "$DOTFILES_DIR" && { git ls-files codex/ 2>/dev/null; git ls-files --others --exclude-standard codex/ 2>/dev/null; } | sort -u) > "$_codex_filelist"

        while IFS= read -r file; do
            [ -z "$file" ] && continue

            relative="${file#codex/}"
            dest="${HOME}/.codex/${relative}"

            dest_dir=$(dirname "$dest")
            ensure_dir "$dest_dir"

            create_link "$file" "$dest"
        done < "$_codex_filelist"

        rm -f "$_codex_filelist"
    fi

    if command -v codex >/dev/null 2>&1; then
        if codex features list 2>/dev/null | grep -q '^hooks[[:space:]]'; then
            print_success "Codex hooks feature: 利用可能"
        elif codex features list 2>/dev/null | grep -q '^codex_hooks[[:space:]]'; then
            print_info "Codex hooks feature: codex_hooks を有効化してください (codex features enable codex_hooks)"
        fi
    fi
}

uninstall_codex_config() {
    print_header "Codex設定をアンインストール"

    cleanup_stale_codex_links

    if [ -d "${DOTFILES_DIR}/codex" ]; then
        _codex_filelist=$(mktemp)
        _TMPFILES="$_TMPFILES $_codex_filelist"
        (cd "$DOTFILES_DIR" && { git ls-files codex/ 2>/dev/null; git ls-files --others --exclude-standard codex/ 2>/dev/null; } | sort -u) > "$_codex_filelist"

        while IFS= read -r file; do
            [ -z "$file" ] && continue

            relative="${file#codex/}"
            dest="${HOME}/.codex/${relative}"
            remove_link "$file" "$dest"
        done < "$_codex_filelist"

        rm -f "$_codex_filelist"

        _empty_count=$(find "${HOME}/.codex" -mindepth 1 -depth -type d 2>/dev/null \
            | while IFS= read -r _dir; do rmdir "$_dir" 2>/dev/null && echo x; done \
            | wc -l)
        [ "$_empty_count" -gt 0 ] && print_success "空ディレクトリ削除: .codex/ 配下 ${_empty_count} 件"
    fi
}


# ============================================================================
# 対話的選択
# ============================================================================

select_uninstall_components() {
    echo ""
    printf "${COLOR_BOLD}アンインストールするカテゴリを選択 (複数可、スペース区切り):${COLOR_RESET}\n"
    printf "  ${COLOR_BOLD}1)${COLOR_RESET} シェル設定\n"
    printf "  ${COLOR_BOLD}2)${COLOR_RESET} Git設定\n"
    printf "  ${COLOR_BOLD}3)${COLOR_RESET} Vim設定\n"
    printf "  ${COLOR_BOLD}4)${COLOR_RESET} CLIツール\n"
    printf "  ${COLOR_BOLD}5)${COLOR_RESET} Claude Code設定\n"
    printf "  ${COLOR_BOLD}6)${COLOR_RESET} Codex設定\n"
    printf "  ${COLOR_BOLD}a)${COLOR_RESET} すべて\n"
    echo ""
    printf "選択 (例: 1 3 / a) [a]: "
    read -r choices

    case "$choices" in
        a|A|"")
            UNINSTALL_SHELL=true
            UNINSTALL_GIT=true
            UNINSTALL_VIM=true
            UNINSTALL_BIN=true
            UNINSTALL_CLAUDE=true
            UNINSTALL_CODEX=true
            ;;
        *)
            for c in $choices; do
                case "$c" in
                    1) UNINSTALL_SHELL=true ;;
                    2) UNINSTALL_GIT=true ;;
                    3) UNINSTALL_VIM=true ;;
                    4) UNINSTALL_BIN=true ;;
                    5) UNINSTALL_CLAUDE=true ;;
                    6) UNINSTALL_CODEX=true ;;
                    *) print_error "無効な選択をスキップ: $c" ;;
                esac
            done
            ;;
    esac

    # 選択結果を表示
    selected=""
    [ "$UNINSTALL_SHELL" = "true" ] && selected="${selected}シェル "
    [ "$UNINSTALL_GIT" = "true" ] && selected="${selected}Git "
    [ "$UNINSTALL_VIM" = "true" ] && selected="${selected}Vim "
    [ "$UNINSTALL_BIN" = "true" ] && selected="${selected}CLIツール "
    [ "$UNINSTALL_CLAUDE" = "true" ] && selected="${selected}Claude "
    [ "$UNINSTALL_CODEX" = "true" ] && selected="${selected}Codex "

    if [ -z "$selected" ]; then
        die "カテゴリが選択されていません"
    fi

    print_success "アンインストール対象: ${selected}"
}

show_category_menu() {
    print_header "インストールするカテゴリを選択"
    echo ""
    printf "  ${COLOR_BOLD}1)${COLOR_RESET} シェル設定\n"
    printf "     PATH, エイリアス, プロンプト, SSH Agent を設定\n"
    printf "  ${COLOR_BOLD}2)${COLOR_RESET} Git設定\n"
    printf "     gitconfig, 補完, gitignore を設定\n"
    printf "  ${COLOR_BOLD}3)${COLOR_RESET} Vim設定\n"
    printf "     .vimrc を配置\n"
    printf "  ${COLOR_BOLD}4)${COLOR_RESET} CLIツール\n"
    printf "     git-new-feature 等を ~/.local/bin/ に配置\n"
    printf "  ${COLOR_BOLD}5)${COLOR_RESET} Claude Code設定\n"
    printf "     hooks, skills, rules, commands を ~/.claude/ に配置\n"
    printf "  ${COLOR_BOLD}6)${COLOR_RESET} Codex設定\n"
    printf "     hooks, skills, rules, prompts を ~/.codex/ に配置\n"
    echo ""
    printf "  ${COLOR_BOLD}a)${COLOR_RESET} すべて  ${COLOR_BOLD}q)${COLOR_RESET} 終了\n"
    echo ""
}

select_files_interactive() {
    # 選択フラグ
    GIT_SELECTED=false
    VIM_SELECTED=false

    while true; do
        show_category_menu
        printf "カテゴリを選択 (1-6/a/q): "
        read -r choice

        case "$choice" in
            q|Q)
                echo "キャンセルしました。"
                exit 0
                ;;
            a|A)
                SHELL_SELECTED=true
                select_shell_type
                SHELL_COMPONENTS="full"
                GIT_SELECTED=true
                select_gitconfig_variant
                VIM_SELECTED=true
                BIN_SELECTED=true
                CLAUDE_SELECTED=true
                CODEX_SELECTED=true
                return
                ;;
            1)
                SHELL_SELECTED=true
                select_shell_type
                select_shell_components
                ;;
            2)
                GIT_SELECTED=true
                select_gitconfig_variant
                ;;
            3)
                VIM_SELECTED=true
                print_success "Vim設定を追加しました"
                ;;
            4)
                BIN_SELECTED=true
                print_success "CLIツールを追加しました"
                ;;
            5)
                CLAUDE_SELECTED=true
                print_success "Claude Code設定を追加しました"
                ;;
            6)
                CODEX_SELECTED=true
                print_success "Codex設定を追加しました"
                ;;
            *)
                print_error "無効な選択です"
                continue
                ;;
        esac

        # 全カテゴリ選択済みなら自動で抜ける
        if [ "$SHELL_SELECTED" = "true" ] && [ "$GIT_SELECTED" = "true" ] && [ "$VIM_SELECTED" = "true" ] && [ "$BIN_SELECTED" = "true" ] && [ "$CLAUDE_SELECTED" = "true" ] && [ "$CODEX_SELECTED" = "true" ]; then
            print_success "全カテゴリが選択されました"
            return
        fi

        printf "\n選択を続けますか? [Y/n]: "
        read -r cont
        case "$cont" in
            n|N) return ;;
        esac
    done
}

confirm_installation() {
    if [ "$SHELL_SELECTED" != "true" ] && [ "$GIT_SELECTED" != "true" ] && [ "$VIM_SELECTED" != "true" ] && [ "$BIN_SELECTED" != "true" ] && [ "$CLAUDE_SELECTED" != "true" ] && [ "$CODEX_SELECTED" != "true" ]; then
        die "ファイルが選択されていません"
    fi

    print_header "インストールするファイル"
    echo ""

    if [ "$SHELL_SELECTED" = "true" ]; then
        case "$SHELL_COMPONENTS" in
            full)
                printf "  ${COLOR_CYAN}シェル設定 - フルセット (${SHELL_TYPE}):${COLOR_RESET}\n"
                case "$SHELL_TYPE" in
                    bash)
                        printf "    + config/shell/bash/bashrc -> ~/.bashrc\n"
                        printf "    + config/shell/bash/bash_profile -> ~/.bash_profile\n"
                        ;;
                    zsh)
                        printf "    + config/shell/zsh/zshrc -> ~/.zshrc\n"
                        printf "    + config/shell/zsh/zprofile -> ~/.zprofile\n"
                        ;;
                    fish)
                        printf "    + config/shell/fish/config.fish -> ~/.config/fish/config.fish\n"
                        ;;
                    all)
                        printf "    + config/shell/bash/bashrc -> ~/.bashrc\n"
                        printf "    + config/shell/bash/bash_profile -> ~/.bash_profile\n"
                        printf "    + config/shell/zsh/zshrc -> ~/.zshrc\n"
                        printf "    + config/shell/zsh/zprofile -> ~/.zprofile\n"
                        printf "    + config/shell/fish/config.fish -> ~/.config/fish/config.fish\n"
                        ;;
                esac
                ;;
            append)
                printf "  ${COLOR_CYAN}シェル設定 - 追記モード (${SHELL_TYPE}):${COLOR_RESET}\n"
                printf "    + config/shell/common.sh -> ~/.shell_common\n"
                case "$SHELL_TYPE" in
                    bash)
                        printf "    → ~/.bashrc にsource行を自動挿入\n"
                        ;;
                    zsh)
                        printf "    → ~/.zshrc にsource行を自動挿入\n"
                        ;;
                    fish)
                        printf "    → ~/.config/fish/config.fish にsource行を自動挿入\n"
                        ;;
                    all)
                        printf "    → ~/.bashrc, ~/.zshrc, ~/.config/fish/config.fish にsource行を自動挿入\n"
                        ;;
                esac
                ;;
        esac
        echo ""
    fi

    if [ "$GIT_SELECTED" = "true" ]; then
        printf "  ${COLOR_CYAN}Git設定:${COLOR_RESET}\n"
        printf "    + config/git/.git-completion.bash -> ~/.git-completion.bash\n"
        printf "    + config/git/.git-prompt.sh -> ~/.git-prompt.sh\n"
        printf "    + config/git/.gitattributes -> ~/.config/git/.gitattributes\n"
        if [ -n "$GITCONFIG_VARIANT" ]; then
            printf "    + config/git/.gitconfig.common -> ~/.gitconfig.common\n"
            printf "    + config/git/.gitconfig.%s -> ~/.gitconfig\n" "$GITCONFIG_VARIANT"
            printf "    + config/git/.gitignore.common + .gitignore.%s -> ~/.gitignore\n" "$GITCONFIG_VARIANT"
        fi
        echo ""
    fi

    if [ "$VIM_SELECTED" = "true" ]; then
        printf "  ${COLOR_CYAN}Vim設定:${COLOR_RESET}\n"
        printf "    + config/vim/.vimrc -> ~/.vimrc\n"
        echo ""
    fi

    if [ "$BIN_SELECTED" = "true" ]; then
        printf "  ${COLOR_CYAN}CLIツール:${COLOR_RESET}\n"
        printf "    + bin/* -> ~/.local/bin/*\n"
        echo ""
    fi

    if [ "$CLAUDE_SELECTED" = "true" ]; then
        printf "  ${COLOR_CYAN}Claude Code設定:${COLOR_RESET}\n"
        printf "    + claude/* -> ~/.claude/*\n"
        echo ""
    fi

    if [ "$CODEX_SELECTED" = "true" ]; then
        printf "  ${COLOR_CYAN}Codex設定:${COLOR_RESET}\n"
        printf "    + codex/* -> ~/.codex/*\n"
        printf "    + codex/hooks.json -> ~/.codex/hooks.json\n"
        echo ""
    fi

    printf "インストールを実行しますか? [Y/n]: "
    read -r confirm
    case "$confirm" in
        n|N)
            echo "キャンセルしました。"
            exit 0
            ;;
    esac
}

# ============================================================================
# メイン処理
# ============================================================================

install_files() {
    print_header "dotfilesをインストール: $DOTFILES_DIR"

    install_shell_config

    if [ "$GIT_SELECTED" = "true" ]; then
        install_git_files
        install_gitconfig
        install_gitignore
    fi

    if [ "$VIM_SELECTED" = "true" ]; then
        install_vim_files
    fi

    install_bin_files
    install_claude_config
    install_codex_config
}

uninstall_files() {
    print_header "dotfilesをアンインストール"

    if [ "$UNINSTALL_SHELL" = "true" ]; then
        uninstall_shell_config
    fi
    if [ "$UNINSTALL_GIT" = "true" ]; then
        uninstall_git_files
        uninstall_gitconfig
        uninstall_gitignore
    fi
    if [ "$UNINSTALL_VIM" = "true" ]; then
        uninstall_vim_files
    fi
    if [ "$UNINSTALL_BIN" = "true" ]; then
        uninstall_bin_files
    fi
    if [ "$UNINSTALL_CLAUDE" = "true" ]; then
        uninstall_claude_config
    fi
    if [ "$UNINSTALL_CODEX" = "true" ]; then
        uninstall_codex_config
    fi
}

show_summary() {
    print_header "結果"
    echo ""

    if [ "$MODE_UNINSTALL" = "true" ]; then
        printf "  削除: ${COLOR_GREEN}%d${COLOR_RESET}\n" "$COUNT_REMOVED"
    else
        printf "  作成: ${COLOR_GREEN}%d${COLOR_RESET}\n" "$COUNT_CREATED"
        printf "  バックアップ: ${COLOR_YELLOW}%d${COLOR_RESET}\n" "$COUNT_BACKUP"
    fi
    printf "  スキップ: ${COLOR_YELLOW}%d${COLOR_RESET}\n" "$COUNT_SKIPPED"

    if [ $COUNT_ERROR -gt 0 ]; then
        printf "  エラー: ${COLOR_RED}%d${COLOR_RESET}\n" "$COUNT_ERROR"
    fi
    echo ""
}

show_help() {
    cat << 'EOF'
dotfiles インストーラー - dotfilesのシンボリックリンクを作成

使い方:
    ./install.sh [オプション]

オプション:
    -h, --help          このヘルプを表示
    -i, --interactive   対話モード(デフォルト)
    -f, --force         確認なしで全ファイルをインストール
    -n, --dry-run       実行内容をプレビュー(変更なし)
    -u, --uninstall     作成したシンボリックリンクを削除

カテゴリ:
    shell   シェル設定 (bash/zsh/fish 選択可能)
    git     Git設定(.gitconfig.work/private, .git-completion.bash等)
    vim     Vim設定(.vimrc)
    bin     CLIツール (git-new-feature等 → ~/.local/bin/)
    claude  Claude Code設定 (claude/)
    codex   Codex設定 (codex/)

例:
    ./install.sh              # 対話的にインストール
    ./install.sh -f           # すべてインストール(現在のシェルのみ)
    ./install.sh -n           # インストール内容をプレビュー
    ./install.sh -u           # すべてのシンボリックリンクを削除
EOF
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -i|--interactive)
                MODE_INTERACTIVE=true
                shift
                ;;
            -f|--force)
                MODE_INTERACTIVE=false
                shift
                ;;
            -n|--dry-run)
                MODE_DRY_RUN=true
                shift
                ;;
            -u|--uninstall)
                MODE_UNINSTALL=true
                shift
                ;;
            *)
                die "不明なオプション: $1\nヘルプは -h で表示"
                ;;
        esac
    done
}

cleanup() {
    echo ""
    print_info "中断されました"
    exit 130
}

main() {
    trap cleanup INT TERM

    parse_args "$@"
    check_requirements

    if [ "$MODE_DRY_RUN" = "true" ]; then
        print_header "ドライランモード - 変更は行われません"
    fi

    if [ "$MODE_UNINSTALL" = "true" ]; then
        if [ "$MODE_INTERACTIVE" = "true" ]; then
            select_uninstall_components
            if [ "$MODE_DRY_RUN" != "true" ]; then
                printf "\nアンインストールを実行しますか? [y/N]: "
                read -r confirm
                case "$confirm" in
                    y|Y) ;;
                    *) echo "キャンセルしました。"; exit 0 ;;
                esac
            fi
        else
            UNINSTALL_SHELL=true
            UNINSTALL_GIT=true
            UNINSTALL_VIM=true
            UNINSTALL_BIN=true
            UNINSTALL_CLAUDE=true
            UNINSTALL_CODEX=true
        fi
        uninstall_files
    else
        if [ "$MODE_INTERACTIVE" = "true" ]; then
            select_files_interactive
            confirm_installation
        else
            # 強制モード: すべて選択
            SHELL_SELECTED=true
            SHELL_TYPE=$(detect_current_shell)
            SHELL_COMPONENTS="full"
            GIT_SELECTED=true
            VIM_SELECTED=true
            BIN_SELECTED=true
            CLAUDE_SELECTED=true
            CODEX_SELECTED=true

            # プラットフォーム自動検出
            platform=$(detect_platform)
            if [ "$platform" = "macos" ]; then
                GITCONFIG_VARIANT="private"
            else
                GITCONFIG_VARIANT="work"
            fi
            print_info ".gitconfig: ${GITCONFIG_VARIANT} を自動選択しました"
            print_info "シェル設定: ${SHELL_TYPE} を自動選択しました"
        fi
        install_files
    fi

    show_summary

    [ $COUNT_ERROR -gt 0 ] && exit 1
    exit 0
}

main "$@"
