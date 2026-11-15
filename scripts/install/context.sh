# shellcheck shell=sh

# 一時ファイル cleanup
# shellcheck disable=SC2329 # invoked by the EXIT trap below
cleanup_tmpfiles() {
    for _f in $_TMPFILES; do
        rm -f "$_f"
    done
    [ -z "$_AI_ASSET_STAGE" ] || rm -rf "$_AI_ASSET_STAGE"
    [ -z "$_AI_ASSET_STAGE_PARENT_CREATED" ] || rmdir "$_AI_ASSET_STAGE_PARENT_CREATED" 2>/dev/null || true
}

initialize_installer() {
    _TMPFILES=""
    _AI_ASSET_STAGE=""
    _AI_ASSET_STAGE_PARENT_CREATED=""
    trap cleanup_tmpfiles EXIT INT TERM

    # 定数・設定
    DOTFILES_DIR="$1"
    CLAUDE_CONFIG_ROOT="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
    CODEX_CONFIG_ROOT="${CODEX_HOME:-$HOME/.codex}"
    STOW_TARGET_DIR="$HOME"

    for _runtime_root in "$CLAUDE_CONFIG_ROOT" "$CODEX_CONFIG_ROOT"; do
        case "$_runtime_root" in
            /*) ;;
            *) printf 'runtime config directory must be absolute: %s\n' "$_runtime_root" >&2; exit 2 ;;
        esac
    done

    MODE_INTERACTIVE=true
    MODE_DRY_RUN=false
    MODE_UNINSTALL=false

    COUNT_CREATED=0
    COUNT_SKIPPED=0
    COUNT_BACKUP=0
    COUNT_REMOVED=0
    COUNT_ERROR=0

    SHELL_SELECTED=false
    SHELL_TYPE=""
    SHELL_COMPONENTS=""
    GIT_SELECTED=false
    VIM_SELECTED=false
    BIN_SELECTED=false
    CLAUDE_SELECTED=false
    CODEX_SELECTED=false
    GITCONFIG_VARIANT=""

    UNINSTALL_SHELL=false
    UNINSTALL_GIT=false
    UNINSTALL_VIM=false
    UNINSTALL_BIN=false
    UNINSTALL_CLAUDE=false
    UNINSTALL_CODEX=false

    VENDOR_SKILLS="composition-patterns react-best-practices web-design-guidelines"
    COMMON_HOOKS="common/hooks"
    AI_ASSET_GENERATOR_REL="scripts/generate-ai-assets.py"
    AI_ASSET_ROOT_REL=".generated/ai-assets"
    AI_ASSET_ROOT="${DOTFILES_DIR}/${AI_ASSET_ROOT_REL}"
    AI_PROFILE_SUFFIX=""

    DOTWORK_MARKER_BEGIN="# === dotfile-work: BEGIN ==="
    DOTWORK_MARKER_END="# === dotfile-work: END ==="

    # カラー出力
    if [ -t 1 ]; then
        COLOR_GREEN=$(printf '\033[0;32m')
        COLOR_YELLOW=$(printf '\033[0;33m')
        COLOR_RED=$(printf '\033[0;31m')
        COLOR_BLUE=$(printf '\033[0;34m')
        COLOR_CYAN=$(printf '\033[0;36m')
        COLOR_BOLD=$(printf '\033[1m')
        COLOR_RESET=$(printf '\033[0m')
    else
        COLOR_GREEN=''
        COLOR_YELLOW=''
        COLOR_RED=''
        COLOR_BLUE=''
        COLOR_CYAN=''
        COLOR_BOLD=''
        COLOR_RESET=''
    fi
}
