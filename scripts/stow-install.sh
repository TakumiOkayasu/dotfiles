#!/bin/sh
set -eu

MODE_DRY_RUN=false
MODE_UNINSTALL=false
PACKAGES=""
GENERATED_LINKS=""
REPO_DIR=$(pwd)
TARGET_DIR=${HOME:-}

die() {
    printf '%s\n' "$1" >&2
    exit "${2:-2}"
}

usage() {
    cat << 'EOF'
Usage: stow-install.sh [--repo DIR] [--target DIR] --package NAME [options]

Options:
  --repo DIR       dotfile-work repository root
  --target DIR     stow target directory, usually HOME
  --package NAME   stow package name under stow/
  --link SRC:DEST  materialize SRC from repo as DEST in a generated package
  --dry-run        pass --no --verbose to stow
  --uninstall      pass --delete to stow
EOF
}

need_stow() {
    if command -v stow >/dev/null 2>&1; then
        return 0
    fi

    printf '%s\n' "GNU stow is required for stow-based dotfile install." >&2
    printf '%s\n' "Install it with: brew install stow" >&2
    printf '%s\n' "Install it with: apt install stow" >&2
    exit 127
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --repo)
                [ $# -ge 2 ] || die "missing value for --repo"
                REPO_DIR=$2
                shift 2
                ;;
            --target)
                [ $# -ge 2 ] || die "missing value for --target"
                TARGET_DIR=$2
                shift 2
                ;;
            --package)
                [ $# -ge 2 ] || die "missing value for --package"
                PACKAGES="${PACKAGES} $2"
                shift 2
                ;;
            --link)
                [ $# -ge 2 ] || die "missing value for --link"
                GENERATED_LINKS="${GENERATED_LINKS} $2"
                shift 2
                ;;
            --dry-run)
                MODE_DRY_RUN=true
                shift
                ;;
            --uninstall)
                MODE_UNINSTALL=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                die "unknown option: $1"
                ;;
        esac
    done
}

validate_package_name() {
    case "$1" in
        ""|.|..|-*|*/*|*\\*|*[!A-Za-z0-9._-]*)
            die "invalid stow package: $1"
            ;;
    esac
}

validate_generated_source() {
    case "$1" in
        ""|.|..|/*|../*|*/../*|*//*)
            die "invalid generated link source: $1"
            ;;
    esac
    [ -e "${REPO_DIR}/$1" ] || [ -L "${REPO_DIR}/$1" ] || die "missing generated link source: $1"
}

validate_generated_dest() {
    case "$1" in
        ""|.|..|/*|../*|*/../*|*//*)
            die "invalid generated link dest: $1"
            ;;
    esac
}

canonicalize_dir() {
    [ -d "$1" ] || die "directory not found: $1"
    (cd -P "$1" 2>/dev/null && pwd -P) || die "cannot resolve directory: $1"
}

normalize_paths() {
    REPO_DIR=$(canonicalize_dir "$REPO_DIR")
    TARGET_DIR=$(canonicalize_dir "$TARGET_DIR")
}

absolute_path_without_following_leaf() {
    _path=$1
    _base=$2

    case "$_path" in
        /*) _abs_path=$_path ;;
        *)  _abs_path="${_base}/${_path}" ;;
    esac

    _abs_dir=$(cd -P "$(dirname "$_abs_path")" 2>/dev/null && pwd -P) || {
        printf '%s\n' "$_abs_path"
        return 0
    }
    printf '%s/%s\n' "$_abs_dir" "$(basename "$_abs_path")"
}

prune_empty_target_dirs() {
    _dir=$1

    while [ "$_dir" != "$TARGET_DIR" ]; do
        case "$_dir" in
            "$TARGET_DIR"/*) ;;
            *) return 0 ;;
        esac

        rmdir "$_dir" 2>/dev/null || return 0
        _dir=$(dirname "$_dir")
    done
}

remove_stow_owned_target_link() {
    _package=$1
    _relative=$2
    _target=$3

    _target_link=$(readlink "$_target" 2>/dev/null) || return 0
    _target_abs=$(absolute_path_without_following_leaf "$_target_link" "$(dirname "$_target")")
    _generated_abs=$(absolute_path_without_following_leaf ".stow-work/${_package}/${_relative}" "$REPO_DIR")

    [ "$_target_abs" = "$_generated_abs" ] || return 1
    [ "$MODE_DRY_RUN" = "false" ] || return 0

    rm "$_target"
    prune_empty_target_dirs "$(dirname "$_target")"
}

first_target_symlink_relative() {
    _dest=$1

    _remaining=$_dest
    _relative=
    while :; do
        _part=${_remaining%%/*}
        if [ -z "$_relative" ]; then
            _relative=$_part
        else
            _relative="${_relative}/${_part}"
        fi

        _target="${TARGET_DIR}/${_relative}"
        if [ -L "$_target" ]; then
            printf '%s\n' "$_relative"
            return 0
        fi

        [ "$_remaining" != "$_part" ] || return 1
        _remaining=${_remaining#*/}
    done
}

