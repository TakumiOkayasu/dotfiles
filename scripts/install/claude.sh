# shellcheck shell=sh

# global_ プレフィックスを除去
strip_global_prefix() {
    case "$1" in
        global_*) printf '%s\n' "${1#global_}" ;;
        *)        printf '%s\n' "$1" ;;
    esac
}

claude_target_relative() {
    case "$1" in
        statusline.settings.json) printf '%s\n' "statusline.json" ;;
        *)                        strip_global_prefix "$1" ;;
    esac
}

cleanup_legacy_claude_skill_tiers() {
    _skills_dir="${CLAUDE_CONFIG_ROOT}/skills"
    [ -d "$_skills_dir" ] || return 0

    for _entry in "$_skills_dir"/*; do
        case "$(basename "$_entry")" in
            1-core|2-domain|3-task|4-utility)
                if [ -L "$_entry" ]; then
                    remove_dotfiles_link "$_entry" "旧スキル構造: $(basename "$_entry")"
                    continue
                fi
                [ -d "$_entry" ] || continue

                _legacy_links=$(mktemp)
                _TMPFILES="$_TMPFILES $_legacy_links"
                find "$_entry" -type l -print > "$_legacy_links" 2>/dev/null || true
                while IFS= read -r _legacy_link; do
                    [ -n "$_legacy_link" ] || continue
                    remove_dotfiles_link \
                        "$_legacy_link" \
                        "旧スキル構造リンク: ${_legacy_link#"$HOME"/}"
                done < "$_legacy_links"
                ;;
        esac
    done
}

install_claude_config() {
    [ "$CLAUDE_SELECTED" != "true" ] && return 0
    configure_ai_asset_profile
    print_header "Claude設定をインストール"

    _claude_ensure_directories
    _claude_cleanup_stale
    _claude_install_stow_package
    _claude_setup_vendor_skills
}

_claude_ensure_directories() {
    ensure_dir "${CLAUDE_CONFIG_ROOT}"
    ensure_dir "${CLAUDE_CONFIG_ROOT}/bin"
    ensure_dir "${CLAUDE_CONFIG_ROOT}/hooks"
    ensure_dir "${CLAUDE_CONFIG_ROOT}/skills"
    ensure_dir "${CLAUDE_CONFIG_ROOT}/rules"
}

_claude_cleanup_stale() {
    cleanup_legacy_claude_skill_tiers
    remove_dotfiles_link "${CLAUDE_CONFIG_ROOT}/statusline.settings.json" "旧Claude statusline.settings.json"
    cleanup_stale_links_in "Claude" "${CLAUDE_CONFIG_ROOT}" bin commands hooks skills rules
}

_claude_install_stow_package() {
    if [ "$CLAUDE_CONFIG_ROOT" != "$HOME/.claude" ]; then
        runtime_stow_package claude "$CLAUDE_CONFIG_ROOT" install runtime
        return
    fi
    new_stow_specs_file
    _spec_file="$_stow_specs_file"
    _claude_add_managed_stow_specs "$_spec_file"
    install_stow_specs_file "claude${AI_PROFILE_SUFFIX}" "$_spec_file"
}

_claude_uninstall_stow_package() {
    if [ "$CLAUDE_CONFIG_ROOT" != "$HOME/.claude" ]; then
        runtime_stow_package claude "$CLAUDE_CONFIG_ROOT" uninstall runtime
        return
    fi
    new_stow_specs_file
    _spec_file="$_stow_specs_file"
    _claude_add_managed_stow_specs "$_spec_file"
    uninstall_stow_specs_file "claude${AI_PROFILE_SUFFIX}" "$_spec_file"
}

_claude_add_managed_stow_specs() {
    _spec_file="$1"
    add_generated_ai_stow_specs "$_spec_file" claude "claude${AI_PROFILE_SUFFIX}"
}

_claude_setup_vendor_skills() {
    _vendor_dir="${CLAUDE_CONFIG_ROOT}/vendor"
    _agent_skills_dir="${_vendor_dir}/agent-skills"
    ensure_dir "$_vendor_dir"

    _claude_vendor_clone_if_missing "$_agent_skills_dir"

    [ -d "$_agent_skills_dir/skills" ] || return 0
    for _skill in $VENDOR_SKILLS; do
        _claude_vendor_link_skill "$_agent_skills_dir" "$_skill"
    done
}

_claude_vendor_clone_if_missing() {
    [ -d "${1}/.git" ] && return 0

    if [ "$MODE_DRY_RUN" = "true" ]; then
        print_info "[ドライラン] vendor: agent-skills を取得"
        return 0
    fi

    if (
        unset GIT_INDEX_FILE
        git clone --depth 1 --quiet "https://github.com/vercel-labs/agent-skills.git" "$1" 2>/dev/null
    ); then
        print_success "取得: vendor/agent-skills"
    else
        print_skip "vendor/agent-skills の取得に失敗（オフライン？）"
    fi
}

_claude_vendor_link_skill() {
    _src="${1}/skills/${2}"
    _dest="${CLAUDE_CONFIG_ROOT}/skills/${2}"

    [ -L "$_dest" ] && [ ! -e "$_dest" ] && rm "$_dest" 2>/dev/null

    [ -e "$_src" ]  || return 0
    [ -e "$_dest" ] && return 0

    if [ "$MODE_DRY_RUN" = "true" ]; then
        print_info "[ドライラン] リンク: ${CLAUDE_CONFIG_ROOT}/skills/${2}"
        return 0
    fi

    if ln -s "$_src" "$_dest"; then
        print_success "作成: ${CLAUDE_CONFIG_ROOT}/skills/${2}"
    else
        print_error "リンク作成失敗: ${2}"
    fi
}

uninstall_claude_config() {
    configure_ai_asset_profile
    print_header "Claude設定をアンインストール"

    _claude_cleanup_stale
    _claude_uninstall_stow_package
    _claude_unlink_managed_files
    remove_legacy_common_hook_links "${CLAUDE_CONFIG_ROOT}/hooks"
    remove_legacy_qa_nightmare_checklist_links "${CLAUDE_CONFIG_ROOT}/skills/qa-nightmare/checklists"
    _claude_unlink_vendor_skills
    _claude_prune_empty_dirs
}

_claude_unlink_managed_files() {
    [ -d "${DOTFILES_DIR}/claude" ] || return 0

    _filelist=$(mktemp)
    _TMPFILES="$_TMPFILES $_filelist"
    (cd "$DOTFILES_DIR" && git ls-files claude/ 2>/dev/null) > "$_filelist"

    while IFS= read -r _file; do
        [ -z "$_file" ] && continue

        _relative="${_file#claude/}"
        case "$_relative" in CLAUDE.md) continue ;; esac

        _dest_relative=$(claude_target_relative "$_relative")
        _dest="${CLAUDE_CONFIG_ROOT}/${_dest_relative}"
        remove_link "$_file" "$_dest"
    done < "$_filelist"

    rm -f "$_filelist"
}

_claude_unlink_vendor_skills() {
    for _skill in $VENDOR_SKILLS; do
        _dest="${CLAUDE_CONFIG_ROOT}/skills/${_skill}"
        [ -L "$_dest" ] || continue
        if [ "$MODE_DRY_RUN" = "true" ]; then
            print_info "[ドライラン] 削除: ${CLAUDE_CONFIG_ROOT}/skills/${_skill}"
        else
            rm "$_dest" && print_success "削除: ${CLAUDE_CONFIG_ROOT}/skills/${_skill}"
        fi
    done

    [ -d "${CLAUDE_CONFIG_ROOT}/vendor/agent-skills" ] || return 0
    if [ "$MODE_DRY_RUN" = "true" ]; then
        print_info "[ドライラン] 削除: ${CLAUDE_CONFIG_ROOT}/vendor/agent-skills"
    else
        rm -rf "${CLAUDE_CONFIG_ROOT}/vendor/agent-skills" && print_success "削除: ${CLAUDE_CONFIG_ROOT}/vendor/agent-skills"
        rmdir "${CLAUDE_CONFIG_ROOT}/vendor" 2>/dev/null || true
    fi
}

_claude_prune_empty_dirs() {
    [ "$MODE_DRY_RUN" = "true" ] && return 0

    _count=$(find "${CLAUDE_CONFIG_ROOT}" -mindepth 1 -depth -type d 2>/dev/null \
        | while IFS= read -r _dir; do rmdir "$_dir" 2>/dev/null && echo x; done \
        | wc -l)
    if [ "$_count" -gt 0 ]; then
        print_success "空ディレクトリ削除: .claude/ 配下 ${_count} 件"
    fi
}
