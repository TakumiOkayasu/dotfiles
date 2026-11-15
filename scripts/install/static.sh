# shellcheck shell=sh

install_vim_files() {
    apply_link_package vim "$HOME" install emit_link_spec config/vim/.vimrc .vimrc
}

uninstall_vim_files() {
    apply_link_package vim "$HOME" uninstall emit_link_spec config/vim/.vimrc .vimrc || return $?
    remove_link config/vim/.vimrc "$HOME/.vimrc"
    remove_link stow/vim/.vimrc "$HOME/.vimrc"
}

bin_link_specs() (
    for _file in "$DOTFILES_DIR"/bin/*; do
        [ -f "$_file" ] || continue
        _name=${_file##*/}
        emit_link_spec "bin/$_name" ".local/bin/$_name" || return 1
    done
    return 0
)

install_bin_files() {
    [ "$BIN_SELECTED" = true ] || return 0
    print_header "CLIツールをインストール"
    apply_link_package bin "$HOME" install bin_link_specs
}

uninstall_bin_files() {
    apply_link_package bin "$HOME" uninstall bin_link_specs
}
