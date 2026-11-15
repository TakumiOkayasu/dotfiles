# shellcheck shell=sh

install_git_files() {
    cleanup_legacy_git_artifacts

    new_stow_specs_file
    _spec_file="$_stow_specs_file"
    stow_specs_add "$_spec_file" "config/git/.git-completion.bash" ".git-completion.bash"
    stow_specs_add "$_spec_file" "config/git/.git-prompt.sh" ".git-prompt.sh"
    stow_specs_add "$_spec_file" "config/git/.git-prompt.sh" ".config/git/.git-prompt.sh"
    stow_specs_add "$_spec_file" "config/git/.gitattributes" ".config/git/attributes"
    install_stow_specs_file "git" "$_spec_file"
}

uninstall_git_files() {
    cleanup_legacy_git_artifacts

    new_stow_specs_file
    _spec_file="$_stow_specs_file"
    stow_specs_add "$_spec_file" "config/git/.git-completion.bash" ".git-completion.bash"
    stow_specs_add "$_spec_file" "config/git/.git-prompt.sh" ".git-prompt.sh"
    stow_specs_add "$_spec_file" "config/git/.git-prompt.sh" ".config/git/.git-prompt.sh"
    stow_specs_add "$_spec_file" "config/git/.gitattributes" ".config/git/attributes"
    uninstall_stow_specs_file "git" "$_spec_file"

    remove_link "config/git/.git-completion.bash" "${HOME}/.git-completion.bash"
    remove_link "config/git/.git-prompt.sh"        "${HOME}/.git-prompt.sh"
    remove_link "config/git/.git-prompt.sh"        "${HOME}/.config/git/.git-prompt.sh"
    remove_link "config/git/.gitattributes"        "${HOME}/.config/git/attributes"
}

cleanup_legacy_git_artifacts() {
    remove_dotfiles_link "${HOME}/.gitignore_global"        "旧gitignore_globalリンク"
    remove_dotfiles_link "${HOME}/.gitignore.common"        "旧gitignore.commonリンク"
    remove_dotfiles_link "${HOME}/.config/git/.gitattributes" "旧gitattributesリンク (ドット付き)"

    _legacy_ignore="${HOME}/.gitignore"
    if is_dotfiles_link "$_legacy_ignore"; then
        remove_dotfiles_link "$_legacy_ignore" "旧gitignoreリンク"
    elif [ -f "$_legacy_ignore" ]; then
        print_info "残骸の可能性: ${_legacy_ignore} (旧 excludesfile 実体)。不要なら手動削除してください"
    fi
}

install_gitignore() {
    [ -z "$GITCONFIG_VARIANT" ] && return 0
    _install_merged_file \
        "${DOTFILES_DIR}/config/git/.gitignore.common" \
        "${DOTFILES_DIR}/config/git/.gitignore.${GITCONFIG_VARIANT}" \
        "${HOME}/.config/git/ignore"
}

_install_merged_file() {
    _base="$1"
    _variant="$2"
    _target="$3"

    if [ "$MODE_DRY_RUN" = "true" ]; then
        printf "%s[DRY-RUN]%s Would create: %s (base + %s)\n" "$COLOR_YELLOW" "$COLOR_RESET" "$_target" "$GITCONFIG_VARIANT"
        return 0
    fi

    _merged_validate_variant "$_variant" || return 1
    ensure_dir "$(dirname "$_target")" || return 1
    _merged_target_matches "$_base" "$_variant" "$_target" && return 0
    _merged_backup_existing "$_target"
    _merged_write "$_base" "$_variant" "$_target"
}

_merged_validate_variant() {
    [ -f "$1" ] && return 0
    printf "%s[ERROR]%s variant not found: %s\n" "$COLOR_RED" "$COLOR_RESET" "$1"
    return 1
}

_merged_target_matches() {
    _base="$1"
    _variant="$2"
    _target="$3"

    [ -f "$_target" ] && [ ! -L "$_target" ] || return 1

    _merged=$(mktemp)
    _TMPFILES="$_TMPFILES $_merged"
    cat "$_base" "$_variant" > "$_merged"
    cmp -s "$_merged" "$_target"
}

_merged_backup_existing() {
    _target="$1"
    [ -f "$_target" ] || [ -L "$_target" ] || return 0

    if [ -L "$_target" ]; then
        rm "$_target"
    else
        _backup=$(next_backup_path "$_target")
        mv "$_target" "$_backup"
        printf "%s[BACKUP]%s %s -> %s\n" "$COLOR_YELLOW" "$COLOR_RESET" "$_target" "$_backup"
    fi
}

