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
SHELL_COMPONENTS=""  # full, append, custom
SHELL_COMP_ALIASES=false
SHELL_COMP_COMMON=false
SHELL_COMP_PROMPT=false
CLAUDE_SELECTED=false
GITCONFIG_VARIANT=""

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

    # このdotfilesへのリンクのみ削除
    if [ "$target" != "$src" ]; then
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
}

uninstall_git_files() {
    remove_link "config/git/.git-completion.bash" "${HOME}/.git-completion.bash"
    remove_link "config/git/.git-prompt.sh" "${HOME}/.git-prompt.sh"
    remove_link "config/git/.git-prompt.sh" "${HOME}/.config/git/.git-prompt.sh"
}

# Gitignore設定 (base + work/privateを結合)
install_gitignore() {
    if [ -z "$GITCONFIG_VARIANT" ]; then
        return 0
    fi

    target="${HOME}/.gitignore_global"
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

    # 結合してコピー
    cat "$base" "$variant" > "$target"
    printf "%s[CREATE]%s %s (base + %s)\n" "$COLOR_GREEN" "$COLOR_RESET" "$target" "$GITCONFIG_VARIANT"
}

uninstall_gitignore() {
    target="${HOME}/.gitignore_global"

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
    printf "  ${COLOR_BOLD}1)${COLOR_RESET} フルセット (既存設定を置き換え) ${COLOR_RED}⚠ 破壊的${COLOR_RESET}\n"
    printf "     → ~/.bashrc 等をリポジトリのものに置換 (既存は .bak にバックアップ)\n"
    printf "  ${COLOR_BOLD}2)${COLOR_RESET} 追記モード (既存設定を保持) ${COLOR_GREEN}★推奨${COLOR_RESET}\n"
    printf "     → 既存の ~/.bashrc 等にsource行を自動挿入\n"
    printf "  ${COLOR_BOLD}3)${COLOR_RESET} カスタム選択\n"
    printf "     → コンポーネントを個別選択 (source行は手動追記)\n"
    echo ""
    printf "選択 (1-3) [2]: "
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
        3)
            SHELL_COMPONENTS="custom"
            select_shell_custom_components
            ;;
        *)
            print_error "無効な選択です。追記モードを使用します"
            SHELL_COMPONENTS="append"
            ;;
    esac
}

