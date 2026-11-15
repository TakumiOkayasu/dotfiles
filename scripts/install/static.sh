# shellcheck shell=sh

install_vim_files() {
    if prepare_stow_target "${HOME}/.vimrc" "vim" ".stow-work/vim/.vimrc"; then
        run_stow_link "vim" "config/vim/.vimrc" ".vimrc"
    else
        _status=$?
        [ "$_status" -eq 2 ] && return 0
        return "$_status"
    fi
}

uninstall_vim_files() {
    _dest="${HOME}/.vimrc"
    [ -e "$_dest" ] || [ -L "$_dest" ] || return 0

    if link_points_to_repo_entry "$_dest" "config/vim/.vimrc"; then
        remove_link "config/vim/.vimrc" "$_dest"
    elif link_points_to_repo_entry "$_dest" "stow/vim/.vimrc"; then
        remove_link "stow/vim/.vimrc" "$_dest"
    elif link_points_to_repo_entry "$_dest" ".stow-work/vim/.vimrc"; then
        run_stow_link "vim" "config/vim/.vimrc" ".vimrc" "uninstall"
    else
        print_skip "スキップ: $_dest (別の場所を指しています)"
        COUNT_SKIPPED=$((COUNT_SKIPPED + 1))
    fi
}

install_bin_files() {
    [ "$BIN_SELECTED" != "true" ] && return 0
    print_header "CLIツールをインストール"

    new_stow_specs_file
    _spec_file="$_stow_specs_file"

    for _bin_file in "$DOTFILES_DIR"/bin/*; do
        [ -f "$_bin_file" ] || continue
        _name=$(basename "$_bin_file")
        stow_specs_add "$_spec_file" "bin/$_name" ".local/bin/$_name"
    done

    install_stow_specs_file "bin" "$_spec_file"
}

uninstall_bin_files() {
    new_stow_specs_file
    _spec_file="$_stow_specs_file"

    for _bin_file in "$DOTFILES_DIR"/bin/*; do
        [ -f "$_bin_file" ] || continue
        _name=$(basename "$_bin_file")
        stow_specs_add "$_spec_file" "bin/$_name" ".local/bin/$_name"
    done

    uninstall_stow_specs_file "bin" "$_spec_file"

    for _bin_file in "$DOTFILES_DIR"/bin/*; do
        [ -f "$_bin_file" ] || continue
        _name=$(basename "$_bin_file")
        remove_link "bin/$_name" "${HOME}/.local/bin/$_name"
    done
}
