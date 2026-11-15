# shellcheck shell=sh

prepare_stow_target() {
    _dest="$1"
    _package="$2"
    _stow_entry="$3"

    [ -e "$_dest" ] || [ -L "$_dest" ] || return 0
    link_points_to_repo_entry "$_dest" "$_stow_entry" && return 0

    if [ "$MODE_DRY_RUN" = "true" ]; then
        if [ -L "$_dest" ]; then
            print_info "[ドライラン] 既存リンク削除: $_dest"
        else
            _backup=$(next_backup_path "$_dest")
            print_info "[ドライラン] バックアップ: $_dest -> $_backup"
            COUNT_BACKUP=$((COUNT_BACKUP + 1))
        fi
        print_info "[ドライラン] 設定リンク作成: $_package"
        COUNT_CREATED=$((COUNT_CREATED + 1))
        return 2
    fi

    if [ -L "$_dest" ]; then
        if rm "$_dest" 2>/dev/null; then
            print_info "既存リンク削除: $_dest"
        else
            print_error "既存リンク削除失敗: $_dest"
            COUNT_ERROR=$((COUNT_ERROR + 1))
            return 1
        fi
    elif [ -e "$_dest" ]; then
        _backup=$(next_backup_path "$_dest")
        print_info "バックアップ: $_dest -> $_backup"
        if ! mv "$_dest" "$_backup" 2>/dev/null; then
            print_error "バックアップ失敗: $_dest"
            COUNT_ERROR=$((COUNT_ERROR + 1))
            return 1
        fi
        COUNT_BACKUP=$((COUNT_BACKUP + 1))
    fi

    return 0
}

new_stow_specs_file() {
    _stow_specs_file=$(mktemp)
    _TMPFILES="$_TMPFILES $_stow_specs_file"
}

stow_specs_add() {
    _spec_file="$1"
    _source="$2"
    _dest="$3"

    if [ ! -e "${DOTFILES_DIR}/${_source}" ] && [ ! -L "${DOTFILES_DIR}/${_source}" ]; then
        print_skip "スキップ: ${DOTFILES_DIR}/${_source} (ファイルが存在しません)"
        COUNT_SKIPPED=$((COUNT_SKIPPED + 1))
        return 0
    fi

    printf '%s:%s\n' "$_source" "$_dest" >> "$_spec_file"
}

prepare_stow_target_path() {
    _pst_package="$1"
    _pst_remaining="$2"
    _pst_relative=""

    # Never prepare a leaf through an ancestor symlink: that would modify
    # the linked source tree, while leaving the actual stow conflict intact.
    while :; do
        _pst_part=${_pst_remaining%%/*}
        _pst_relative=${_pst_relative:+${_pst_relative}/}${_pst_part}
        _pst_target="${STOW_TARGET_DIR}/${_pst_relative}"
        _pst_entry=".stow-work/${_pst_package}/${_pst_relative}"

        if [ -L "$_pst_target" ]; then
            # Stow owns folded directory links and handles unfolding itself.
            # Stop here even for owned links; do not touch package contents.
            prepare_stow_target "$_pst_target" "$_pst_package" "$_pst_entry"
            return $?
        fi
        [ -e "$_pst_target" ] || return 0
        if [ "$_pst_remaining" = "$_pst_part" ] || [ ! -d "$_pst_target" ]; then
            prepare_stow_target "$_pst_target" "$_pst_package" "$_pst_entry"
            return $?
        fi
        _pst_remaining=${_pst_remaining#*/}
    done
}

prepare_stow_targets_from_file() {
    _package="$1"
    _spec_file="$2"
    _prepare_status=0

    while IFS= read -r _spec; do
        [ -z "$_spec" ] && continue
        _dest="${_spec#*:}"
        if prepare_stow_target_path "$_package" "$_dest"; then
            continue
        else
            _status=$?
        fi

        if [ "$_status" -eq 2 ]; then
            _prepare_status=2
            continue
        fi
        return "$_status"
    done < "$_spec_file"

    return "$_prepare_status"
}

