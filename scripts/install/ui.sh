# shellcheck shell=sh

die() {
    printf "${COLOR_RED}エラー:${COLOR_RESET} %s\n" "$1" >&2
    exit "${2:-1}"
}

print_success() { printf "${COLOR_GREEN}✓${COLOR_RESET} %s\n" "$1"; }

print_skip()    { printf "${COLOR_YELLOW}○${COLOR_RESET} %s\n" "$1"; }

print_error()   { printf "${COLOR_RED}✗${COLOR_RESET} %s\n" "$1"; }

print_info()    { printf "${COLOR_BLUE}→${COLOR_RESET} %s\n" "$1"; }

print_header()  { printf "\n${COLOR_BOLD}${COLOR_CYAN}%s${COLOR_RESET}\n" "$1"; }

select_shell_type() {
    [ -n "$SHELL_TYPE" ] && return 0

    _current_shell=$(detect_current_shell)

    echo ""
    printf '%sシェル設定を選択:%s\n' "$COLOR_BOLD" "$COLOR_RESET"
    printf '  %s1)%s bash のみ\n' "$COLOR_BOLD" "$COLOR_RESET"
    printf '  %s2)%s zsh のみ\n' "$COLOR_BOLD" "$COLOR_RESET"
    printf '  %s3)%s すべて (bash + zsh)\n' "$COLOR_BOLD" "$COLOR_RESET"
    printf '  %s4)%s 現在のシェル (%s) のみ\n' "$COLOR_BOLD" "$COLOR_RESET" "$_current_shell"
    echo ""
    printf "選択 (1-4) [4]: "
    read -r _choice

    case "$_choice" in
        1)    SHELL_TYPE="bash" ;;
        2)    SHELL_TYPE="zsh" ;;
        3)    SHELL_TYPE="all" ;;
        4|"") SHELL_TYPE="$_current_shell" ;;
        *)
            print_error "無効な選択です。現在のシェルを使用します"
            SHELL_TYPE="$_current_shell"
            ;;
    esac

    print_success "シェル設定: ${SHELL_TYPE}"
}

select_shell_components() {
    echo ""
    printf '%sインストールする内容を選択:%s\n' "$COLOR_BOLD" "$COLOR_RESET"
    _shell_rc=$(get_shell_rc_display "$SHELL_TYPE")
    printf '  %s1)%s フルセット (既存設定を置き換え) %s⚠ 破壊的%s\n' "$COLOR_BOLD" "$COLOR_RESET" "$COLOR_RED" "$COLOR_RESET"
    printf "     → %s 等をリポジトリのものに置換 (既存は .bak にバックアップ)\n" "$_shell_rc"
    printf '  %s2)%s 追記モード (既存設定を保持) %s★推奨%s\n' "$COLOR_BOLD" "$COLOR_RESET" "$COLOR_GREEN" "$COLOR_RESET"
    printf "     → 既存の %s にsource行を自動挿入\n" "$_shell_rc"
    echo ""
    printf "選択 (1-2) [2]: "
    read -r _choice

    case "$_choice" in
        1)    SHELL_COMPONENTS="full";   print_success "フルセットを選択しました" ;;
        2|"") SHELL_COMPONENTS="append"; print_success "追記モードを選択しました" ;;
        *)
            print_error "無効な選択です。追記モードを使用します"
            SHELL_COMPONENTS="append"
            ;;
    esac
}

select_gitconfig_variant() {
    [ -n "$GITCONFIG_VARIANT" ] && return 0

    echo ""
    printf '%s.gitconfigの環境を選択:%s\n' "$COLOR_BOLD" "$COLOR_RESET"
    printf '  %s1)%s プライベート用 (macOS: /Users/...)\n' "$COLOR_BOLD" "$COLOR_RESET"
    printf '  %s2)%s 仕事用 (Linux: /home/...)\n' "$COLOR_BOLD" "$COLOR_RESET"
    echo ""
    printf "選択 (1/2): "
    read -r _choice

    case "$_choice" in
        1) GITCONFIG_VARIANT="private" ;;
        2) GITCONFIG_VARIANT="work" ;;
        *)
            print_error "無効な選択です。プライベート用を使用します"
            GITCONFIG_VARIANT="private"
            ;;
    esac

    print_success ".gitconfig: ${GITCONFIG_VARIANT} を選択しました"
}

