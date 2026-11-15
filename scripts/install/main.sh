# shellcheck shell=sh

check_requirements() {
    for cmd in git python3 ln mkdir rm mv cp cmp; do
        command -v "$cmd" >/dev/null 2>&1 || die "必須コマンドが見つかりません: $cmd"
    done
}

install_files() {
    print_header "dotfilesをインストール: $DOTFILES_DIR"

    install_shell_config

    if [ "$GIT_SELECTED" = "true" ]; then
        install_git_files
        install_gitconfig
        install_gitignore
    fi

    [ "$VIM_SELECTED" = "true" ] && install_vim_files

    install_bin_files
    install_claude_config
    install_codex_config
}

uninstall_files() {
    print_header "dotfilesをアンインストール"

    [ "$UNINSTALL_SHELL" = "true" ] && uninstall_shell_config
    if [ "$UNINSTALL_GIT" = "true" ]; then
        uninstall_git_files
        uninstall_gitconfig
        uninstall_gitignore
    fi
    [ "$UNINSTALL_VIM" = "true" ]    && uninstall_vim_files
    [ "$UNINSTALL_BIN" = "true" ]    && uninstall_bin_files
    [ "$UNINSTALL_CLAUDE" = "true" ] && uninstall_claude_config
    [ "$UNINSTALL_CODEX" = "true" ]  && uninstall_codex_config
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            -h| --help)        show_help; exit 0 ;;
            -i| --interactive) MODE_INTERACTIVE=true; shift ;;
            -f| --force)       MODE_INTERACTIVE=false; shift ;;
            -n| --dry-run)     MODE_DRY_RUN=true; shift ;;
            -u| --uninstall)   MODE_UNINSTALL=true; shift ;;
            *)                die "不明なオプション: $1\nヘルプは -h で表示" ;;
        esac
    done
}

# shellcheck disable=SC2329 # invoked by the INT and TERM traps in main
cleanup() {
    echo ""
    print_info "中断されました"
    exit 130
}

main() {
    trap cleanup INT TERM

    parse_args "$@"
    check_requirements

    [ "$MODE_DRY_RUN" = "true" ] && print_header "ドライランモード - 変更は行われません"

    if [ "$MODE_UNINSTALL" = "true" ]; then
        _run_uninstall_mode
    else
        _run_install_mode
    fi

    _finalize
}

_run_install_mode() {
    if [ "$MODE_INTERACTIVE" = "true" ]; then
        select_files_interactive
        confirm_installation
    else
        _apply_force_mode_defaults
    fi
    generate_ai_assets
    install_files
}

_run_uninstall_mode() {
    if [ "$MODE_INTERACTIVE" = "true" ]; then
        select_uninstall_components
        _confirm_uninstall_unless_dry_run
    else
        _select_all_uninstall_components
    fi
    uninstall_files
}

_apply_force_mode_defaults() {
    SHELL_SELECTED=true
    SHELL_TYPE=$(detect_current_shell)
    SHELL_COMPONENTS="full"
    GIT_SELECTED=true
    VIM_SELECTED=true
    BIN_SELECTED=true
    CLAUDE_SELECTED=true
    CODEX_SELECTED=true

    case "$(detect_platform)" in
        macos) GITCONFIG_VARIANT="private" ;;
        *)     GITCONFIG_VARIANT="work" ;;
    esac

    print_info ".gitconfig: ${GITCONFIG_VARIANT} を自動選択しました"
    print_info "シェル設定: ${SHELL_TYPE} を自動選択しました"
}

_select_all_uninstall_components() {
    UNINSTALL_SHELL=true
    UNINSTALL_GIT=true
    UNINSTALL_VIM=true
    UNINSTALL_BIN=true
    UNINSTALL_CLAUDE=true
    UNINSTALL_CODEX=true
}

_confirm_uninstall_unless_dry_run() {
    [ "$MODE_DRY_RUN" = "true" ] && return 0

    printf "\nアンインストールを実行しますか? [y/N]: "
    read -r _confirm
    case "$_confirm" in
        y|Y) ;;
        *) echo "キャンセルしました。"; exit 0 ;;
    esac
}

_finalize() {
    show_summary
    [ "$COUNT_ERROR" -gt 0 ] && exit 1
    exit 0
}
