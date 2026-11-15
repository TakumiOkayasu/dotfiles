# shellcheck shell=sh

# Categories declare links on stdout. This service owns batch files, target
# preparation, backend invocation and result accounting.
emit_link_spec() {
    printf '%s:%s\n' "$1" "$2"
}

apply_link_package() {
    ensure_installer_workspace || return 1
    set -- "$(installer_temp_file)" "$@"
    if write_package_specs "$@" > "$1"; then
        apply_link_specs "$2" "$3" "$4" "$1"
    else
        return $?
    fi
}

write_package_specs() {
    shift 4
    "$@"
}

validate_relative_link_path() {
    case "$1" in
        ""|.|..|/*|../*|*/../*|*/..|*/./*|*/.|*//*) return 2 ;;
    esac
}

validate_link_spec() {
    case "$1" in *:*) ;; *) return 2 ;; esac
    validate_relative_link_path "${1%%:*}" || return $?
    validate_relative_link_path "${1#*:}"
}

apply_link_specs() {
    case "$3" in install|uninstall) ;; *) print_error "不明なリンク操作: $3"; return 1 ;; esac
    case "$2" in /*) ;; *) print_error "配置先は絶対パスで指定してください: $2"; return 1 ;; esac
    case "$1" in ""|.|..|-*|*/*|*\\*|*[!A-Za-z0-9._-]*) print_error "不正なリンクpackage: $1"; return 2 ;; esac
    if [ "$3" = uninstall ] && [ ! -s "$4" ] && [ -f "$DOTFILES_DIR/.stow-work/.manifests/$1.links" ]; then
        set -- "$1" "$2" "$3" "$DOTFILES_DIR/.stow-work/.manifests/$1.links"
    fi
    ensure_installer_workspace || return 1
    set -- "$1" "$2" "$3" "$4" "$(installer_temp_file)"
    materialize_available_specs "$@" || return $?
    [ -s "$5" ] || return 0
    require_link_backend || return $?
    if [ "$3" = install ]; then
        if prepare_link_targets "$1" "$2" "$5"; then
            :
        else
            case "$?" in 2) return 0 ;; *) return 1 ;; esac
        fi
    fi
    run_link_backend "$1" "$2" "$3" "$5"
}

materialize_available_specs() {
    while IFS= read -r _batch_spec; do
        [ -n "$_batch_spec" ] || continue
        validate_link_spec "$_batch_spec" || { print_error "不正なリンク指定: $_batch_spec"; return 2; }
        if { [ "$3" = uninstall ] && [ -f "$DOTFILES_DIR/.stow-work/.manifests/$1.links" ]; } || [ -e "${DOTFILES_DIR}/${_batch_spec%%:*}" ] || [ -L "${DOTFILES_DIR}/${_batch_spec%%:*}" ]; then
            printf '%s\n' "$_batch_spec" >> "$5" || return 1
        else
            print_skip "スキップ: ${DOTFILES_DIR}/${_batch_spec%%:*} (ファイルが存在しません)"
            COUNT_SKIPPED=$((COUNT_SKIPPED + 1))
        fi
    done < "$4"

}

# Read-only path inspection is isolated from the caller's shell state.
first_link_conflict() (
    _remaining=$2
    _relative=
    while :; do
        _part=${_remaining%%/*}
        _relative=${_relative:+${_relative}/}${_part}
        _target="$1/$_relative"
        if [ -L "$_target" ] || { [ -e "$_target" ] && { [ "$_remaining" = "$_part" ] || [ ! -d "$_target" ]; }; }; then
            printf '%s\n' "$_relative"
            return 0
        fi
        [ -e "$_target" ] || return 0
        _remaining=${_remaining#*/}
    done
)

prepare_link_targets() {
    _batch_prepare_status=0
    while IFS= read -r _batch_prepare_spec; do
        [ -n "$_batch_prepare_spec" ] || continue
        if prepare_link_path "$1" "$2" "${_batch_prepare_spec#*:}"; then
            continue
        else
            case "$?" in 2) _batch_prepare_status=2 ;; *) return 1 ;; esac
        fi
    done < "$3"
    return "$_batch_prepare_status"
}

