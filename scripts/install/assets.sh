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

add_generated_ai_stow_specs() {
    _spec_file="$1"
    _target="$2"
    _package="$3"
    _previous_manifest="${DOTFILES_DIR}/.stow-work/.manifests/${_package}.links"

    if [ "$MODE_UNINSTALL" = "true" ]; then
        [ -s "$_previous_manifest" ] && cat "$_previous_manifest" >> "$_spec_file"
        return 0
    fi

    _generator="${DOTFILES_DIR}/${AI_ASSET_GENERATOR_REL}"
    _generated_manifest="${AI_ASSET_ROOT}/manifest.json"
    [ -f "$_generated_manifest" ] || return 0

    _generated_specs=$(mktemp)
    _TMPFILES="$_TMPFILES $_generated_specs"
    if [ "$MODE_DRY_RUN" = "true" ]; then
        if ! PYTHONDONTWRITEBYTECODE=1 python3 "$_generator" --repo "$DOTFILES_DIR" --output "$AI_ASSET_ROOT" --list-target "$_target" > "$_generated_specs"; then
            print_error "生成済み ${_target} asset manifest の読み込みに失敗しました"
            COUNT_ERROR=$((COUNT_ERROR + 1))
            return 1
        fi
    elif ! python3 "$_generator" --repo "$DOTFILES_DIR" --output "$AI_ASSET_ROOT" --list-target "$_target" > "$_generated_specs"; then
        print_error "生成済み ${_target} asset manifest の読み込みに失敗しました"
        COUNT_ERROR=$((COUNT_ERROR + 1))
        return 1
    fi
    cat "$_generated_specs" >> "$_spec_file"
}

runtime_stow_package() {
    _runtime="$1"
    _runtime_root="$2"
    _runtime_mode="$3"
    _runtime_filter="$4"
    _runtime_package="${_runtime}-runtime${AI_PROFILE_SUFFIX}"
    STOW_TARGET_DIR="$_runtime_root"
    if [ "$_runtime_filter" = shared ]; then
        _runtime_package="${_runtime}-shared${AI_PROFILE_SUFFIX}"
        STOW_TARGET_DIR="$HOME"
    fi
    new_stow_specs_file
    _runtime_specs="$_stow_specs_file"
    add_generated_ai_stow_specs "$_runtime_specs" "$_runtime" "$_runtime_package"
    if [ "$MODE_UNINSTALL" != true ]; then
        _runtime_filtered=$(mktemp)
        _TMPFILES="$_TMPFILES $_runtime_filtered"
        while IFS= read -r _runtime_spec; do
            _runtime_source=${_runtime_spec%%:*}
            _runtime_dest=${_runtime_spec#*:}
            case "$_runtime_dest" in
                ".${_runtime}/"*)
                    [ "$_runtime_filter" = runtime ] || continue
                    _runtime_dest=${_runtime_dest#*/}
                    ;;
                *) [ "$_runtime_filter" = shared ] || continue ;;
            esac
            printf '%s:%s\n' "$_runtime_source" "$_runtime_dest" >> "$_runtime_filtered"
        done < "$_runtime_specs"
        _runtime_specs="$_runtime_filtered"
    fi
    if [ "$_runtime_mode" = uninstall ]; then
        uninstall_stow_specs_file "$_runtime_package" "$_runtime_specs"
    else
        install_stow_specs_file "$_runtime_package" "$_runtime_specs"
    fi
    STOW_TARGET_DIR="$HOME"
}
