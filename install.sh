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
CLAUDE_SELECTED=false
GITCONFIG_VARIANT=""

# ============================================================================
# カラー出力
# ============================================================================

if [ -t 1 ]; then
    COLOR_GREEN='\033[0;32m'
    COLOR_YELLOW='\033[0;33m'
    COLOR_RED='\033[0;31m'
    COLOR_BLUE='\033[0;34m'
    COLOR_CYAN='\033[0;36m'
    COLOR_BOLD='\033[1m'
    COLOR_RESET='\033[0m'
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
    if [ -f /proc/sys/fs/binfmt_misc/WSLInterop ] || \
       [ -n "${WSL_DISTRO_NAME:-}" ] || \
       grep -qi microsoft /proc/version 2>/dev/null; then
        echo "wsl"
    elif [ "$(uname)" = "Darwin" ]; then
        echo "macos"
    else
        echo "linux"
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
        if [ -e "$dest" ] && [ ! -L "$dest" ]; then
            print_info "[ドライラン] バックアップ: $dest -> ${dest}.bak"
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
    create_link ".git-completion.bash" "${HOME}/.git-completion.bash"
    create_link ".git-prompt.sh" "${HOME}/.git-prompt.sh"
}

uninstall_git_files() {
    remove_link ".git-completion.bash" "${HOME}/.git-completion.bash"
    remove_link ".git-prompt.sh" "${HOME}/.git-prompt.sh"
}

# Gitignore設定 (work/privateに応じて選択)
install_gitignore() {
    if [ -z "$GITCONFIG_VARIANT" ]; then
        return 0
    fi

    create_link ".gitignore.${GITCONFIG_VARIANT}" "${HOME}/.gitignore_global"
}

uninstall_gitignore() {
    remove_link ".gitignore.work" "${HOME}/.gitignore_global"
    remove_link ".gitignore.private" "${HOME}/.gitignore_global"
}

# Vim設定ファイル
install_vim_files() {
    create_link ".vimrc" "${HOME}/.vimrc"
}

uninstall_vim_files() {
    remove_link ".vimrc" "${HOME}/.vimrc"
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

install_shell_config() {
    if [ "$SHELL_SELECTED" != "true" ]; then
        return 0
    fi

    print_header "シェル設定をインストール"

    case "$SHELL_TYPE" in
        bash)
            create_link "shell/bash/bashrc" "${HOME}/.bashrc"
            create_link "shell/bash/bash_profile" "${HOME}/.bash_profile"
            ;;
        zsh)
            create_link "shell/zsh/zshrc" "${HOME}/.zshrc"
            create_link "shell/zsh/zprofile" "${HOME}/.zprofile"
            ;;
        fish)
            ensure_dir "${HOME}/.config/fish"
            create_link "shell/fish/config.fish" "${HOME}/.config/fish/config.fish"
            ;;
        all)
            create_link "shell/bash/bashrc" "${HOME}/.bashrc"
            create_link "shell/bash/bash_profile" "${HOME}/.bash_profile"
            create_link "shell/zsh/zshrc" "${HOME}/.zshrc"
            create_link "shell/zsh/zprofile" "${HOME}/.zprofile"
            ensure_dir "${HOME}/.config/fish"
            create_link "shell/fish/config.fish" "${HOME}/.config/fish/config.fish"
            ;;
    esac
}

uninstall_shell_config() {
    print_header "シェル設定をアンインストール"

    remove_link "shell/bash/bashrc" "${HOME}/.bashrc"
    remove_link "shell/bash/bash_profile" "${HOME}/.bash_profile"
    remove_link "shell/zsh/zshrc" "${HOME}/.zshrc"
    remove_link "shell/zsh/zprofile" "${HOME}/.zprofile"
    remove_link "shell/fish/config.fish" "${HOME}/.config/fish/config.fish"
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

    create_link ".gitconfig.${GITCONFIG_VARIANT}" "${HOME}/.gitconfig"
}

uninstall_gitconfig() {
    remove_link ".gitconfig.work" "${HOME}/.gitconfig"
    remove_link ".gitconfig.private" "${HOME}/.gitconfig"
}