_merged_write() {
    cat "$1" "$2" > "$3"
    printf "%s[CREATE]%s %s (base + %s)\n" "$COLOR_GREEN" "$COLOR_RESET" "$3" "$GITCONFIG_VARIANT"
}

remove_legacy_gitconfig_common() {
    _target="${HOME}/.gitconfig.common"
    if [ -f "$_target" ] && [ ! -L "$_target" ] \
        && cmp -s "${DOTFILES_DIR}/config/git/.gitconfig.common" "$_target"; then
        rm "$_target"
        printf "%s[REMOVE]%s %s (旧gitconfig.commonコピー)\n" "$COLOR_RED" "$COLOR_RESET" "$_target"
    elif [ -e "$_target" ] || [ -L "$_target" ]; then
        remove_dotfiles_link "$_target" "旧gitconfig.commonリンク"
        [ -f "$_target" ] && print_info "残骸の可能性: ${_target} (現在は参照されない)。不要なら手動削除してください"
    fi
    return 0
}

uninstall_gitconfig_common() {
    _target="${HOME}/.gitconfig.common"
    _source="${DOTFILES_DIR}/config/git/.gitconfig.common"

    if [ -f "$_target" ] && [ ! -L "$_target" ] && cmp -s "$_source" "$_target"; then
        rm "$_target"
        printf "%s[REMOVE]%s %s\n" "$COLOR_RED" "$COLOR_RESET" "$_target"
    else
        remove_link "config/git/.gitconfig.common" "$_target"
    fi

    if [ -f "${_target}.bak" ]; then
        mv "${_target}.bak" "$_target"
        printf "%s[RESTORE]%s %s.bak -> %s\n" "$COLOR_GREEN" "$COLOR_RESET" "$_target" "$_target"
    fi
}

uninstall_gitignore() {
    _target="${HOME}/.config/git/ignore"

    if [ -f "$_target" ]; then
        rm "$_target"
        printf "%s[REMOVE]%s %s\n" "$COLOR_RED" "$COLOR_RESET" "$_target"
    fi

    if [ -f "${_target}.bak" ]; then
        mv "${_target}.bak" "$_target"
        printf "%s[RESTORE]%s %s.bak -> %s\n" "$COLOR_GREEN" "$COLOR_RESET" "$_target" "$_target"
    fi
}

install_gitconfig() {
    [ -z "$GITCONFIG_VARIANT" ] && return 0
    [ "$MODE_DRY_RUN" = "true" ] || remove_legacy_gitconfig_common
    _install_merged_file \
        "${DOTFILES_DIR}/config/git/.gitconfig.common" \
        "${DOTFILES_DIR}/config/git/.gitconfig.${GITCONFIG_VARIANT}" \
        "${HOME}/.gitconfig"
}

uninstall_gitconfig() {
    _variant="${GITCONFIG_VARIANT:-work}"
    # 旧方式 (stow link + ~/.gitconfig.common コピー) で配置済みの環境を片付ける
    if [ -L "${HOME}/.gitconfig" ]; then
        new_stow_specs_file
        _spec_file="$_stow_specs_file"
        stow_specs_add "$_spec_file" "config/git/.gitconfig.${_variant}" ".gitconfig"
        uninstall_stow_specs_file "gitconfig" "$_spec_file"
    fi

    uninstall_gitconfig_common
    _target=$(readlink "${HOME}/.gitconfig" 2>/dev/null) || true
    case "$_target" in
        */.gitconfig.work)    remove_link "config/git/.gitconfig.work"    "${HOME}/.gitconfig" ;;
        */.gitconfig.private) remove_link "config/git/.gitconfig.private" "${HOME}/.gitconfig" ;;
    esac

    _uninstall_merged_gitconfig \
        "${DOTFILES_DIR}/config/git/.gitconfig.common" \
        "${DOTFILES_DIR}/config/git/.gitconfig.${_variant}" \
        "${HOME}/.gitconfig"
}

_uninstall_merged_gitconfig() {
    _target="$3"
    [ -f "$_target" ] && [ ! -L "$_target" ] || return 0

    if ! _merged_target_matches "$1" "$2" "$_target"; then
        print_info "${_target} は生成後に変更されているため残します。不要なら手動削除してください"
        return 0
    fi

    rm "$_target"
    printf "%s[REMOVE]%s %s\n" "$COLOR_RED" "$COLOR_RESET" "$_target"
    if [ -f "${_target}.bak" ]; then
        mv "${_target}.bak" "$_target"
        printf "%s[RESTORE]%s %s.bak -> %s\n" "$COLOR_GREEN" "$COLOR_RESET" "$_target" "$_target"
    fi
}
