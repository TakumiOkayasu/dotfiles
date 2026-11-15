# shellcheck shell=sh

install_git_settings() {
    install_git_files || return $?
    install_gitconfig || return $?
    install_gitignore
}

uninstall_git_settings() {
    uninstall_git_files || return $?
    uninstall_gitconfig || return $?
    uninstall_gitignore
}

git_link_specs() {
    emit_link_spec config/git/.git-completion.bash .git-completion.bash || return 1
    emit_link_spec config/git/.git-prompt.sh .git-prompt.sh || return 1
    emit_link_spec config/git/.git-prompt.sh .config/git/.git-prompt.sh || return 1
    emit_link_spec config/git/.gitattributes .config/git/attributes
}

install_git_files() {
    cleanup_legacy_git_artifacts || return $?
    apply_link_package git "$HOME" install git_link_specs
}

uninstall_git_files() {
    cleanup_legacy_git_artifacts || return $?
    apply_link_package git "$HOME" uninstall git_link_specs
}

cleanup_legacy_git_artifacts() {
    remove_dotfiles_link "${HOME}/.gitignore_global"        "旧gitignore_globalリンク" || return $?
    remove_dotfiles_link "${HOME}/.gitignore.common"        "旧gitignore.commonリンク" || return $?
    remove_dotfiles_link "${HOME}/.config/git/.gitattributes" "旧gitattributesリンク (ドット付き)" || return $?
    if is_dotfiles_link "$HOME/.gitignore"; then
        remove_dotfiles_link "$HOME/.gitignore" "旧gitignoreリンク"
    elif [ -f "$HOME/.gitignore" ]; then
        print_info "残骸の可能性: $HOME/.gitignore (旧 excludesfile 実体)。不要なら手動削除してください"
    fi
}

emit_git_content() {
    case "$2" in work|private) ;; *) print_error "不正なGit設定variant: $2" >&2; return 1 ;; esac
    cat "$DOTFILES_DIR/config/git/.$1.common" "$DOTFILES_DIR/config/git/.$1.$2"
}

git_content_matches() (
    _expected=$(installer_temp_file) || return 1
    for _variant in work private; do
        [ -f "$DOTFILES_DIR/config/git/.$1.common" ] && [ -f "$DOTFILES_DIR/config/git/.$1.$_variant" ] || continue
        emit_git_content "$1" "$_variant" > "$_expected" || return 1
        cmp -s "$_expected" "$2" && return 0
    done
    return 1
)

install_gitconfig() {
    [ -n "$GITCONFIG_VARIANT" ] || return 0
    if [ "$MODE_DRY_RUN" != true ]; then remove_legacy_gitconfig_common || return $?; fi
    install_generated_file "$HOME/.gitconfig" "base + $GITCONFIG_VARIANT" emit_git_content gitconfig "$GITCONFIG_VARIANT"
}

install_gitignore() {
    [ -n "$GITCONFIG_VARIANT" ] || return 0
    install_generated_file "$HOME/.config/git/ignore" "base + $GITCONFIG_VARIANT" emit_git_content gitignore "$GITCONFIG_VARIANT"
}

remove_legacy_gitconfig_common() {
    if [ -f "$HOME/.gitconfig.common" ] && [ ! -L "$HOME/.gitconfig.common" ] \
        && cmp -s "$DOTFILES_DIR/config/git/.gitconfig.common" "$HOME/.gitconfig.common"; then
        remove_generated_file "$HOME/.gitconfig.common" retire source_content_matches "$DOTFILES_DIR/config/git/.gitconfig.common"
    elif [ -e "$HOME/.gitconfig.common" ] || [ -L "$HOME/.gitconfig.common" ]; then
        remove_dotfiles_link "$HOME/.gitconfig.common" "旧gitconfig.commonリンク" || return $?
        if [ -f "$HOME/.gitconfig.common" ]; then
            print_info "残骸の可能性: $HOME/.gitconfig.common (現在は参照されない)。不要なら手動削除してください"
        fi
    fi
}

uninstall_gitconfig_common() {
    if [ -L "$HOME/.gitconfig.common" ]; then
        remove_link config/git/.gitconfig.common "$HOME/.gitconfig.common"
    else
        remove_generated_file "$HOME/.gitconfig.common" uninstall source_content_matches "$DOTFILES_DIR/config/git/.gitconfig.common"
    fi
}

uninstall_gitconfig() {
    if link_points_to_repo_entry "$HOME/.gitconfig" .stow-work/gitconfig/.gitconfig; then
        apply_link_package gitconfig "$HOME" uninstall emit_link_spec config/git/.gitconfig.work .gitconfig || return $?
    fi
    if [ -L "$HOME/.gitconfig" ]; then
        if link_targets_source "$HOME/.gitconfig" "$DOTFILES_DIR/config/git/.gitconfig.private"; then
            remove_link config/git/.gitconfig.private "$HOME/.gitconfig" || return $?
        else
            remove_link config/git/.gitconfig.work "$HOME/.gitconfig" || return $?
        fi
    fi
    uninstall_gitconfig_common || return $?
    remove_generated_file "$HOME/.gitconfig" uninstall git_content_matches gitconfig
}

uninstall_gitignore() {
    remove_generated_file "$HOME/.config/git/ignore" uninstall git_content_matches gitignore
}
