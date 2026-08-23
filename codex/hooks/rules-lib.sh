#!/bin/sh
# Shared helpers for Codex markdown rule discovery and checksum calculation.

rules_inline_dispatcher_registered() {
    _event="$1"
    _codex_dir="${CODEX_HOME:-$HOME/.codex}"
    _config="${_codex_dir}/config.toml"
    [ -f "$_config" ] || return 1
    grep -Fq "hook-dispatcher.sh ${_event}" "$_config"
}

rules_hash_cmd() {
    if command -v sha256sum >/dev/null 2>&1; then sha256sum | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then shasum -a 256 | awk '{print $1}'
    else cksum | awk '{print $1}'
    fi
}

rules_mktemp_file() {
    _name="${1:-tmp}"
    mktemp 2>/dev/null || printf '%s\n' "/tmp/codex-rules.$$.$_name"
}

rules_mktemp_dir() {
    _name="${1:-tmp}"
    _dir=$(mktemp -d 2>/dev/null || printf '%s\n' "/tmp/codex-rules.$$.$_name")
    mkdir -p "$_dir" 2>/dev/null || return 1
    printf '%s\n' "$_dir"
}

rules_add_rule_dir() {
    _dir="$1"
    _pairs="$2"
    _seen="$3"
    [ -d "$_dir" ] || return 0

    find -L "$_dir" -maxdepth 1 -type f -name '*.md' \
        ! -name 'RULES_BUNDLE.md' ! -name 'RULES_INDEX.md' 2>/dev/null |
        sort |
        while IFS= read -r _file; do
            [ -f "$_file" ] || continue
            _base=$(basename "$_file")
            _seen_file="${_seen}/${_base}"
            [ -e "$_seen_file" ] && continue
            : > "$_seen_file"
            printf '%s\t%s\n' "$_base" "$_file" >> "$_pairs"
        done
}

rules_collect_rule_files() {
    _cwd="$1"
    _out="$2"
    _code_root="${3:-}"
    _state=$(rules_mktemp_dir collect) || return 1
    _pairs="${_state}/pairs"
    _seen="${_state}/seen"
    mkdir -p "$_seen" 2>/dev/null || return 1
    : > "$_pairs"
    : > "$_out"

    _git_root=""
    if command -v git >/dev/null 2>&1; then
        _git_root=$(git -C "$_cwd" rev-parse --show-toplevel 2>/dev/null || echo "")
    fi

    # Higher-priority rule locations are registered first. Duplicate basenames
    # are ignored after the first match, so plugin/home/repo mirrors do not
    # change the active checksum.
    rules_add_rule_dir "$_cwd/.codex/rules" "$_pairs" "$_seen"
    if [ -n "$_git_root" ] && [ "$_git_root" != "$_cwd" ]; then
        rules_add_rule_dir "$_git_root/.codex/rules" "$_pairs" "$_seen"
    fi
    rules_add_rule_dir "$_cwd/common/rules" "$_pairs" "$_seen"
    if [ -n "$_git_root" ] && [ "$_git_root" != "$_cwd" ]; then
        rules_add_rule_dir "$_git_root/common/rules" "$_pairs" "$_seen"
    fi
    rules_add_rule_dir "$_cwd/codex/rules" "$_pairs" "$_seen"
    if [ -n "$_git_root" ] && [ "$_git_root" != "$_cwd" ]; then
        rules_add_rule_dir "$_git_root/codex/rules" "$_pairs" "$_seen"
    fi
    rules_add_rule_dir "$HOME/.codex/rules" "$_pairs" "$_seen"
    [ -n "$_code_root" ] && rules_add_rule_dir "$_code_root/../common/rules" "$_pairs" "$_seen"
    [ -n "$_code_root" ] && rules_add_rule_dir "$_code_root/rules" "$_pairs" "$_seen"
    [ -n "${PLUGIN_ROOT:-}" ] && rules_add_rule_dir "${PLUGIN_ROOT}/rules" "$_pairs" "$_seen"

    sort "$_pairs" | awk -F '	' '{print $2}' > "$_out"
    rm -rf "$_state"
}

rules_checksum_file_list() {
    _files="$1"
    while IFS= read -r _file; do
        [ -f "$_file" ] || continue
        printf 'FILE:%s\n' "$(basename "$_file")"
        cat "$_file"
    done < "$_files" | rules_hash_cmd
}

rules_total_bytes() {
    _files="$1"
    while IFS= read -r _file; do
        [ -f "$_file" ] && wc -c < "$_file"
    done < "$_files" | awk '{s+=$1} END{print s+0}'
}
