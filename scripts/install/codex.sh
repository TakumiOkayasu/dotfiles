# shellcheck shell=sh

cleanup_removed_codex_links() {
    _remove_legacy_codex_files
    _remove_legacy_codex_skill_links
}

_remove_legacy_codex_files() {
    remove_dotfiles_link "${CODEX_CONFIG_ROOT}/README.md" "除外済みCodex README"
    remove_dotfiles_link "${CODEX_CONFIG_ROOT}/settings.json" "除外済みCodex settings.json"
    remove_dotfiles_link "${CODEX_CONFIG_ROOT}/reference/claude-settings.reference.json" "除外済みCodex reference"
}

_remove_legacy_codex_skill_links() {
    _skills_dir="${CODEX_CONFIG_ROOT}/skills"
    [ -d "$_skills_dir" ] || return 0

    for _entry in "$_skills_dir"/*; do
        [ -e "$_entry" ] || [ -L "$_entry" ] || continue

        if is_dotfiles_link "$_entry"; then
            _remove_stale "$_entry" "移行済みCodex skill: $(basename "$_entry")"
        elif [ -d "$_entry" ]; then
            _remove_codex_skill_dir_if_all_dotfiles_links "$_entry"
        fi
    done
}

_remove_codex_skill_dir_if_all_dotfiles_links() {
    _entry="$1"
    _has_entries=false
    _all_dotfiles_links=true
    for _f in "$_entry"/*; do
        [ -e "$_f" ] || [ -L "$_f" ] || continue
        _has_entries=true
        is_dotfiles_link "$_f" || { _all_dotfiles_links=false; break; }
    done
    [ "$_has_entries" = "true" ] && [ "$_all_dotfiles_links" = "true" ] || return 0
    _remove_stale "$_entry" "移行済みCodex skill: $(basename "$_entry")" rf
}

codex_dest_for_relative() {
    case "$1" in
        global_AGENTS.md)
            printf '%s/AGENTS.md\n' "$CODEX_CONFIG_ROOT"
            ;;
        SUBAGENTS.md)
            printf '%s/%s\n' "$CODEX_CONFIG_ROOT" "$1"
            ;;
        agents/*.toml|agents/*/checklists/*.md|bin/*|hooks/*|rules/*.md|rules/*.rules)
            printf '%s/%s\n' "$CODEX_CONFIG_ROOT" "$1"
            ;;
        */*.config.toml)
            return 1
            ;;
        *.config.toml)
            printf '%s/%s\n' "$CODEX_CONFIG_ROOT" "$1"
            ;;
        config.toml|config.toml.template|hooks.json)
            return 1
            ;;
        skills/*/SKILL.md|skills/*/agents/openai.yaml)
            # Plugin-only mode: skills are distributed via plugins.
            return 1
            ;;
        *)
            return 1
            ;;
    esac
}

install_codex_config() {
    [ "$CODEX_SELECTED" != "true" ] && return 0
    configure_ai_asset_profile
    print_header "Codex設定をインストール"

    _codex_ensure_directories
    _codex_cleanup_all
    _codex_install_stow_package
    _codex_generate_config_from_template
    _codex_warn_legacy_hooks_json
    _codex_verify_hooks_feature
}

_codex_ensure_directories() {
    ensure_dir "${CODEX_CONFIG_ROOT}"
    ensure_dir "${CODEX_CONFIG_ROOT}/agents"
    ensure_dir "${CODEX_CONFIG_ROOT}/bin"
    ensure_dir "${CODEX_CONFIG_ROOT}/hooks"
    ensure_dir "${CODEX_CONFIG_ROOT}/rules"
    ensure_dir "${CODEX_CONFIG_ROOT}/plugins"
    ensure_dir "${HOME}/.agents/plugins"
}

_codex_cleanup_all() {
    cleanup_stale_links_in "Codex"       "${CODEX_CONFIG_ROOT}"  agents bin hooks plugins rules skills
    cleanup_removed_codex_links
    cleanup_stale_links_in "Codex shared" "${HOME}/.agents" plugins skills
}

_codex_install_stow_package() {
    if [ "$CODEX_CONFIG_ROOT" != "$HOME/.codex" ]; then
        runtime_stow_package codex "$CODEX_CONFIG_ROOT" install runtime
        runtime_stow_package codex "$CODEX_CONFIG_ROOT" install shared
        return
    fi
    new_stow_specs_file
    _spec_file="$_stow_specs_file"
    _codex_add_managed_stow_specs "$_spec_file"
    install_stow_specs_file "codex${AI_PROFILE_SUFFIX}" "$_spec_file"
}