select_uninstall_components() {
    echo ""
    printf '%sアンインストールするカテゴリを選択 (複数可、スペース区切り):%s\n' "$COLOR_BOLD" "$COLOR_RESET"
    printf '  %s1)%s シェル設定\n' "$COLOR_BOLD" "$COLOR_RESET"
    printf '  %s2)%s Git設定\n' "$COLOR_BOLD" "$COLOR_RESET"
    printf '  %s3)%s Vim設定\n' "$COLOR_BOLD" "$COLOR_RESET"
    printf '  %s4)%s CLIツール\n' "$COLOR_BOLD" "$COLOR_RESET"
    printf '  %s5)%s Claude Code設定\n' "$COLOR_BOLD" "$COLOR_RESET"
    printf '  %s6)%s Codex設定\n' "$COLOR_BOLD" "$COLOR_RESET"
    printf '  %sa)%s すべて\n' "$COLOR_BOLD" "$COLOR_RESET"
    echo ""
    printf "選択 (例: 1 3 / a) [a]: "
    read -r _choices

    case "$_choices" in
        a|A|"")
            UNINSTALL_SHELL=true
            UNINSTALL_GIT=true
            UNINSTALL_VIM=true
            UNINSTALL_BIN=true
            UNINSTALL_CLAUDE=true
            UNINSTALL_CODEX=true
            ;;
        *)
            for _c in $_choices; do
                case "$_c" in
                    1) UNINSTALL_SHELL=true ;;
                    2) UNINSTALL_GIT=true ;;
                    3) UNINSTALL_VIM=true ;;
                    4) UNINSTALL_BIN=true ;;
                    5) UNINSTALL_CLAUDE=true ;;
                    6) UNINSTALL_CODEX=true ;;
                    *) print_error "無効な選択をスキップ: $_c" ;;
                esac
            done
            ;;
    esac

    _selected=""
    [ "$UNINSTALL_SHELL" = "true" ]  && _selected="${_selected}シェル "
    [ "$UNINSTALL_GIT" = "true" ]    && _selected="${_selected}Git "
    [ "$UNINSTALL_VIM" = "true" ]    && _selected="${_selected}Vim "
    [ "$UNINSTALL_BIN" = "true" ]    && _selected="${_selected}CLIツール "
    [ "$UNINSTALL_CLAUDE" = "true" ] && _selected="${_selected}Claude "
    [ "$UNINSTALL_CODEX" = "true" ]  && _selected="${_selected}Codex "

    [ -z "$_selected" ] && die "カテゴリが選択されていません"

    print_success "アンインストール対象: ${_selected}"
}

show_category_menu() {
    print_header "インストールするカテゴリを選択"
    echo ""
    printf '  %s1)%s シェル設定\n' "$COLOR_BOLD" "$COLOR_RESET"
    printf "     PATH, エイリアス, プロンプト, SSH Agent を設定\n"
    printf '  %s2)%s Git設定\n' "$COLOR_BOLD" "$COLOR_RESET"
    printf "     gitconfig, 補完, gitignore を設定\n"
    printf '  %s3)%s Vim設定\n' "$COLOR_BOLD" "$COLOR_RESET"
    printf "     .vimrc を配置\n"
    printf '  %s4)%s CLIツール\n' "$COLOR_BOLD" "$COLOR_RESET"
    printf "     git-new-feature 等を ~/.local/bin/ に配置\n"
    printf '  %s5)%s Claude Code設定\n' "$COLOR_BOLD" "$COLOR_RESET"
    printf "     hooks, skills, rules, commands を %s/ に配置\n" "$CLAUDE_CONFIG_ROOT"
    printf '  %s6)%s Codex設定\n' "$COLOR_BOLD" "$COLOR_RESET"
    printf "     agents, inline hooks template, rules を %s/ に配置 (skills は plugin 配布)\n" "$CODEX_CONFIG_ROOT"
    echo ""
    printf '  %sa)%s すべて  %sq)%s 終了\n' "$COLOR_BOLD" "$COLOR_RESET" "$COLOR_BOLD" "$COLOR_RESET"
    echo ""
}

