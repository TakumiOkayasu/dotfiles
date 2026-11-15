# shellcheck shell=sh

canonicalize_path() (
    [ -z "$1" ] && return 0
    readlink -f "$1" 2>/dev/null || realpath "$1" 2>/dev/null || {
        _cp_dir=$(cd -P "$(dirname "$1")" 2>/dev/null && pwd -P) || { echo "$1"; return; }
        echo "${_cp_dir}/$(basename "$1")"
    }
)

ensure_dir() {
    _dir="$1"

    if [ -L "$_dir" ]; then
        if [ "$MODE_DRY_RUN" = "true" ]; then
            print_info "[ドライラン] 既存リンク削除: $_dir"
        else
            rm "$_dir" 2>/dev/null || true
        fi
    fi

    [ -d "$_dir" ] && return 0

    if [ "$MODE_DRY_RUN" = "true" ]; then
        print_info "[ドライラン] ディレクトリ作成: $_dir"
        return 0
    fi

    if ! mkdir -p "$_dir" 2>/dev/null; then
        print_error "ディレクトリ作成失敗: $_dir"
        COUNT_ERROR=$((COUNT_ERROR + 1))
        return 1
    fi
    return 0
}

absolute_path_without_following_leaf() (
    _path="$1"
    _base="$2"

    case "$_path" in
        /*) _abs_path="$_path" ;;
        *)  _abs_path="${_base}/$_path" ;;
    esac

    _abs_dir=$(cd -P "$(dirname "$_abs_path")" 2>/dev/null && pwd -P) || {
        printf '%s\n' "$_abs_path"
        return 0
    }
    printf '%s/%s\n' "$_abs_dir" "$(basename "$_abs_path")"
)

link_points_to_repo_entry() (
    _link="$1"
    _repo_entry="$2"

    [ -L "$_link" ] || return 1
    _link_target=$(readlink "$_link" 2>/dev/null) || return 1
    _link_target=$(absolute_path_without_following_leaf "$_link_target" "$(dirname "$_link")")
    _expected_target=$(absolute_path_without_following_leaf "$_repo_entry" "$DOTFILES_DIR")
    [ "$_link_target" = "$_expected_target" ]
)

next_backup_path() (
    _target="$1"
    _backup="${_target}.bak"

    if [ ! -e "$_backup" ] && [ ! -L "$_backup" ]; then
        printf '%s\n' "$_backup"
        return 0
    fi

    _index=1
    while :; do
        _backup="${_target}.bak.${_index}"
        if [ ! -e "$_backup" ] && [ ! -L "$_backup" ]; then
            printf '%s\n' "$_backup"
            return 0
        fi
        _index=$((_index + 1))
    done
)

remove_link() {
    remove_owned_link "$DOTFILES_DIR/$1" "$2" restore
}

remove_owned_link() {
    case "$3" in restore|preserve) ;; *) return 2 ;; esac
    [ -e "$2" ] || [ -L "$2" ] || return 0
    if [ ! -L "$2" ]; then
        print_skip "スキップ: $2 (シンボリックリンクではありません)"
        COUNT_SKIPPED=$((COUNT_SKIPPED + 1))
        return 0
    fi
    if ! link_targets_source "$2" "$1"; then
        print_skip "スキップ: $2 (別の場所を指しています)"
        COUNT_SKIPPED=$((COUNT_SKIPPED + 1))
        return 0
    fi
    if [ "$MODE_DRY_RUN" = true ]; then
        print_info "[ドライラン] 削除: $2"
        return 0
    fi
    if rm "$2" 2>/dev/null; then
        print_success "削除: $2"
        COUNT_REMOVED=$((COUNT_REMOVED + 1))
        if [ "$3" = restore ] && [ -e "$2.bak" ]; then
            if mv "$2.bak" "$2" 2>/dev/null; then
                print_info "復元: $2.bak -> $2"
            else
                print_error "復元失敗: $2.bak"
                COUNT_ERROR=$((COUNT_ERROR + 1))
                return 1
            fi
        fi
    else
        print_error "削除失敗: $2"
        COUNT_ERROR=$((COUNT_ERROR + 1))
        return 1
    fi
}

install_optional_link() {
    [ -e "$1" ] || return 0
    # Existing vendor installs repair dangling links, but previews must not.
    if [ -L "$2" ] && [ ! -e "$2" ]; then
        if [ "$MODE_DRY_RUN" = true ]; then
            print_info "[ドライラン] リンク: $2"
            return 0
        fi
        if ! rm "$2"; then
            print_error "既存リンク削除失敗: $2"
            COUNT_ERROR=$((COUNT_ERROR + 1))
            return 1
        fi
    fi
    { [ -e "$2" ] || [ -L "$2" ]; } && return 0
    if [ "$MODE_DRY_RUN" = true ]; then
        print_info "[ドライラン] リンク: $2"
        return 0
    fi
    if ln -s "$1" "$2"; then
        print_success "作成: $2"
    else
        print_error "リンク作成失敗: $2"
        COUNT_ERROR=$((COUNT_ERROR + 1))
        return 1
    fi
}

# DOTFILES_DIR 向きのシンボリックリンクか
is_dotfiles_link() (
    [ ! -L "$1" ] && return 1
    _idl_target=$(readlink "$1" 2>/dev/null) || return 1
    _idl_target=$(absolute_path_without_following_leaf "$_idl_target" "$(dirname "$1")")
    case "$_idl_target" in "${DOTFILES_DIR}"/*) return 0 ;; *) return 1 ;; esac
)

# DOTFILES_DIR 向きのリンクのうち、git 管理外 (stale) か
is_stale_repository_link() (
    [ -L "$1" ] || return 1
    _target=$(readlink "$1") || return 1
    _target=$(absolute_path_without_following_leaf "$_target" "$(dirname "$1")")
    case "$_target" in
        "$2/.stow-work/"*) [ ! -e "$1" ]; return $? ;;
        "$2/"*) ;;
        *) return 1 ;;
    esac
    [ ! -e "$1" ] && return 0
    _relative=${_target#"$2"/}
    (cd "$DOTFILES_DIR" && git ls-files --error-unmatch "$_relative" >/dev/null 2>&1) && return 1
    return 0
)

_remove_stale() {
    if [ "$MODE_DRY_RUN" = "true" ]; then
        print_info "[ドライラン] 削除: $2"
        return 0
    fi
    _rs_ok=false
    if [ "${3:-}" = "rf" ]; then
        rm -rf "$1" 2>/dev/null && _rs_ok=true
    else
        rm "$1" 2>/dev/null && _rs_ok=true
    fi
    if [ "$_rs_ok" = "true" ]; then
        print_info "削除: $2"
    else
        print_error "削除失敗: $2"
        COUNT_ERROR=$((COUNT_ERROR + 1))
        return 1
    fi
}

# DOTFILES_DIR 向きリンクならラベル付きで削除
remove_dotfiles_link() {
    if is_dotfiles_link "$1"; then
        _remove_stale "$1" "$2" || return $?
    fi
}

cleanup_stale_links_in() {
    _csl_label="$1"
    _csl_base="$2"
    shift 2
    _csl_dotfiles=$(canonicalize_path "$DOTFILES_DIR")

    for _dir in "$@"; do
        _target_dir="${_csl_base}/${_dir}"
        [ -d "$_target_dir" ] || continue
        for _entry in "$_target_dir"/*; do
            if [ -L "$_entry" ]; then
                is_stale_repository_link "$_entry" "$_csl_dotfiles" || continue
                _remove_stale "$_entry" "古い${_csl_label} ${_dir}: $(basename "$_entry")" || return $?
            elif [ -d "$_entry" ]; then
                directory_contains_only_stale_links "$_entry" "$_csl_dotfiles" || continue
                _remove_stale "$_entry" "古い${_csl_label} ${_dir}: $(basename "$_entry")" rf || return $?
            fi
        done
    done
}

directory_contains_only_stale_links() (
    _has_entries=false
    for _entry in "$1"/* "$1"/.[!.]* "$1"/..?*; do
        [ ! -L "$_entry" ] && [ ! -e "$_entry" ] && continue
        _has_entries=true
        is_stale_repository_link "$_entry" "$2" || return 1
    done
    [ "$_has_entries" = true ]
)

remove_legacy_common_hook_links() {
    _dest_dir="$1"

    for _file_path in "$DOTFILES_DIR"/"$COMMON_HOOKS"/*.sh; do
        [ -f "$_file_path" ] || continue
        _relative=$(basename "$_file_path")
        _dest="${_dest_dir}/${_relative}"
        [ -e "$_dest" ] || [ -L "$_dest" ] || continue
        remove_dotfiles_link "$_dest" "旧common hook: ${_relative}" || return $?
    done
}

remove_legacy_qa_nightmare_checklist_links() {
    _dest_dir="$1"
    [ -d "$_dest_dir" ] || return 0

    for _entry in "$_dest_dir"/*; do
        [ -e "$_entry" ] || [ -L "$_entry" ] || continue
        remove_dotfiles_link "$_entry" "旧qa-nightmare checklist: $(basename "$_entry")" || return $?
    done
}

detect_platform() {
    if [ -f /proc/sys/fs/binfmt_misc/WSLInterop ] || [ -n "${WSL_DISTRO_NAME:-}" ] || grep -qi microsoft /proc/version 2>/dev/null; then
        echo "wsl"
    elif [ "$(uname)" = "Darwin" ]; then
        echo "macos"
    else
        case "$(uname -s)" in
            CYGWIN*|MINGW*|MSYS*) echo "windows" ;;
            *) echo "linux" ;;
        esac
    fi
}

# Ownership queries never modify the caller's scratch variables.
link_targets_source() (
    [ -L "$1" ] || return 1
    _link_value=$(readlink "$1") || return 1
    _link_path=$(absolute_path_without_following_leaf "$_link_value" "$(dirname "$1")")
    [ "$(canonicalize_path "$_link_path")" = "$(canonicalize_path "$2")" ]
)