remove_generated_target() {
    _package=$1
    _dest=$2
    validate_generated_dest "$_dest"

    if _relative=$(first_target_symlink_relative "$_dest"); then
        remove_stow_owned_target_link "$_package" "$_relative" "${TARGET_DIR}/${_relative}" || true
    fi
}

relative_source_for_dest() {
    _source=$1
    _dest=$2
    _dest_dir=$(dirname "$_dest")
    _prefix="../.."

    if [ "$_dest_dir" != "." ]; then
        _remaining=$_dest_dir
        while :; do
            _prefix="../${_prefix}"
            case "$_remaining" in
                */*) _remaining=${_remaining#*/} ;;
                *) break ;;
            esac
        done
    fi

    printf '%s/%s\n' "$_prefix" "$_source"
}

remove_legacy_generated_target() {
    _package=$1
    _link_spec=$2

    case "$_link_spec" in
        *:*) ;;
        *) die "invalid generated link: $_link_spec" ;;
    esac

    _source=${_link_spec%%:*}
    _dest=${_link_spec#*:}
    validate_generated_source "$_source"
    validate_generated_dest "$_dest"

    _target="${TARGET_DIR}/${_dest}"
    [ -L "$_target" ] || return 0

    _target_link=$(readlink "$_target" 2>/dev/null) || return 0
    _target_abs=$(absolute_path_without_following_leaf "$_target_link" "$(dirname "$_target")")
    _source_abs=$(absolute_path_without_following_leaf "$_source" "$REPO_DIR")
    _generated_abs=$(absolute_path_without_following_leaf ".stow-work/${_package}/${_dest}" "$REPO_DIR")

    [ "$_target_abs" != "$_generated_abs" ] || return 0
    [ "$_target_abs" = "$_source_abs" ] || return 0
    [ "$MODE_DRY_RUN" = "false" ] || return 0

    rm "$_target"
}

remove_legacy_generated_targets() {
    _package=$1

    [ "$MODE_UNINSTALL" = "false" ] || return 0

    for _link_spec in $GENERATED_LINKS; do
        remove_legacy_generated_target "$_package" "$_link_spec"
    done
}

materialize_generated_link() {
    _package_dir=$1
    _link_spec=$2

    case "$_link_spec" in
        *:*) ;;
        *) die "invalid generated link: $_link_spec" ;;
    esac

    _source=${_link_spec%%:*}
    _dest=${_link_spec#*:}
    validate_generated_source "$_source"
    validate_generated_dest "$_dest"

    _entry="${_package_dir}/${_dest}"
    mkdir -p "$(dirname "$_entry")"
    ln -s "$(relative_source_for_dest "$_source" "$_dest")" "$_entry"
}

generated_manifest_content() {
    for _link_spec in $GENERATED_LINKS; do
        printf '%s\n' "$_link_spec"
    done
}

generated_dest_in_specs() {
    _dest=$1

    for _link_spec in $GENERATED_LINKS; do
        case "$_link_spec" in
            *:*) [ "${_link_spec#*:}" = "$_dest" ] && return 0 ;;
        esac
    done
    return 1
}

generated_package_has_expected_links() {
    _package_dir=$1

    for _link_spec in $GENERATED_LINKS; do
        case "$_link_spec" in
            *:*) ;;
            *) die "invalid generated link: $_link_spec" ;;
        esac

        _source=${_link_spec%%:*}
        _dest=${_link_spec#*:}
        validate_generated_source "$_source"
        validate_generated_dest "$_dest"

        _entry="${_package_dir}/${_dest}"
        [ -L "$_entry" ] || return 1
        _actual_target=$(readlink "$_entry" 2>/dev/null) || return 1
        _expected_target=$(relative_source_for_dest "$_source" "$_dest")
        [ "$_actual_target" = "$_expected_target" ] || return 1
    done
}

