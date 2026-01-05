#!/usr/bin/env bash
#
# dotfiles インストーラー
# dotfilesのシンボリックリンクをホームディレクトリに作成します
#
# 使い方:
#   ./install.sh              # 対話モード(デフォルト)
#   ./install.sh -f           # 全ファイルを強制インストール
#   ./install.sh -n           # ドライラン(プレビューのみ)
#   ./install.sh -u           # アンインストール
#
# 必要条件:
#   bash 4.0以上 (macOSでは: brew install bash)
#

set -euo pipefail

# ============================================================================
# バージョンチェック
# ============================================================================

if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
    echo "エラー: bash 4.0以上が必要です (現在: ${BASH_VERSION})" >&2
    echo "" >&2
    echo "macOSの場合:" >&2
    echo "  1. brew install bash" >&2
    echo "  2. /opt/homebrew/bin/bash ./install.sh" >&2
    echo "" >&2
    echo "または、homebrewのbashをデフォルトに設定:" >&2
    echo "  sudo bash -c 'echo /opt/homebrew/bin/bash >> /etc/shells'" >&2
    echo "  chsh -s /opt/homebrew/bin/bash" >&2
    exit 1
fi

# ============================================================================
# 定数・設定
# ============================================================================

readonly DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REQUIRED_COMMANDS=(git ln mkdir rm mv readlink)

# モードフラグ
MODE_INTERACTIVE=true
MODE_DRY_RUN=false
MODE_UNINSTALL=false

# カウンター
declare -i COUNT_CREATED=0
declare -i COUNT_SKIPPED=0
declare -i COUNT_BACKUP=0
declare -i COUNT_REMOVED=0
declare -i COUNT_ERROR=0

# 選択されたファイルインデックス
declare -a SELECTED_INDICES=()
CLAUDE_SELECTED=false

# Claudeファイルリストのキャッシュ
declare -a CLAUDE_FILES_CACHE=()
CLAUDE_FILES_LOADED=false

# ============================================================================
# ファイル定義(配列形式)
# フォーマット: "カテゴリ|ソース|配置先|説明"
# ============================================================================

declare -a DOTFILE_DEFS=(
    "shell|.profile|${HOME}/.profile|共通シェル設定(PATH, 環境変数)"
    "shell|.shell_aliases|${HOME}/.shell_aliases|シェルエイリアス"
    "git|.git-completion.bash|${HOME}/.git-completion.bash|Gitコマンド補完"
    "git|.git-prompt.sh|${HOME}/.git-prompt.sh|Gitブランチ表示"
    "git|.gitignore|${HOME}/.config/git/ignore|グローバルgitignore"
    "vim|.vimrc|${HOME}/.vimrc|Vim設定"
)

# .gitconfig選択 (work/private)
GITCONFIG_VARIANT=""

readonly DOTFILE_COUNT=${#DOTFILE_DEFS[@]}

# カテゴリ定義
declare -A CATEGORY_DESC=(
    ["shell"]="シェル設定(共通profile, エイリアス)"
    ["git"]="Git設定と補完"
    ["vim"]="Vimエディタ設定"
    ["claude"]="Claude Code AI アシスタント設定"
)

readonly CATEGORIES=(shell git vim claude)

# ============================================================================
# カラー出力
# ============================================================================

if [[ -t 1 ]]; then
    readonly COLOR_GREEN='\033[0;32m'
    readonly COLOR_YELLOW='\033[0;33m'
    readonly COLOR_RED='\033[0;31m'
    readonly COLOR_BLUE='\033[0;34m'
    readonly COLOR_CYAN='\033[0;36m'
    readonly COLOR_BOLD='\033[1m'
    readonly COLOR_RESET='\033[0m'
else
    readonly COLOR_GREEN=''
    readonly COLOR_YELLOW=''
    readonly COLOR_RED=''
    readonly COLOR_BLUE=''
    readonly COLOR_CYAN=''
    readonly COLOR_BOLD=''
    readonly COLOR_RESET=''
fi

# ============================================================================
# ユーティリティ関数
# ============================================================================

# エラー終了
die() {
    printf "${COLOR_RED}エラー:${COLOR_RESET} %s\n" "$1" >&2
    exit "${2:-1}"
}

# 出力関数
print_success() { printf "${COLOR_GREEN}✓${COLOR_RESET} %s\n" "$1"; }
print_skip()    { printf "${COLOR_YELLOW}○${COLOR_RESET} %s\n" "$1"; }
print_error()   { printf "${COLOR_RED}✗${COLOR_RESET} %s\n" "$1"; }
print_info()    { printf "${COLOR_BLUE}→${COLOR_RESET} %s\n" "$1"; }
print_header()  { printf "\n${COLOR_BOLD}${COLOR_CYAN}%s${COLOR_RESET}\n" "$1"; }

# 必須コマンドの確認
check_requirements() {
    local missing=()
    for cmd in "${REQUIRED_COMMANDS[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        die "必須コマンドが見つかりません: ${missing[*]}"
    fi
}

# ディレクトリ作成(エラーハンドリング付き)
ensure_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        if $MODE_DRY_RUN; then
            print_info "[ドライラン] ディレクトリ作成: $dir"
        else
            if ! mkdir -p "$dir" 2>/dev/null; then
                print_error "ディレクトリ作成失敗: $dir"
                ((COUNT_ERROR++)) || true
                return 1
            fi
        fi
    fi
    return 0
}

