#!/bin/bash
# session-start-reminder.sh - セッション開始時のリマインダー
#
# 責務:
#   - セッション開始メッセージの表示
#   - リマインダーの表示
#   - claude-config-info.sh の呼び出し
#
# 配置先: claude-config/hooks/session-start-reminder.sh
#         -> ~/.claude/hooks/session-start-reminder.sh (symlink)

set -euo pipefail

# ============================================================================
# 設定
# ============================================================================

# claude-config-info.sh の検索
# シンボリックリンク解決して dotfiles の bin を探す
find_config_info_script() {
    local script_path="${BASH_SOURCE[0]}"
    
    # シンボリックリンクを解決
    while [[ -L "$script_path" ]]; do
        local dir="$(cd -P "$(dirname "$script_path")" && pwd)"
        script_path="$(readlink "$script_path")"
        [[ "$script_path" != /* ]] && script_path="$dir/$script_path"
    done
    
    local hooks_dir="$(cd -P "$(dirname "$script_path")" && pwd)"
    local claude_config_dir="$(dirname "$hooks_dir")"
    local bin_dir="$claude_config_dir/bin"
    
    # 検索順序:
    # 1. claude-config/bin/ (dotfiles)
    # 2. ~/.claude/bin/
    # 3. ~/.local/bin/
    for dir in "$bin_dir" "$HOME/.claude/bin" "$HOME/.local/bin"; do
        if [[ -x "$dir/claude-config-info.sh" ]]; then
            echo "$dir/claude-config-info.sh"
            return 0
        fi
    done
    
    return 1
}

CONFIG_INFO_SCRIPT=""
if script=$(find_config_info_script 2>/dev/null); then
    CONFIG_INFO_SCRIPT="$script"
fi

# ============================================================================
# メイン出力
# ============================================================================

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║              Claude Code Session Started                       ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# ----------------------------------------------------------------------------
# リマインダー
# ----------------------------------------------------------------------------

echo "📋 REMINDERS:"
echo "  1. Read CLAUDE.md before starting any task"
echo "  2. Create a new branch before coding (no work on main)"
echo "  3. Test-first approach (RED-GREEN-REFACTOR)"
echo "  4. Consult before implementing if unclear"
echo "  5. Check ~/.claude/skills/ for available skills"
echo ""

# ----------------------------------------------------------------------------
# 設定情報 (claude-config-info.sh を呼び出し)
# ----------------------------------------------------------------------------

if [[ -n "$CONFIG_INFO_SCRIPT" ]]; then
    "$CONFIG_INFO_SCRIPT" --all
else
    echo "⚠️  claude-config-info.sh not found"
    echo "   Expected location: ~/.claude/bin/claude-config-info.sh"
    echo ""
fi

# ----------------------------------------------------------------------------
# フッター
# ----------------------------------------------------------------------------

echo "════════════════════════════════════════════════════════════════"
echo ""