generated_package_has_no_extra_entries() {
    _package_dir=$1

    _extra_entries=$(
        find "$_package_dir" \( -type f -o -type l \) -print |
            while IFS= read -r _entry; do
                _dest=${_entry#"$_package_dir"/}
                generated_dest_in_specs "$_dest" || printf '%s\n' "$_dest"
            done
    )
    [ -z "$_extra_entries" ]
}

generated_package_entries_match_specs() {
    _package_dir=$1

    generated_package_has_expected_links "$_package_dir" || return 1
    generated_package_has_no_extra_entries "$_package_dir"
}

generated_package_matches_manifest() {
    _package_dir=$1
    _manifest=$2

    [ "$MODE_DRY_RUN" = "false" ] || return 1
    [ "$MODE_UNINSTALL" = "false" ] || return 1
    [ -d "$_package_dir" ] || return 1
    [ -f "$_manifest" ] || return 1
    [ "$(cat "$_manifest")" = "$(generated_manifest_content)" ] || return 1
    generated_package_entries_match_specs "$_package_dir"
}

write_generated_manifest() {
    _manifest=$1

    mkdir -p "$(dirname "$_manifest")"
    generated_manifest_content > "$_manifest"
}

unstow_existing_generated_package() {
    _stow_dir=$1
    _package=$2
    _manifest=$3
    _package_dir="${_stow_dir}/${_package}"

    [ "$MODE_DRY_RUN" = "false" ] || return 0
    [ "$MODE_UNINSTALL" = "false" ] || return 0
    [ -d "$_package_dir" ] || return 0

    if [ -f "$_manifest" ]; then
        while IFS= read -r _link_spec; do
            [ -z "$_link_spec" ] && continue
            case "$_link_spec" in
                *:*) remove_generated_target "$_package" "${_link_spec#*:}" ;;
                *) die "invalid generated manifest entry: $_link_spec" ;;
            esac
        done < "$_manifest"
        return 0
    fi

    find "$_package_dir" \( -type f -o -type l \) -print | while IFS= read -r _entry; do
        remove_generated_target "$_package" "${_entry#"$_package_dir"/}"
    done
}

prepare_generated_package() {
    _package=$1
    _stow_dir="${REPO_DIR}/.stow-work"
    _package_dir="${_stow_dir}/${_package}"
    _manifest="${_stow_dir}/.manifests/${_package}.links"

    validate_package_name "$_package"
    case "$_package_dir" in
        "${_stow_dir}/"*) ;;
        *) die "invalid generated package path: $_package_dir" ;;
    esac

    remove_legacy_generated_targets "$_package"

    if generated_package_matches_manifest "$_package_dir" "$_manifest"; then
        printf '%s\n' "$_stow_dir"
        return 0
    fi

    unstow_existing_generated_package "$_stow_dir" "$_package" "$_manifest"
    rm -rf "$_package_dir"
    mkdir -p "$_package_dir"

    for _link_spec in $GENERATED_LINKS; do
        materialize_generated_link "$_package_dir" "$_link_spec"
    done
    write_generated_manifest "$_manifest"

    printf '%s\n' "$_stow_dir"
}

run_stow_package() {
    _package=$1
    validate_package_name "$_package"

    if [ -n "$GENERATED_LINKS" ]; then
        _stow_dir=$(prepare_generated_package "$_package")
    else
        _stow_dir="${REPO_DIR}/stow"
        [ -d "${_stow_dir}/${_package}" ] || die "missing stow package: ${_package}"
    fi

    set -- --dir "$_stow_dir" --target "$TARGET_DIR"
    [ "$MODE_DRY_RUN" = "true" ] && set -- "$@" --no --verbose
    [ "$MODE_UNINSTALL" = "true" ] && set -- "$@" --delete
    set -- "$@" "$_package"
    stow "$@"
}

main() {
    parse_args "$@"
    normalize_paths
    need_stow
    [ -n "$PACKAGES" ] || die "missing --package"

    for _package in $PACKAGES; do
        run_stow_package "$_package"
    done
}

main "$@"