select_files_interactive() {
    while true; do
        show_category_menu
        printf "カテゴリを選択 (1-6/a/q): "
        read -r _choice

        case "$_choice" in
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

        if [ "$SHELL_SELECTED" = "true" ] && [ "$GIT_SELECTED" = "true" ] && [ "$VIM_SELECTED" = "true" ] && [ "$BIN_SELECTED" = "true" ] && [ "$CLAUDE_SELECTED" = "true" ] && [ "$CODEX_SELECTED" = "true" ]; then
            print_success "全カテゴリが選択されました"
            return
        fi

        printf "\n選択を続けますか? [Y/n]: "
        read -r _cont
        case "$_cont" in
            n|N) return ;;
        esac
    done
}

confirm_installation() {
    _validate_selection || die "ファイルが選択されていません"

    print_header "インストールするファイル"
    echo ""

    [ "$SHELL_SELECTED" = "true" ]  && _preview_shell
    [ "$GIT_SELECTED" = "true" ]    && _preview_git
    [ "$VIM_SELECTED" = "true" ]    && _preview_vim
    [ "$BIN_SELECTED" = "true" ]    && _preview_bin
    [ "$CLAUDE_SELECTED" = "true" ] && _preview_claude
    [ "$CODEX_SELECTED" = "true" ]  && _preview_codex

    _prompt_user_consent
}

_validate_selection() {
    [ "$SHELL_SELECTED" = "true" ] || [ "$GIT_SELECTED" = "true" ] || [ "$VIM_SELECTED" = "true" ] \
        || [ "$BIN_SELECTED" = "true" ] || [ "$CLAUDE_SELECTED" = "true" ] || [ "$CODEX_SELECTED" = "true" ]
}

_preview_shell() {
    case "$SHELL_COMPONENTS" in
        full)
            printf '  %sシェル設定 - フルセット (%s):%s\n' "$COLOR_CYAN" "$SHELL_TYPE" "$COLOR_RESET"
            case "$SHELL_TYPE" in
                bash)
                    printf "    + config/shell/bash/bashrc -> ~/.bashrc\n"
                    printf "    + config/shell/bash/bash_profile -> ~/.bash_profile\n"
                    ;;
                zsh)
                    printf "    + config/shell/zsh/zshrc -> ~/.zshrc\n"
                    printf "    + config/shell/zsh/zprofile -> ~/.zprofile\n"
                    printf "    + config/shell/zsh/macos.zprofile -> ~/.zsh/macos.zprofile\n"
                    ;;
                all)
                    printf "    + config/shell/bash/bashrc -> ~/.bashrc\n"
                    printf "    + config/shell/bash/bash_profile -> ~/.bash_profile\n"
                    printf "    + config/shell/zsh/zshrc -> ~/.zshrc\n"
                    printf "    + config/shell/zsh/zprofile -> ~/.zprofile\n"
                    printf "    + config/shell/zsh/macos.zprofile -> ~/.zsh/macos.zprofile\n"
                    ;;
            esac
            ;;
        append)
            printf '  %sシェル設定 - 追記モード (%s):%s\n' "$COLOR_CYAN" "$SHELL_TYPE" "$COLOR_RESET"
            printf "    + config/shell/common.sh -> ~/.shell_common\n"
            case "$SHELL_TYPE" in
                bash) printf "    → ~/.bashrc にsource行を自動挿入\n" ;;
                zsh)  printf "    → ~/.zshrc にsource行を自動挿入\n" ;;
                all)  printf "    → ~/.bashrc, ~/.zshrc にsource行を自動挿入\n" ;;
            esac
            ;;
    esac
    echo ""
}