_codex_uninstall_stow_package() {
    if [ "$CODEX_CONFIG_ROOT" != "$HOME/.codex" ]; then
        runtime_stow_package codex "$CODEX_CONFIG_ROOT" uninstall runtime
        runtime_stow_package codex "$CODEX_CONFIG_ROOT" uninstall shared
        return
    fi
    new_stow_specs_file
    _spec_file="$_stow_specs_file"
    _codex_add_managed_stow_specs "$_spec_file"
    uninstall_stow_specs_file "codex${AI_PROFILE_SUFFIX}" "$_spec_file"
}

_codex_add_managed_stow_specs() {
    _spec_file="$1"
    add_generated_ai_stow_specs "$_spec_file" codex "codex${AI_PROFILE_SUFFIX}"
}

_codex_generate_config_from_template() {
    _template="${DOTFILES_DIR}/codex/config.toml.template"
    _dest="${CODEX_CONFIG_ROOT}/config.toml"

    if [ ! -f "$_template" ]; then
        print_skip "スキップ: codex/config.toml.template (ファイルが存在しません)"
        COUNT_SKIPPED=$((COUNT_SKIPPED + 1))
        return 0
    fi

    if [ -e "$_dest" ] || [ -L "$_dest" ]; then
        print_info "既存の ${CODEX_CONFIG_ROOT}/config.toml は上書きしません。codex/config.toml.template を手動 merge してください"
        COUNT_SKIPPED=$((COUNT_SKIPPED + 1))
        return 0
    fi

    if [ "$MODE_DRY_RUN" = "true" ]; then
        print_info "[ドライラン] 生成: ${CODEX_CONFIG_ROOT}/config.toml <- codex/config.toml.template"
        COUNT_CREATED=$((COUNT_CREATED + 1))
        return 0
    fi

    ensure_dir "$(dirname "$_dest")" || return 1
    if cp "$_template" "$_dest" 2>/dev/null; then
        print_success "生成: ${CODEX_CONFIG_ROOT}/config.toml"
        COUNT_CREATED=$((COUNT_CREATED + 1))
    else
        print_error "生成失敗: ${CODEX_CONFIG_ROOT}/config.toml"
        COUNT_ERROR=$((COUNT_ERROR + 1))
        return 1
    fi
}

_codex_warn_legacy_hooks_json() {
    _hooks_json="${CODEX_CONFIG_ROOT}/hooks.json"
    [ -e "$_hooks_json" ] || [ -L "$_hooks_json" ] || return 0
    print_info "既存の ${CODEX_CONFIG_ROOT}/hooks.json は自動削除しません。inline hooks へ移行済みのため必要なら手動で退避してください"
    COUNT_SKIPPED=$((COUNT_SKIPPED + 1))
}

_codex_verify_hooks_feature() {
    [ "$MODE_DRY_RUN" = "true" ] && return 0

    command -v codex >/dev/null 2>&1 || return 0

    if codex features list 2>/dev/null | grep -q '^hooks[[:space:]]'; then
        print_success "Codex hooks feature: 利用可能"
    elif codex features list 2>/dev/null | grep -q '^codex_hooks[[:space:]]'; then
        print_info "Codex hooks feature: codex_hooks を有効化してください (codex features enable codex_hooks)"
    fi
}

uninstall_codex_config() {
    configure_ai_asset_profile
    print_header "Codex設定をアンインストール"

    _codex_cleanup_all
    _codex_uninstall_stow_package
    _codex_unlink_managed_files
    remove_legacy_common_hook_links "${CODEX_CONFIG_ROOT}/hooks"
    remove_legacy_qa_nightmare_checklist_links "${CODEX_CONFIG_ROOT}/agents/qa-nightmare/checklists"
    _codex_prune_empty_dirs
}

_codex_unlink_managed_files() {
    [ -d "${DOTFILES_DIR}/codex" ] || return 0

    _filelist=$(mktemp)
    _TMPFILES="$_TMPFILES $_filelist"
    (cd "$DOTFILES_DIR" && git ls-files codex/ 2>/dev/null) > "$_filelist"

    while IFS= read -r _file; do
        [ -z "$_file" ] && continue

        _relative="${_file#codex/}"
        _dest=$(codex_dest_for_relative "$_relative") || continue
        remove_link "$_file" "$_dest"
    done < "$_filelist"

    rm -f "$_filelist"
}

_codex_prune_empty_dirs() {
    [ "$MODE_DRY_RUN" = "true" ] && return 0

    _count=$(find "${CODEX_CONFIG_ROOT}" -mindepth 1 -depth -type d 2>/dev/null \
        | while IFS= read -r _dir; do rmdir "$_dir" 2>/dev/null && echo x; done \
        | wc -l)
    if [ "$_count" -gt 0 ]; then
        print_success "空ディレクトリ削除: .codex/ 配下 ${_count} 件"
    fi
}