prepare_link_path() {
    set -- "$1" "$2" "$(first_link_conflict "$2" "$3")"
    [ -n "$3" ] || return 0
    prepare_link_target "$2/$3" "$1" ".stow-work/$1/$3"
}

prepare_link_target() {
    [ -e "$1" ] || [ -L "$1" ] || return 0
    link_points_to_repo_entry "$1" "$3" && return 0
    if [ "$MODE_DRY_RUN" = true ]; then
        if [ -L "$1" ]; then
            print_info "[ドライラン] 既存リンク削除: $1"
        else
            print_info "[ドライラン] バックアップ: $1 -> $(next_backup_path "$1")"
            COUNT_BACKUP=$((COUNT_BACKUP + 1))
        fi
        print_info "[ドライラン] 設定リンク作成: $2"
        COUNT_CREATED=$((COUNT_CREATED + 1))
        return 2
    fi
    if [ -L "$1" ]; then
        if rm "$1" 2>/dev/null; then
            print_info "既存リンク削除: $1"
        else
            print_error "既存リンク削除失敗: $1"
            COUNT_ERROR=$((COUNT_ERROR + 1))
            return 1
        fi
    else
        set -- "$1" "$2" "$3" "$(next_backup_path "$1")"
        print_info "バックアップ: $1 -> $4"
        if ! mv "$1" "$4" 2>/dev/null; then
            print_error "バックアップ失敗: $1"
            COUNT_ERROR=$((COUNT_ERROR + 1))
            return 1
        fi
        COUNT_BACKUP=$((COUNT_BACKUP + 1))
    fi
}

link_preview_source() (
    _asset_relative=${AI_ASSET_ROOT#"$DOTFILES_DIR"/}
    case "$1" in
        "$_asset_relative"/*) printf '%s/%s\n' "$AI_ASSET_ROOT_REL" "${1#"$_asset_relative"/}" ;;
        *) printf '%s\n' "$1" ;;
    esac
)

require_link_backend() {
    [ -x "$DOTFILES_DIR/scripts/stow-install.sh" ] || {
        print_error "リンク配置scriptが見つからないか実行できません: $DOTFILES_DIR/scripts/stow-install.sh"
        COUNT_ERROR=$((COUNT_ERROR + 1))
        return 1
    }
}

run_link_backend() {
    if [ "$MODE_DRY_RUN" = true ]; then
        while IFS= read -r _batch_preview; do
            print_info "[ドライラン] 設定リンク: $2/${_batch_preview#*:} <- $DOTFILES_DIR/$(link_preview_source "${_batch_preview%%:*}")"
        done < "$4"
        if [ ! -d "$2" ]; then
            print_info "[ドライラン] 配置先の作成後にリンク: $2"
            COUNT_CREATED=$((COUNT_CREATED + 1))
            return 0
        fi
    fi
    if execute_link_backend "$@"; then
        record_link_package "$1" "$3"
    else
        _batch_exit=$?
        print_error "設定リンク処理失敗: $1"
        COUNT_ERROR=$((COUNT_ERROR + 1))
        return "$_batch_exit"
    fi
}

execute_link_backend() (
    exec 3< "$4"
    case "$3" in
        uninstall) set -- --repo "$DOTFILES_DIR" --target "$2" --package "$1" --uninstall ;;
        install) set -- --repo "$DOTFILES_DIR" --target "$2" --package "$1" ;;
    esac
    while IFS= read -r _spec <&3; do
        [ -n "$_spec" ] && set -- "$@" --link "$_spec"
    done
    [ "$MODE_DRY_RUN" = true ] && set -- "$@" --dry-run
    "$DOTFILES_DIR/scripts/stow-install.sh" "$@"
)

record_link_package() {
    if [ "$2" = uninstall ]; then
        if [ "$MODE_DRY_RUN" = true ]; then
            print_info "[ドライラン] 設定リンク削除: $1"
        else
            print_success "設定リンク削除: $1"
            COUNT_REMOVED=$((COUNT_REMOVED + 1))
        fi
    else
        if [ "$MODE_DRY_RUN" = true ]; then print_info "[ドライラン] 設定リンク作成: $1"
        else print_success "設定リンク作成: $1"; fi
        COUNT_CREATED=$((COUNT_CREATED + 1))
    fi
}
