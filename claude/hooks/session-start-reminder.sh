#!/bin/sh
# session-start-reminder.sh - セッション開始時のリマインダー
#
# 責務:
#   - セッション開始メッセージの表示
#   - リマインダーの表示
#   - claude-config-info.sh の呼び出し
#
# 配置先: claude-config/hooks/session-start-reminder.sh
#         -> ~/.claude/hooks/session-start-reminder.sh (symlink)

set -eu

# claude-config-info.sh を検索
find_config_info_script() {
    for dir in "$HOME/.claude/bin" "$HOME/.local/bin"; do
        if [ -x "$dir/claude-config-info.sh" ]; then
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

# メイン出力
echo ""
echo "🚀 Claude Code Session Started"
echo ""
echo "📋 REMINDERS:"
echo "  1. Read CLAUDE.md before starting any task"
echo "  2. Create a new branch before coding (no work on main)"
echo "  3. Test-first approach (RED-GREEN-REFACTOR)"
echo "  4. Consult before implementing if unclear"
echo "  5. Check ~/.claude/skills/ for available skills"
echo ""

if [ -n "$CONFIG_INFO_SCRIPT" ]; then
    "$CONFIG_INFO_SCRIPT" --all
else
    echo "⚠️  claude-config-info.sh not found"
    echo "   Expected: ~/.claude/bin/claude-config-info.sh"
    echo ""
fi