_preview_git() {
    printf '  %sGit設定:%s\n' "$COLOR_CYAN" "$COLOR_RESET"
    printf "    + config/git/.git-completion.bash -> ~/.git-completion.bash\n"
    printf "    + config/git/.git-prompt.sh -> ~/.git-prompt.sh\n"
    printf "    + config/git/.gitattributes -> ~/.config/git/attributes\n"
    if [ -n "$GITCONFIG_VARIANT" ]; then
        printf "    + config/git/.gitconfig.common + .gitconfig.%s -> ~/.gitconfig\n" "$GITCONFIG_VARIANT"
        printf "    + config/git/.gitignore.common + .gitignore.%s -> ~/.config/git/ignore\n" "$GITCONFIG_VARIANT"
    fi
    echo ""
}

_preview_vim() {
    printf '  %sVim設定:%s\n' "$COLOR_CYAN" "$COLOR_RESET"
    printf "    + config/vim/.vimrc -> ~/.vimrc\n"
    echo ""
}

_preview_bin() {
    printf '  %sCLIツール:%s\n' "$COLOR_CYAN" "$COLOR_RESET"
    printf "    + bin/* -> ~/.local/bin/*\n"
    echo ""
}

_preview_claude() {
    printf '  %sClaude Code設定:%s\n' "$COLOR_CYAN" "$COLOR_RESET"
    printf "    + trackedな claude/* と common/* -> 生成・検証 -> %s/*\n" "$CLAUDE_CONFIG_ROOT"
    echo ""
}

_preview_codex() {
    printf '  %sCodex設定:%s\n' "$COLOR_CYAN" "$COLOR_RESET"
    printf "    + trackedな codex/* と common/* -> 生成・検証 -> %s/*\n" "$CODEX_CONFIG_ROOT"
    printf "    + plugin bundle -> %s/plugins, ~/.agents/plugins/marketplace.json\n" "$CODEX_CONFIG_ROOT"
    printf "    + codex/config.toml.template -> %s/config.toml (存在しない場合のみ生成)\n" "$CODEX_CONFIG_ROOT"
    printf "    + codex/*.config.toml -> %s/*.config.toml (profile)\n" "$CODEX_CONFIG_ROOT"
    printf "    - codex/skills/* は plugin 配布のため install 対象外\n"
    printf "    - codex/hooks.json は作成しない (hooks は config.toml inline TOML)\n"
    echo ""
}

_prompt_user_consent() {
    printf "インストールを実行しますか? [Y/n]: "
    read -r _confirm
    case "$_confirm" in
        n|N) echo "キャンセルしました。"; exit 0 ;;
    esac
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

    [ "$COUNT_ERROR" -gt 0 ] && printf "  エラー: ${COLOR_RED}%d${COLOR_RESET}\n" "$COUNT_ERROR"
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
    shell   シェル設定 (bash/zsh 選択可能)
    git     Git設定(.gitconfig.work/private, .git-completion.bash等)
    vim     Vim設定(.vimrc)
    bin     CLIツール (git-new-feature等 → ~/.local/bin/)
    claude  Claude Code設定 (claude/, global_* prefix と statusline.settings.json は配置名を変換)
    codex   Codex設定 (codex/)

例:
    ./install.sh              # 対話的にインストール
    ./install.sh -f           # すべてインストール(現在のシェルのみ)
    ./install.sh -n           # インストール内容をプレビュー
    ./install.sh -u           # このリポジトリが管理するシンボリックリンクを削除
EOF
}