# ============================================================================
# Claude設定
# ============================================================================

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

    # claude-config/ 内のファイルを取得してリンク
    if [ -d "${DOTFILES_DIR}/claude-config" ]; then
        cd "$DOTFILES_DIR"
        git ls-files claude-config/ 2>/dev/null | while read -r file; do
            [ -z "$file" ] && continue

            relative="${file#claude-config/}"

            # 配置先パスを計算
            case "$relative" in
                skills/*)
                    # skills/スキル名/ファイル -> ~/.claude/skills/スキル名/ファイル
                    dest="${HOME}/.claude/${relative}"
                    ;;
                *)
                    dest="${HOME}/.claude/${relative}"
                    ;;
            esac

            # 配置先の親ディレクトリを作成
            dest_dir=$(dirname "$dest")
            ensure_dir "$dest_dir"

            create_link "$file" "$dest"
        done
    fi
}

uninstall_claude_config() {
    print_header "Claude設定をアンインストール"

    if [ -d "${DOTFILES_DIR}/claude-config" ]; then
        cd "$DOTFILES_DIR"
        git ls-files claude-config/ 2>/dev/null | while read -r file; do
            [ -z "$file" ] && continue

            relative="${file#claude-config/}"

            case "$relative" in
                skills/*)
                    dest="${HOME}/.claude/${relative}"
                    ;;
                *)
                    dest="${HOME}/.claude/${relative}"
                    ;;
            esac

            remove_link "$file" "$dest"
        done
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
                GIT_SELECTED=true
                select_gitconfig_variant
                VIM_SELECTED=true
                CLAUDE_SELECTED=true
                return
                ;;
            1)
                SHELL_SELECTED=true
                select_shell_type
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
    if [ "$SHELL_SELECTED" != "true" ] && \
       [ "$GIT_SELECTED" != "true" ] && \
       [ "$VIM_SELECTED" != "true" ] && \
       [ "$CLAUDE_SELECTED" != "true" ]; then
        die "ファイルが選択されていません"
    fi

    print_header "インストールするファイル"
    echo ""

    if [ "$SHELL_SELECTED" = "true" ]; then
        printf "  ${COLOR_CYAN}シェル設定 (${SHELL_TYPE}):${COLOR_RESET}\n"
        case "$SHELL_TYPE" in
            bash)
                printf "    + shell/bash/bashrc -> ~/.bashrc\n"
                printf "    + shell/bash/bash_profile -> ~/.bash_profile\n"
                ;;
            zsh)
                printf "    + shell/zsh/zshrc -> ~/.zshrc\n"
                printf "    + shell/zsh/zprofile -> ~/.zprofile\n"
                ;;
            fish)
                printf "    + shell/fish/config.fish -> ~/.config/fish/config.fish\n"
                ;;
            all)
                printf "    + shell/bash/bashrc -> ~/.bashrc\n"
                printf "    + shell/bash/bash_profile -> ~/.bash_profile\n"
                printf "    + shell/zsh/zshrc -> ~/.zshrc\n"
                printf "    + shell/zsh/zprofile -> ~/.zprofile\n"
                printf "    + shell/fish/config.fish -> ~/.config/fish/config.fish\n"
                ;;
        esac
        echo ""
    fi

    if [ "$GIT_SELECTED" = "true" ]; then
        printf "  ${COLOR_CYAN}Git設定:${COLOR_RESET}\n"
        printf "    + .git-completion.bash -> ~/.git-completion.bash\n"
        printf "    + .git-prompt.sh -> ~/.git-prompt.sh\n"
        if [ -n "$GITCONFIG_VARIANT" ]; then
            printf "    + .gitconfig.%s -> ~/.gitconfig\n" "$GITCONFIG_VARIANT"
            printf "    + .gitignore.%s -> ~/.gitignore_global\n" "$GITCONFIG_VARIANT"
        fi
        echo ""
    fi

    if [ "$VIM_SELECTED" = "true" ]; then
        printf "  ${COLOR_CYAN}Vim設定:${COLOR_RESET}\n"
        printf "    + .vimrc -> ~/.vimrc\n"
        echo ""
    fi

    if [ "$CLAUDE_SELECTED" = "true" ]; then
        printf "  ${COLOR_CYAN}Claude Code設定:${COLOR_RESET}\n"
        printf "    + claude-config/* -> ~/.claude/*\n"
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
    claude  Claude Code設定(claude-config/から)

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