# ============================================================================
# ファイル定義アクセス関数
# ============================================================================

# フィールド取得
get_dotfile_field() {
    local index="$1"
    local field="$2"
    local def="${DOTFILE_DEFS[$index]}"

    case "$field" in
        category)    echo "${def%%|*}" ;;
        source)      echo "${def#*|}" | cut -d'|' -f1 ;;
        dest)        echo "${def#*|}" | cut -d'|' -f2 ;;
        description) echo "${def##*|}" ;;
    esac
}

# カテゴリに属するインデックスを取得
get_indices_by_category() {
    local cat="$1"
    local indices=()

    for ((i = 0; i < DOTFILE_COUNT; i++)); do
        if [[ "$(get_dotfile_field "$i" category)" == "$cat" ]]; then
            indices+=("$i")
        fi
    done
    echo "${indices[*]}"
}

# ============================================================================
# .gitconfig選択関連
# ============================================================================

# .gitconfigのバリアントを選択
select_gitconfig_variant() {
    if [[ -n "$GITCONFIG_VARIANT" ]]; then
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

# .gitconfigのインストール
install_gitconfig() {
    if [[ -z "$GITCONFIG_VARIANT" ]]; then
        return 0
    fi

    local src=".gitconfig.${GITCONFIG_VARIANT}"
    local dest="${HOME}/.gitconfig"

    create_link "$src" "$dest"
}

# ============================================================================
# Claude設定ファイル関連
# ============================================================================

# Claudeファイルリストを取得(キャッシュ付き)
get_claude_config_files() {
    if ! $CLAUDE_FILES_LOADED; then
        local files
        if files=$(cd "$DOTFILES_DIR" && git ls-files claude-config/ 2>/dev/null); then
            while IFS= read -r file; do
                [[ -n "$file" ]] && CLAUDE_FILES_CACHE+=("$file")
            done <<< "$files"
        fi
        CLAUDE_FILES_LOADED=true
    fi
    printf '%s\n' "${CLAUDE_FILES_CACHE[@]}"
}

# skillsパスかどうか判定
is_skills_path() {
    [[ "$1" == skills/* ]]
}

# Claude設定ファイルの配置先パスを計算(共通化)
get_claude_dest_path() {
    local relative="$1"

    if is_skills_path "$relative"; then
        local skill_path="${relative#skills/}"
        local skill_name="${skill_path%%/*}"
        local skill_file="${skill_path#*/}"
        echo "${HOME}/.claude/skills/${skill_name}/${skill_file}"
    else
        echo "${HOME}/.claude/${relative}"
    fi
}

# Claude設定ファイルの表示用パスを計算
get_claude_display_path() {
    local relative="$1"

    if is_skills_path "$relative"; then
        local skill_path="${relative#skills/}"
        local skill_name="${skill_path%%/*}"
        local skill_file="${skill_path#*/}"
        echo "~/.claude/skills/${skill_name}/${skill_file}"
    else
        echo "~/.claude/${relative}"
    fi
}

# ============================================================================
# コア機能
# ============================================================================

# シンボリックリンク作成
create_link() {
    local src="${DOTFILES_DIR}/$1"
    local dest="$2"

    if [[ ! -e "$src" ]]; then
        print_skip "スキップ: $src (ファイルが存在しません)"
        ((COUNT_SKIPPED++)) || true
        return 0
    fi

    local dest_dir
    dest_dir="$(dirname "$dest")"

    if $MODE_DRY_RUN; then
        print_info "[ドライラン] 作成: $dest -> $src"
        if [[ -e "$dest" && ! -L "$dest" ]]; then
            print_info "[ドライラン] バックアップ: $dest -> ${dest}.bak"
        fi
        return 0
    fi

    # ディレクトリ確保
    if ! ensure_dir "$dest_dir"; then
        return 1
    fi

    # 既存ファイルの処理
    if [[ -L "$dest" ]]; then
        if ! rm "$dest" 2>/dev/null; then
            print_error "既存リンク削除失敗: $dest"
            ((COUNT_ERROR++)) || true
            return 1
        fi
    elif [[ -e "$dest" ]]; then
        print_info "バックアップ: $dest -> ${dest}.bak"
        if ! mv "$dest" "${dest}.bak" 2>/dev/null; then
            print_error "バックアップ失敗: $dest"
            ((COUNT_ERROR++)) || true
            return 1
        fi
        ((COUNT_BACKUP++)) || true
    fi

    # リンク作成
    if ln -s "$src" "$dest" 2>/dev/null; then
        print_success "作成: $dest"
        echo "         -> $src"
        ((COUNT_CREATED++)) || true
    else
        print_error "リンク作成失敗: $dest"
        ((COUNT_ERROR++)) || true
        return 1
    fi
}

# シンボリックリンク削除
remove_link() {
    local src="${DOTFILES_DIR}/$1"
    local dest="$2"

    if [[ ! -L "$dest" ]]; then
        print_skip "スキップ: $dest (シンボリックリンクではありません)"
        ((COUNT_SKIPPED++)) || true
        return 0
    fi

    local target
    target="$(readlink "$dest" 2>/dev/null)" || true

    # このdotfilesへのリンクのみ削除
    if [[ "$target" != "$src" ]]; then
        print_skip "スキップ: $dest (別の場所を指しています)"
        ((COUNT_SKIPPED++)) || true
        return 0
    fi

    if $MODE_DRY_RUN; then
        print_info "[ドライラン] 削除: $dest"
        return 0
    fi

    if rm "$dest" 2>/dev/null; then
        print_success "削除: $dest"
        ((COUNT_REMOVED++)) || true

        # バックアップがあれば復元
        if [[ -e "${dest}.bak" ]]; then
            if mv "${dest}.bak" "$dest" 2>/dev/null; then
                print_info "復元: ${dest}.bak -> $dest"
            else
                print_error "復元失敗: ${dest}.bak"
            fi
        fi
    else
        print_error "削除失敗: $dest"
        ((COUNT_ERROR++)) || true
        return 1
    fi
}

# Claude設定ファイルのインストール
install_claude_config() {
    local files
    mapfile -t files < <(get_claude_config_files)

    if [[ ${#files[@]} -eq 0 ]]; then
        print_skip "Claude設定ファイルがgitに登録されていません"
        return 0
    fi

    # ベースディレクトリ作成
    ensure_dir "${HOME}/.claude"
    ensure_dir "${HOME}/.claude/skills"

    for file in "${files[@]}"; do
        [[ -z "$file" ]] && continue

        local relative="${file#claude-config/}"
        local dest
        dest=$(get_claude_dest_path "$relative")

        # 配置先の親ディレクトリを作成 (skills/, hooks/ など)
        local dest_dir
        dest_dir=$(dirname "$dest")
        ensure_dir "$dest_dir"

        create_link "$file" "$dest"
    done
}

# Claude設定ファイルのアンインストール
uninstall_claude_config() {
    local files
    mapfile -t files < <(get_claude_config_files)

    [[ ${#files[@]} -eq 0 ]] && return 0

    for file in "${files[@]}"; do
        [[ -z "$file" ]] && continue

        local relative="${file#claude-config/}"
        local dest
        dest=$(get_claude_dest_path "$relative")

        remove_link "$file" "$dest"
    done
}

# ============================================================================
# インタラクティブUI
# ============================================================================

# カテゴリメニュー表示
show_category_menu() {
    print_header "インストールするカテゴリを選択"
    echo ""

    local i=1
    for cat in "${CATEGORIES[@]}"; do
        printf "  ${COLOR_BOLD}%d)${COLOR_RESET} %s\n" "$i" "${CATEGORY_DESC[$cat]}"
        ((i++))
    done

    echo ""
    printf "  ${COLOR_BOLD}a)${COLOR_RESET} すべてのカテゴリ\n"
    printf "  ${COLOR_BOLD}q)${COLOR_RESET} 終了\n"
    echo ""
}

# カテゴリ内ファイル表示
show_files_in_category() {
    local cat="$1"

    print_header "${CATEGORY_DESC[$cat]} のファイル"
    echo ""

    if [[ "$cat" == "claude" ]]; then
        local i=1
        local files
        mapfile -t files < <(get_claude_config_files)

        for file in "${files[@]}"; do
            [[ -z "$file" ]] && continue
            local relative="${file#claude-config/}"
            local display_dest
            display_dest=$(get_claude_display_path "$relative")

            printf "  ${COLOR_BOLD}%d)${COLOR_RESET} %s\n" "$i" "$relative"
            printf "     ${COLOR_CYAN}-> %s${COLOR_RESET}\n" "$display_dest"
            ((i++))
        done
    else
        local i=1
        local indices
        read -ra indices <<< "$(get_indices_by_category "$cat")"

        for idx in "${indices[@]}"; do
            local src desc
            src=$(get_dotfile_field "$idx" source)
            desc=$(get_dotfile_field "$idx" description)
            printf "  ${COLOR_BOLD}%d)${COLOR_RESET} %s\n" "$i" "$src"
            printf "     ${COLOR_CYAN}%s${COLOR_RESET}\n" "$desc"
            ((i++))
        done
    fi

    echo ""
    printf "  ${COLOR_BOLD}a)${COLOR_RESET} このカテゴリのすべて\n"
    printf "  ${COLOR_BOLD}b)${COLOR_RESET} カテゴリメニューに戻る\n"
    echo ""
}

# インデックスが選択済みか確認
is_index_selected() {
    local idx="$1"
    for selected in "${SELECTED_INDICES[@]}"; do
        [[ "$selected" == "$idx" ]] && return 0
    done
    return 1
}

# インデックスを選択に追加
add_to_selected() {
    local idx="$1"
    if ! is_index_selected "$idx"; then
        SELECTED_INDICES+=("$idx")
    fi
}

# 対話的ファイル選択
select_files_interactive() {
    while true; do
        show_category_menu
        printf "カテゴリを選択 (1-%d/a/q): " "${#CATEGORIES[@]}"
        read -r choice

        case "$choice" in
            q|Q)
                echo "キャンセルしました。"
                exit 0
                ;;
            a|A)
                for ((i = 0; i < DOTFILE_COUNT; i++)); do
                    add_to_selected "$i"
                done
                CLAUDE_SELECTED=true
                select_gitconfig_variant
                return
                ;;
            [1-4])
                local cat_idx=$((choice - 1))
                if [[ $cat_idx -lt ${#CATEGORIES[@]} ]]; then
                    select_from_category "${CATEGORIES[$cat_idx]}"
                fi
                ;;
            *)
                print_error "無効な選択です"
                ;;
        esac

        if [[ ${#SELECTED_INDICES[@]} -gt 0 || $CLAUDE_SELECTED == true ]]; then
            printf "\n選択を続けますか? [Y/n]: "
            read -r cont
            case "$cont" in
                n|N) return ;;
            esac
        fi
    done
}

# カテゴリからファイル選択
select_from_category() {
    local cat="$1"

    if [[ "$cat" == "claude" ]]; then
        show_files_in_category "$cat"
        printf "すべてのClaude設定ファイルをインストールしますか? [Y/n]: "
        read -r choice
        case "$choice" in
            n|N) return ;;
            *)
                CLAUDE_SELECTED=true
                print_success "Claude設定ファイルを追加しました"
                return
                ;;
        esac
    fi

    local indices
    read -ra indices <<< "$(get_indices_by_category "$cat")"
    local file_count=${#indices[@]}

    while true; do
        show_files_in_category "$cat"
        printf "ファイルを選択 (1-%d/a/b): " "$file_count"
        read -r choice

        case "$choice" in
            b|B) return ;;
            a|A)
                for idx in "${indices[@]}"; do
                    add_to_selected "$idx"
                done
                # gitカテゴリの場合は.gitconfig選択
                if [[ "$cat" == "git" ]]; then
                    select_gitconfig_variant
                fi
                print_success "${CATEGORY_DESC[$cat]} のすべてのファイルを追加しました"
                return
                ;;
            [1-9]*)
                if [[ "$choice" -ge 1 && "$choice" -le "$file_count" ]]; then
                    local target_idx="${indices[$((choice - 1))]}"
                    add_to_selected "$target_idx"
                    local src
                    src=$(get_dotfile_field "$target_idx" source)
                    print_success "追加: $src"
                else
                    print_error "無効な選択です"
                fi
                ;;
            *)
                print_error "無効な選択です"
                ;;
        esac
    done
}

# インストール確認
confirm_installation() {
    if [[ ${#SELECTED_INDICES[@]} -eq 0 && $CLAUDE_SELECTED == false && -z "$GITCONFIG_VARIANT" ]]; then
        die "ファイルが選択されていません"
    fi

    print_header "インストールするファイル"
    echo ""

    # 通常のdotfiles
    for idx in "${SELECTED_INDICES[@]}"; do
        local src dest
        src=$(get_dotfile_field "$idx" source)
        dest=$(get_dotfile_field "$idx" dest)
        printf "  ${COLOR_GREEN}+${COLOR_RESET} %s -> %s\n" "$src" "$dest"
    done

    # .gitconfig
    if [[ -n "$GITCONFIG_VARIANT" ]]; then
        printf "  ${COLOR_GREEN}+${COLOR_RESET} .gitconfig.%s -> %s/.gitconfig\n" "$GITCONFIG_VARIANT" "$HOME"
    fi

    # Claude設定
    if $CLAUDE_SELECTED; then
        echo ""
        printf "  ${COLOR_CYAN}Claude Code設定 (claude-config/):${COLOR_RESET}\n"

        local files
        mapfile -t files < <(get_claude_config_files)

        for file in "${files[@]}"; do
            [[ -z "$file" ]] && continue
            local relative="${file#claude-config/}"
            local display_dest
            display_dest=$(get_claude_display_path "$relative")
            printf "    + %s -> %s\n" "$relative" "$display_dest"
        done
    fi

    echo ""
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
# 仕事用環境設定
# ============================================================================

setup_work_environment() {
    local gitignore_global="${HOME}/.gitignore_global"

    print_header "仕事用環境設定"
    echo ""
    printf "仕事用環境ですか? (CLAUDE.mdをgit追跡から除外します) [y/N]: "
    read -r is_work

    case "$is_work" in
        y|Y)
            if $MODE_DRY_RUN; then
                print_info "[ドライラン] グローバルgitignoreにCLAUDE.mdと.claude/を追加"
                print_info "[ドライラン] core.excludesfileを設定: $gitignore_global"
                return
            fi

            local patterns_added=0

            if [[ ! -f "$gitignore_global" ]] || ! grep -q "^CLAUDE\.md$" "$gitignore_global" 2>/dev/null; then
                echo "CLAUDE.md" >> "$gitignore_global"
                ((patterns_added++)) || true
            fi

            if [[ ! -f "$gitignore_global" ]] || ! grep -q "^\.claude/$" "$gitignore_global" 2>/dev/null; then
                echo ".claude/" >> "$gitignore_global"
                ((patterns_added++)) || true
            fi

            if ! git config --global core.excludesfile "$gitignore_global" 2>/dev/null; then
                print_error "git設定の更新に失敗しました"
                return 1
            fi

            if [[ $patterns_added -gt 0 ]]; then
                print_success "グローバルgitignoreにCLAUDE.mdと.claude/を追加しました"
            else
                print_info "グローバルgitignoreは既に設定済みです"
            fi
            print_success "core.excludesfileを設定しました: $gitignore_global"
            ;;
        *)
            print_info "仕事用環境の設定をスキップしました"
            ;;
    esac
}

# ============================================================================
# .profile読み込み設定
# ============================================================================

setup_profile_source() {
    print_header ".profile読み込み設定"
    echo ""

    # シェル設定ファイルを検出
    local shell_rc=""
    local shell_name=""

    if [[ -n "$ZSH_VERSION" ]] || [[ "$SHELL" == *"zsh"* ]]; then
        shell_name="zsh"
        # preztoの場合は.zpreztorc、通常は.zshrc
        if [[ -f "$HOME/.zpreztorc" ]]; then
            shell_rc="$HOME/.zshrc"
            print_info "prezto環境を検出しました"
        else
            shell_rc="$HOME/.zshrc"
        fi
    elif [[ -n "$BASH_VERSION" ]] || [[ "$SHELL" == *"bash"* ]]; then
        shell_name="bash"
        shell_rc="$HOME/.bashrc"
    fi

    if [[ -z "$shell_rc" ]]; then
        print_info "シェル設定ファイルを検出できませんでした"
        print_info "手動で追加してください: [[ -f ~/.profile ]] && source ~/.profile"
        return 0
    fi

    # 既に追加済みか確認
    if [[ -f "$shell_rc" ]] && grep -q "source ~/.profile\|source \"\$HOME/.profile\"" "$shell_rc" 2>/dev/null; then
        print_info "既に設定済み: $shell_rc"
        return 0
    fi

    printf "~/.profileの読み込みを %s に追加しますか? [y/N]: " "$shell_rc"
    read -r add_source

    case "$add_source" in
        y|Y)
            if $MODE_DRY_RUN; then
                print_info "[ドライラン] 追加: $shell_rc"
                return 0
            fi

            # バックアップ
            if [[ -f "$shell_rc" ]]; then
                cp "$shell_rc" "${shell_rc}.bak.$(date +%Y%m%d%H%M%S)"
            fi

            # 追加
            {
                echo ""
                echo "# dotfiles共通設定"
                echo '[[ -f ~/.profile ]] && source ~/.profile'
            } >> "$shell_rc"

            print_success "追加しました: $shell_rc"
            print_info "反映するには: source $shell_rc"
            ;;
        *)
            print_info "スキップしました"
            print_info "手動で追加: [[ -f ~/.profile ]] && source ~/.profile"
            ;;
    esac
}

# ============================================================================
# メイン処理
# ============================================================================

# ファイルインストール
install_files() {
    print_header "dotfilesをインストール: $DOTFILES_DIR"

    for idx in "${SELECTED_INDICES[@]}"; do
        local src dest
        src=$(get_dotfile_field "$idx" source)
        dest=$(get_dotfile_field "$idx" dest)
        create_link "$src" "$dest"
    done

    # .gitconfigのインストール
    install_gitconfig

    if $CLAUDE_SELECTED; then
        install_claude_config
    fi
}

# ファイルアンインストール
uninstall_files() {
    print_header "dotfilesをアンインストール"

    for ((i = 0; i < DOTFILE_COUNT; i++)); do
        local src dest
        src=$(get_dotfile_field "$i" source)
        dest=$(get_dotfile_field "$i" dest)
        remove_link "$src" "$dest"
    done

    # .gitconfigの削除 (work/private両方を試行)
    remove_link ".gitconfig.work" "${HOME}/.gitconfig"
    remove_link ".gitconfig.private" "${HOME}/.gitconfig"

    uninstall_claude_config
}

# サマリー表示
show_summary() {
    print_header "結果"
    echo ""

    if $MODE_UNINSTALL; then
        printf "  削除: ${COLOR_GREEN}%d${COLOR_RESET}\n" "$COUNT_REMOVED"
    else
        printf "  作成: ${COLOR_GREEN}%d${COLOR_RESET}\n" "$COUNT_CREATED"
        printf "  バックアップ: ${COLOR_YELLOW}%d${COLOR_RESET}\n" "$COUNT_BACKUP"
    fi
    printf "  スキップ: ${COLOR_YELLOW}%d${COLOR_RESET}\n" "$COUNT_SKIPPED"

    if [[ $COUNT_ERROR -gt 0 ]]; then
        printf "  エラー: ${COLOR_RED}%d${COLOR_RESET}\n" "$COUNT_ERROR"
    fi
    echo ""

}

# ヘルプ表示
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
    shell   シェル設定(.profile, .shell_aliases)
    git     Git設定(.gitconfig.work/private, .git-completion.bash等)
    vim     Vim設定(.vimrc)
    claude  Claude Code設定(claude-config/から)

シェル設定:
    .profileは共通シェル設定ファイルです。PATH、環境変数、エイリアス読み込みを含みます。
    prezto/oh-my-posh等のシェル設定から以下を追加して読み込んでください:
      [[ -f ~/.profile ]] && source ~/.profile

.gitconfig:
    仕事用(.gitconfig.work)とプライベート用(.gitconfig.private)を選択できます。
    強制モードではOS検出で自動選択(macOS=private, Linux=work)。

例:
    ./install.sh              # 対話的にインストール
    ./install.sh -f           # すべてインストール
    ./install.sh -n           # インストール内容をプレビュー
    ./install.sh -u           # すべてのシンボリックリンクを削除
    ./install.sh -n -u        # アンインストール内容をプレビュー

Claude設定:
    claude-config/内のファイルは 'git ls-files' で自動検出されます。
    - claude-config/CLAUDE.md -> ~/.claude/CLAUDE.md
    - claude-config/settings.json -> ~/.claude/settings.json
    - claude-config/skills/*/SKILL.md -> ~/.claude/skills/*/SKILL.md
    新しいClaude設定ファイルを追加するには、claude-config/に追加して
    gitにコミットしてください。

仕事用環境:
    対話モードでは、仕事用環境かどうか確認されます。
    「はい」の場合、CLAUDE.mdと.claude/が~/.gitignore_globalに追加され、
    gitがこのファイルを使用するよう設定されます(core.excludesfile)。
    これにより、仕事用リポジトリでClaude設定ファイルが追跡されなくなります。

必要条件:
    bash 4.0以上が必要です。
    macOSの場合: brew install bash && /opt/homebrew/bin/bash ./install.sh
EOF
}

# 引数解析
parse_args() {
    while [[ $# -gt 0 ]]; do
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

# シグナルハンドラ
cleanup() {
    echo ""
    print_info "中断されました"
    exit 130
}

# メイン関数
main() {
    # シグナルトラップ設定
    trap cleanup SIGINT SIGTERM

    # 引数解析
    parse_args "$@"

    # 必須コマンド確認
    check_requirements

    if $MODE_DRY_RUN; then
        print_header "ドライランモード - 変更は行われません"
    fi

    if $MODE_UNINSTALL; then
        if $MODE_INTERACTIVE && ! $MODE_DRY_RUN; then
            printf "すべてのdotfilesシンボリックリンクを削除しますか? [y/N]: "
            read -r confirm
            case "$confirm" in
                y|Y) ;;
                *) echo "キャンセルしました。"; exit 0 ;;
            esac
        fi
        uninstall_files
    else
        if $MODE_INTERACTIVE; then
            select_files_interactive
            confirm_installation
        else
            # 強制モード: すべて選択
            for ((i = 0; i < DOTFILE_COUNT; i++)); do
                SELECTED_INDICES+=("$i")
            done
            CLAUDE_SELECTED=true
            # 環境自動検出: macOS=private, Linux=work
            if [[ "$(uname)" == "Darwin" ]]; then
                GITCONFIG_VARIANT="private"
            else
                GITCONFIG_VARIANT="work"
            fi
            print_info ".gitconfig: ${GITCONFIG_VARIANT} を自動選択しました"
        fi
        install_files

        if $MODE_INTERACTIVE; then
            setup_profile_source
            setup_work_environment
        fi
    fi

    show_summary

    # エラーがあった場合は終了コード1
    [[ $COUNT_ERROR -gt 0 ]] && exit 1
    exit 0
}

# エントリポイント
main "$@"