run_stow_link_specs_file() {
    _package="$1"
    _mode="$2"
    _spec_file="$3"
    _script="${DOTFILES_DIR}/scripts/stow-install.sh"

    [ -s "$_spec_file" ] || return 0

    case "$_mode" in
        install|uninstall) ;;
        *)
            print_error "不明なリンク操作: $_mode"
            COUNT_ERROR=$((COUNT_ERROR + 1))
            return 1
            ;;
    esac

    if [ ! -x "$_script" ]; then
        print_error "リンク配置scriptが見つからないか実行できません: $_script"
        COUNT_ERROR=$((COUNT_ERROR + 1))
        return 1
    fi

    set -- --repo "$DOTFILES_DIR" --target "$STOW_TARGET_DIR" --package "$_package"
    while IFS= read -r _spec; do
        [ -z "$_spec" ] && continue
        if [ "$MODE_DRY_RUN" = "true" ]; then
            _source="${_spec%%:*}"
            _dest="${_spec#*:}"
            _preview_source="$_source"
            _ai_asset_root_relative=${AI_ASSET_ROOT#"$DOTFILES_DIR"/}
            case "$_source" in
                "$_ai_asset_root_relative"/*)
                    _preview_source="${AI_ASSET_ROOT_REL}/${_source#"$_ai_asset_root_relative"/}"
                    ;;
            esac
            print_info "[ドライラン] 設定リンク: ${STOW_TARGET_DIR}/${_dest} <- ${DOTFILES_DIR}/${_preview_source}"
        fi
        set -- "$@" --link "$_spec"
    done < "$_spec_file"
    [ "$MODE_DRY_RUN" = "true" ] && set -- "$@" --dry-run
    [ "$_mode" = "uninstall" ] && set -- "$@" --uninstall

    if [ "$MODE_DRY_RUN" = true ] && [ ! -d "$STOW_TARGET_DIR" ]; then
        print_info "[ドライラン] 配置先の作成後にリンク: $STOW_TARGET_DIR"
        COUNT_CREATED=$((COUNT_CREATED + 1))
        return 0
    fi

    if "$_script" "$@"; then
        if [ "$_mode" = "uninstall" ]; then
            if [ "$MODE_DRY_RUN" = "true" ]; then
                print_info "[ドライラン] 設定リンク削除: $_package"
            else
                print_success "設定リンク削除: $_package"
                COUNT_REMOVED=$((COUNT_REMOVED + 1))
            fi
        else
            if [ "$MODE_DRY_RUN" = "true" ]; then
                print_info "[ドライラン] 設定リンク作成: $_package"
            else
                print_success "設定リンク作成: $_package"
            fi
            COUNT_CREATED=$((COUNT_CREATED + 1))
        fi
    else
        _status=$?
        print_error "設定リンク処理失敗: $_package"
        COUNT_ERROR=$((COUNT_ERROR + 1))
        return "$_status"
    fi
}

install_stow_specs_file() {
    _package="$1"
    _spec_file="$2"

    [ -s "$_spec_file" ] || return 0

    if prepare_stow_targets_from_file "$_package" "$_spec_file"; then
        run_stow_link_specs_file "$_package" install "$_spec_file"
    else
        _status=$?
        [ "$_status" -eq 2 ] && return 0
        return "$_status"
    fi
}

uninstall_stow_specs_file() {
    _package="$1"
    _spec_file="$2"

    [ -s "$_spec_file" ] || return 0
    run_stow_link_specs_file "$_package" uninstall "$_spec_file"
}

run_stow_link() {
    _package="$1"
    _source="$2"
    _dest="$3"
    _mode="${4:-install}"

    new_stow_specs_file
    _spec_file="$_stow_specs_file"
    stow_specs_add "$_spec_file" "$_source" "$_dest"
    run_stow_link_specs_file "$_package" "$_mode" "$_spec_file"
}
