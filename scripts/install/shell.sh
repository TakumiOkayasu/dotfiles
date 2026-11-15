# shellcheck shell=sh

detect_current_shell() {
    case "${SHELL:-}" in
        */bash) echo "bash" ;;
        */zsh)  echo "zsh" ;;
        *)      echo "bash" ;;
    esac
}

get_shell_rc_display() {
    case "$1" in
        bash) echo "$HOME/.bashrc" ;;
        zsh)  echo "$HOME/.zshrc" ;;
        all)  echo "$HOME/.bashrc, $HOME/.zshrc" ;;
        *)    echo "$HOME/.bashrc" ;;
    esac
}

install_shell_config() {
    [ "$SHELL_SELECTED" != "true" ] && return 0
    print_header "シェル設定をインストール"

    case "$SHELL_COMPONENTS" in
        full)   install_shell_full ;;
        append) install_shell_append ;;
    esac
}

install_shell_full() {
    apply_link_package shell "$HOME" install shell_link_specs "$SHELL_TYPE"
}

shell_link_specs() {
    case "$1" in
        bash|all)
            emit_link_spec config/shell/bash/bashrc .bashrc || return 1
            emit_link_spec config/shell/bash/bash_profile .bash_profile || return 1
            ;;
    esac
    case "$1" in
        zsh|all)
            emit_link_spec config/shell/zsh/zshrc .zshrc || return 1
            emit_link_spec config/shell/zsh/zprofile .zprofile || return 1
            emit_link_spec config/shell/zsh/macos.zprofile .zsh/macos.zprofile || return 1
            ;;
    esac
    return 0
}

# 追記モード共通実装。シェル固有の source 行構文だけ引数で受ける
_inject_source_with_line() {
    _target_rc="$1"
    _source_line="$2"

    [ -f "$_target_rc" ] || { print_skip "スキップ: $_target_rc (ファイルが存在しません)"; return 0; }

    if grep -qF "$DOTWORK_MARKER_BEGIN" "$_target_rc" 2>/dev/null; then
        print_skip "スキップ: $_target_rc (source行は挿入済み)"
        COUNT_SKIPPED=$((COUNT_SKIPPED + 1))
        return 0
    fi

    if [ "$MODE_DRY_RUN" = "true" ]; then
        print_info "[ドライラン] source行を挿入: $_target_rc"
        COUNT_CREATED=$((COUNT_CREATED + 1))
        return 0
    fi

    _ensure_trailing_newline "$_target_rc" || return $?

    cat >> "$_target_rc" << EOF || return $?

$DOTWORK_MARKER_BEGIN
$_source_line
$DOTWORK_MARKER_END
EOF

    print_success "source行を挿入: $_target_rc"
    COUNT_CREATED=$((COUNT_CREATED + 1))
}

_ensure_trailing_newline() {
    _file="$1"
    [ -s "$_file" ] || return 0
    _tail=$(tail -c 1 "$_file" 2>/dev/null | wc -l)
    if [ "$_tail" -eq 0 ]; then
        printf '\n' >> "$_file"
    fi
}

inject_source_block() {
    # shellcheck disable=SC2016 # write the literal source command into the rc file
    _inject_source_with_line "$1" '[ -f "$HOME/.shell_common" ] && . "$HOME/.shell_common"'
}

remove_source_block() {
    _target_rc="$1"
    [ -f "$_target_rc" ] || return 0
    grep -qF "$DOTWORK_MARKER_BEGIN" "$_target_rc" 2>/dev/null || return 0

    if [ "$MODE_DRY_RUN" = "true" ]; then
        print_info "[ドライラン] source行を削除: $_target_rc"
        return 0
    fi

    _tmp="${_target_rc}.dotwork_tmp"
    _in_block=false
    while IFS= read -r _line || [ -n "$_line" ]; do
        case "$_line" in
            *"$DOTWORK_MARKER_BEGIN"*) _in_block=true;  continue ;;
            *"$DOTWORK_MARKER_END"*)   _in_block=false; continue ;;
        esac
        [ "$_in_block" = "false" ] && printf '%s\n' "$_line"
    done < "$_target_rc" > "$_tmp"

    mv "$_tmp" "$_target_rc"

    print_success "source行を削除: $_target_rc"
    COUNT_REMOVED=$((COUNT_REMOVED + 1))
}

install_shell_append() {
    apply_link_package shell-common "$HOME" install emit_link_spec config/shell/common.sh .shell_common || return $?

    case "$SHELL_TYPE" in
        bash) inject_source_block "${HOME}/.bashrc" || return $? ;;
        zsh)  inject_source_block "${HOME}/.zshrc" || return $? ;;
        all)
            inject_source_block "${HOME}/.bashrc" || return $?
            inject_source_block "${HOME}/.zshrc" || return $?
            ;;
    esac

    print_info "追記モードのrcファイルはGit管理外です。共通設定の追記先: ${DOTFILES_DIR}/config/shell/common.sh"
}

uninstall_shell_config() {
    print_header "シェル設定をアンインストール"

    apply_link_package shell "$HOME" uninstall shell_link_specs all || return $?
    apply_link_package shell-common "$HOME" uninstall emit_link_spec config/shell/common.sh .shell_common || return $?

    remove_link "config/shell/bash/bashrc"       "${HOME}/.bashrc" || return $?
    remove_link "config/shell/bash/bash_profile" "${HOME}/.bash_profile" || return $?
    remove_link "config/shell/zsh/zshrc"         "${HOME}/.zshrc" || return $?
    remove_link "config/shell/zsh/zprofile"      "${HOME}/.zprofile" || return $?
    remove_link "config/shell/zsh/macos.zprofile" "${HOME}/.zsh/macos.zprofile" || return $?
    remove_link "config/shell/fish/config.fish"  "${HOME}/.config/fish/config.fish" || return $?

    remove_link "config/shell/common.sh"         "${HOME}/.shell_common" || return $?
    remove_source_block "${HOME}/.bashrc" || return $?
    remove_source_block "${HOME}/.zshrc" || return $?
    remove_source_block "${HOME}/.config/fish/config.fish" || return $?
}