# カスタムコンポーネント選択
select_shell_custom_components() {
    echo ""
    printf "${COLOR_BOLD}インストールするコンポーネントを選択 (複数可、スペース区切り):${COLOR_RESET}\n"
    printf "  ${COLOR_BOLD}1)${COLOR_RESET} エイリアス (ls, git, docker等のショートカット)\n"
    printf "  ${COLOR_BOLD}2)${COLOR_RESET} 共通設定 (PATH/環境変数/プラットフォーム設定)\n"
    printf "  ${COLOR_BOLD}3)${COLOR_RESET} プロンプト設定 (git-prompt.sh)\n"
    echo ""
    printf "選択 (例: 1 2 3) [1]: "
    read -r choices

    # デフォルトはエイリアスのみ
    if [ -z "$choices" ]; then
        choices="1"
    fi

    for c in $choices; do
        case "$c" in
            1) SHELL_COMP_ALIASES=true ;;
            2) SHELL_COMP_COMMON=true ;;
            3) SHELL_COMP_PROMPT=true ;;
        esac
    done

    # 選択結果を表示
    components_list=""
    [ "$SHELL_COMP_ALIASES" = "true" ] && components_list="${components_list}エイリアス "
    [ "$SHELL_COMP_COMMON" = "true" ] && components_list="${components_list}共通設定 "
    [ "$SHELL_COMP_PROMPT" = "true" ] && components_list="${components_list}プロンプト "
    print_success "選択: ${components_list}"
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
        *)
            # custom: コンポーネント別インストール
            if [ "$SHELL_COMP_ALIASES" = "true" ]; then
                create_link "config/shell/aliases.sh" "${HOME}/.shell_aliases"
            fi

            if [ "$SHELL_COMP_COMMON" = "true" ]; then
                create_link "config/shell/common.sh" "${HOME}/.shell_common"
                print_info "ヒント: 既存の設定ファイルに以下を追加してください:"
                printf "        ${COLOR_CYAN}[ -f ~/.shell_common ] && . ~/.shell_common${COLOR_RESET}\n"
            fi

            if [ "$SHELL_COMP_PROMPT" = "true" ]; then
                create_link "config/git/.git-prompt.sh" "${HOME}/.git-prompt.sh"
                print_info "ヒント: 既存の設定ファイルに以下を追加してください:"
                printf "        ${COLOR_CYAN}[ -f ~/.git-prompt.sh ] && . ~/.git-prompt.sh${COLOR_RESET}\n"
            fi
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

    # 追記モード・カスタムモードのクリーンアップ
    remove_link "config/shell/common.sh" "${HOME}/.shell_common"
    remove_link "config/shell/aliases.sh" "${HOME}/.shell_aliases"
    remove_source_block "${HOME}/.bashrc"
    remove_source_block "${HOME}/.zshrc"
    remove_source_block "${HOME}/.config/fish/config.fish"
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
_is_stale_link() {
    [ ! -L "$1" ] && return 1
    _sl_target=$(readlink "$1" 2>/dev/null) || return 1
    case "$_sl_target" in "${DOTFILES_DIR}"/*) ;; *) return 1 ;; esac
    [ -e "$1" ] && return 1
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
        (
            cd "$DOTFILES_DIR"
            # サブシェル内で処理するため cd の影響は外に漏れない
            git ls-files claude/ 2>/dev/null | while IFS= read -r file; do
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
            done
        )
    fi
}

uninstall_claude_config() {
    print_header "Claude設定をアンインストール"

    if [ -d "${DOTFILES_DIR}/claude" ]; then
        (
            cd "$DOTFILES_DIR"
            # サブシェル内で処理するため cd の影響は外に漏れない
            git ls-files claude/ 2>/dev/null | while IFS= read -r file; do
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
            done
        )
    fi
}


# ============================================================================
# 対話的選択
# ============================================================================

show_category_menu() {
    print_header "インストールするカテゴリを選択"
    echo ""
    printf "  ${COLOR_BOLD}1)${COLOR_RESET} シェル設定 (bash/zsh/fish)\n"
    printf "  ${COLOR_BOLD}2)${COLOR_RESET} Git設定と補完\n"
    printf "  ${COLOR_BOLD}3)${COLOR_RESET} Vimエディタ設定\n"
    printf "  ${COLOR_BOLD}4)${COLOR_RESET} Claude Code AI アシスタント設定\n"
    echo ""
    printf "  ${COLOR_BOLD}a)${COLOR_RESET} すべてのカテゴリ\n"
    printf "  ${COLOR_BOLD}q)${COLOR_RESET} 終了\n"
    echo ""
}

select_files_interactive() {
    # 選択フラグ
    GIT_SELECTED=false
    VIM_SELECTED=false

    while true; do
        show_category_menu
        printf "カテゴリを選択 (1-4/a/q): "
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
                CLAUDE_SELECTED=true
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
                CLAUDE_SELECTED=true
                print_success "Claude設定を追加しました"
                ;;
            *)
                print_error "無効な選択です"
                continue
                ;;
        esac

        printf "\n選択を続けますか? [Y/n]: "
        read -r cont
        case "$cont" in
            n|N) return ;;
        esac
    done
}

confirm_installation() {
    if [ "$SHELL_SELECTED" != "true" ] && [ "$GIT_SELECTED" != "true" ] && [ "$VIM_SELECTED" != "true" ] && [ "$CLAUDE_SELECTED" != "true" ]; then
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
            *)
                printf "  ${COLOR_CYAN}シェル設定 - コンポーネント:${COLOR_RESET}\n"
                if [ "$SHELL_COMP_ALIASES" = "true" ]; then
                    printf "    + config/shell/aliases.sh -> ~/.shell_aliases\n"
                fi
                if [ "$SHELL_COMP_COMMON" = "true" ]; then
                    printf "    + config/shell/common.sh -> ~/.shell_common\n"
                fi
                if [ "$SHELL_COMP_PROMPT" = "true" ]; then
                    printf "    + config/git/.git-prompt.sh -> ~/.git-prompt.sh\n"
                fi
                ;;
        esac
        echo ""
    fi

    if [ "$GIT_SELECTED" = "true" ]; then
        printf "  ${COLOR_CYAN}Git設定:${COLOR_RESET}\n"
        printf "    + config/git/.git-completion.bash -> ~/.git-completion.bash\n"
        printf "    + config/git/.git-prompt.sh -> ~/.git-prompt.sh\n"
        if [ -n "$GITCONFIG_VARIANT" ]; then
            printf "    + config/git/.gitconfig.common -> ~/.gitconfig.common\n"
            printf "    + config/git/.gitconfig.%s -> ~/.gitconfig\n" "$GITCONFIG_VARIANT"
            printf "    + config/git/.gitignore.common + .gitignore.%s -> ~/.gitignore_global\n" "$GITCONFIG_VARIANT"
        fi
        echo ""
    fi

    if [ "$VIM_SELECTED" = "true" ]; then
        printf "  ${COLOR_CYAN}Vim設定:${COLOR_RESET}\n"
        printf "    + config/vim/.vimrc -> ~/.vimrc\n"
        echo ""
    fi

    if [ "$CLAUDE_SELECTED" = "true" ]; then
        printf "  ${COLOR_CYAN}Claude Code設定:${COLOR_RESET}\n"
        printf "    + claude/* -> ~/.claude/*\n"
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

    install_claude_config
}

uninstall_files() {
    print_header "dotfilesをアンインストール"

    uninstall_shell_config
    uninstall_git_files
    uninstall_gitconfig
    uninstall_gitignore
    uninstall_vim_files
    uninstall_claude_config
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
    claude  Claude Code設定(claude/から)

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
        if [ "$MODE_INTERACTIVE" = "true" ] && [ "$MODE_DRY_RUN" != "true" ]; then
            printf "すべてのdotfilesシンボリックリンクを削除しますか? [y/N]: "
            read -r confirm
            case "$confirm" in
                y|Y) ;;
                *) echo "キャンセルしました。"; exit 0 ;;
            esac
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
            CLAUDE_SELECTED=true

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
