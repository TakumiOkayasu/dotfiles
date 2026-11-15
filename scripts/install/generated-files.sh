# shellcheck shell=sh

# Producers define content; this boundary owns replacement, ownership checks,
# preview policy and backup restoration for every generated file.
install_generated_file() {
    ensure_installer_workspace || return 1
    set -- "$(installer_temp_file)" "$@"
    write_generated_content "$@" > "$1" || return $?
    commit_generated_file "$2" "$1" "$3"
}

write_generated_content() {
    shift 3
    "$@"
}

commit_generated_file() {
    if [ "$MODE_DRY_RUN" = true ]; then
        printf '%s[DRY-RUN]%s Would create: %s (%s)\n' "$COLOR_YELLOW" "$COLOR_RESET" "$1" "$3"
        return 0
    fi
    ensure_dir "$(dirname "$1")" || return 1
    if [ -f "$1" ] && [ ! -L "$1" ] && cmp -s "$1" "$2"; then return 0; fi
    backup_generated_file "$1" || return 1
    cat "$2" > "$1" || return 1
    printf '%s[CREATE]%s %s (%s)\n' "$COLOR_GREEN" "$COLOR_RESET" "$1" "$3"
}

backup_generated_file() {
    if [ -L "$1" ]; then
        rm "$1"
    elif [ -f "$1" ]; then
        set -- "$1" "$(next_backup_path "$1")"
        mv "$1" "$2" || return 1
        printf '%s[BACKUP]%s %s -> %s\n' "$COLOR_YELLOW" "$COLOR_RESET" "$1" "$2"
    fi
}

remove_generated_file() {
    case "$2" in uninstall|retire) ;; *) return 2 ;; esac
    [ -f "$1" ] && [ ! -L "$1" ] || return 0
    ensure_installer_workspace || return 1
    if generated_file_is_owned "$@"; then
        if [ "$MODE_DRY_RUN" = true ]; then
            print_info "[ドライラン] 削除: $1"
            return 0
        fi
        rm "$1" || return 1
        printf '%s[REMOVE]%s %s\n' "$COLOR_RED" "$COLOR_RESET" "$1"
        if [ "$2" = uninstall ]; then restore_generated_backup "$1"; fi
    else
        print_info "$1 は生成後に変更されているため残します。不要なら手動削除してください"
    fi
}

# The read-only ownership predicate receives its arguments and then the target.
generated_file_is_owned() {
    set -- "$@" "$1"
    shift 2
    "$@"
}

restore_generated_backup() {
    [ -f "$1.bak" ] || return 0
    mv "$1.bak" "$1" || return 1
    printf '%s[RESTORE]%s %s.bak -> %s\n' "$COLOR_GREEN" "$COLOR_RESET" "$1" "$1"
}

source_content_matches() {
    cmp -s "$1" "$2"
}
