# shellcheck shell=sh

configure_ai_asset_profile() {
    [ -z "$AI_PROFILE_SUFFIX" ] || return 0
    if [ "$CLAUDE_CONFIG_ROOT" = "$HOME/.claude" ] && [ "$CODEX_CONFIG_ROOT" = "$HOME/.codex" ]; then
        return 0
    fi
    _profile_digest=$(python3 - "$HOME" "$CLAUDE_CONFIG_ROOT" "$CODEX_CONFIG_ROOT" <<'PY_PROFILE'
import hashlib
import json
import sys
print(hashlib.sha256(json.dumps(sys.argv[1:]).encode()).hexdigest()[:20])
PY_PROFILE
    ) || die "AI asset profile の識別に失敗しました"
    AI_PROFILE_SUFFIX="-${_profile_digest}"
    AI_ASSET_ROOT_REL=".generated/ai-assets${AI_PROFILE_SUFFIX}"
    AI_ASSET_ROOT="${DOTFILES_DIR}/${AI_ASSET_ROOT_REL}"
}

generate_ai_assets() {
    [ "$CLAUDE_SELECTED" = "true" ] || [ "$CODEX_SELECTED" = "true" ] || return 0

    configure_ai_asset_profile
    _generator="${DOTFILES_DIR}/${AI_ASSET_GENERATOR_REL}"
    [ -f "$_generator" ] || die "AI asset generator が見つかりません: $_generator"
    if [ "$MODE_DRY_RUN" = "true" ]; then
        _asset_stage_parent="${DOTFILES_DIR}/.generated"
        if [ ! -e "$_asset_stage_parent" ]; then
            mkdir "$_asset_stage_parent" || die "dry-run用AI asset一時ディレクトリを作成できません: $_asset_stage_parent"
            _AI_ASSET_STAGE_PARENT_CREATED="$_asset_stage_parent"
        fi
        _AI_ASSET_STAGE=$(mktemp -d "${_asset_stage_parent}/.ai-assets-dry-run.XXXXXX") \
            || die "dry-run用AI asset一時ディレクトリを作成できません"
        AI_ASSET_ROOT="${_AI_ASSET_STAGE}/ai-assets"
        print_info "[ドライラン] common/* から Claude/Codex 用assetを一時生成・検証"
        PYTHONDONTWRITEBYTECODE=1 python3 "$_generator" --repo "$DOTFILES_DIR" --output "$AI_ASSET_ROOT" >/dev/null \
            || die "AI asset の一時生成・検証に失敗しました"
    else
        print_info "common/* から Claude/Codex 用assetを生成・検証"
        python3 "$_generator" --repo "$DOTFILES_DIR" --output "$AI_ASSET_ROOT" || die "AI asset の生成・検証に失敗しました"
    fi
    for _generated_dir in "$AI_ASSET_ROOT/claude" "$AI_ASSET_ROOT/codex" "$AI_ASSET_ROOT/plugins"; do
        [ -d "$_generated_dir" ] || die "生成済みAI assetが不足しています: $_generated_dir"
    done
}

# Runtime deployment owns package naming and the default/alternate/shared layout.
deploy_runtime_assets() {
    configure_ai_asset_profile || return $?
    if [ "$2" = "$HOME/.$1" ]; then
        apply_link_package "$1$AI_PROFILE_SUFFIX" "$HOME" "$3" generated_link_specs "$1" "$1$AI_PROFILE_SUFFIX" "$3"
    else
        apply_link_package "$1-runtime$AI_PROFILE_SUFFIX" "$2" "$3" runtime_link_specs "$1" "$1-runtime$AI_PROFILE_SUFFIX" "$3" runtime || return $?
        if [ "$1" = codex ]; then
            apply_link_package "$1-shared$AI_PROFILE_SUFFIX" "$HOME" "$3" runtime_link_specs "$1" "$1-shared$AI_PROFILE_SUFFIX" "$3" shared || return $?
        fi
    fi
}

generated_link_specs() {
    if [ "$3" = uninstall ]; then
        if [ -s "$DOTFILES_DIR/.stow-work/.manifests/$2.links" ]; then
            cat "$DOTFILES_DIR/.stow-work/.manifests/$2.links" || return $?
        fi
        return 0
    fi
    [ -f "$AI_ASSET_ROOT/manifest.json" ] || return 0
    PYTHONDONTWRITEBYTECODE=1 python3 "$DOTFILES_DIR/$AI_ASSET_GENERATOR_REL" \
        --repo "$DOTFILES_DIR" --output "$AI_ASSET_ROOT" --list-target "$1"
}

runtime_link_specs() (
    set -- "$@" "$(installer_temp_file)"
    generated_link_specs "$1" "$2" "$3" > "$5" || return $?
    if [ "$3" = uninstall ]; then
        cat "$5"
        return
    fi
    while IFS= read -r _runtime_spec; do
        _runtime_source=${_runtime_spec%%:*}
        _runtime_dest=${_runtime_spec#*:}
        case "$_runtime_dest" in
            ".$1/"*)
                [ "$4" = runtime ] || continue
                _runtime_dest=${_runtime_dest#*/}
                ;;
            *) [ "$4" = shared ] || continue ;;
        esac
        emit_link_spec "$_runtime_source" "$_runtime_dest" || return 1
    done < "$5"
)
