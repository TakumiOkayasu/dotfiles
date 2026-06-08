#!/bin/sh
# session-start-reminder.sh - セッション開始時のリマインダー
#
# 責務:
#   - セッション開始メッセージの表示
#   - リマインダーの表示
#   - claude-config-info.sh の呼び出し
#   - project-environment-check.sh の呼び出し
#
# 配置先: claude-config/hooks/session-start-reminder.sh
#         -> ~/.claude/hooks/session-start-reminder.sh (symlink)

# set -e を使わない（exit 1 = hookエラー = 許可扱いリスク）

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
echo "  5. Check ${HOME}/.claude/rules/ and ${HOME}/.claude/skills/"
echo ""

if [ -n "$CONFIG_INFO_SCRIPT" ]; then
    "$CONFIG_INFO_SCRIPT" --all
else
    echo "⚠️  claude-config-info.sh not found"
    echo "   Expected: ${HOME}/.claude/bin/claude-config-info.sh"
    echo ""
fi

# ルールファイルを列挙 (常時適用)
RULES_DIR="$HOME/.claude/rules"
if [ -d "$RULES_DIR" ]; then
    rules=$(find "$RULES_DIR" -maxdepth 1 -name "*.md" \( -type f -o -type l \) 2>/dev/null | \
        sed 's|.*/||; s|\.md$||' | \
        sort | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')
    if [ -n "$rules" ]; then
        echo "📏 RULES (always loaded):"
        echo "  $rules"
        echo ""
    fi
fi

# スキルファイルを列挙 (オンデマンド)
SKILLS_DIR="$HOME/.claude/skills"
if [ -d "$SKILLS_DIR" ]; then
    skills=$(find "$SKILLS_DIR" -maxdepth 2 -name "SKILL.md" \( -type f -o -type l \) 2>/dev/null | \
        sed 's|.*/\([^/]*\)/SKILL\.md|\1|' | \
        sort | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')
    if [ -n "$skills" ]; then
        echo "📚 SKILLS (read as needed):"
        echo "  $skills"
        echo ""
    else
        echo "📚 AVAILABLE SKILLS:"
        echo "  No skills found in $SKILLS_DIR"
        echo ""
    fi
fi

# Vendor skills auto-update (throttled to 24h)
SKILLS_UPDATE="$HOME/.claude/bin/skills-update.sh"
if [ -x "$SKILLS_UPDATE" ]; then
    skills_result=$("$SKILLS_UPDATE" --quiet 2>&1) || true
    if [ -n "$skills_result" ]; then
        echo "$skills_result"
        echo ""
    fi
fi

# プロジェクト環境チェック（Docker/Git/hookルール）
SCRIPT_DIR=$(dirname "$0")
if [ -x "$SCRIPT_DIR/project-environment-check.sh" ]; then
    "$SCRIPT_DIR/project-environment-check.sh"
fi
