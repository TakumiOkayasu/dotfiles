#!/bin/sh
# session-start-reminder.sh - セッション開始時のリマインダー
#
# 責務:
#   - セッション開始メッセージの表示
#   - リマインダーの表示
#   - codex-config-info.sh の呼び出し
#
# 配置先: codex-config/hooks/session-start-reminder.sh
#         -> codex/hooks/session-start-reminder.sh (symlink)

# set -e を使わない（exit 1 = hookエラー = 許可扱いリスク）

if SCRIPT_DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd -P); then
    :
else
    SCRIPT_DIR=$(dirname "$0")
fi
CODEX_DIR=$(cd "$SCRIPT_DIR/.." 2>/dev/null && pwd -P || echo "${HOME}/.codex")

# codex-config-info.sh を検索
find_config_info_script() {
    for dir in "$CODEX_DIR/bin" "$HOME/.codex/bin" "codex/bin" "$HOME/.local/bin"; do
        if [ -x "$dir/codex-config-info.sh" ]; then
            echo "$dir/codex-config-info.sh"
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
echo "🚀 Codex セッション開始"
echo ""
echo "📋 リマインダー:"
echo "  1. 必要なら AGENTS.md / SUBAGENTS.md を確認"
echo "  2. 編集が必要なら作業ブランチを確認"
echo "  3. 実装変更は RED-GREEN-REFACTOR を優先"
echo "  4. 不明点は一次ソース確認後に相談"
echo "  5. rules / skills は参照資料として必要時に読む"
echo ""

if [ -n "$CONFIG_INFO_SCRIPT" ]; then
    "$CONFIG_INFO_SCRIPT" --all
else
    echo "⚠️  codex-config-info.sh が見つかりません"
    echo "   期待場所: ~/.codex/bin/codex-config-info.sh"
    echo ""
fi

# ルールファイルを列挙 (参照資料)
RULES_DIR="$CODEX_DIR/rules"
if [ -d "$RULES_DIR" ]; then
    rules=$(find "$RULES_DIR" -maxdepth 1 -name "*.md" \( -type f -o -type l \) 2>/dev/null | \
        sed 's|.*/||; s|\.md$||' | \
        sort | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')
    if [ -n "$rules" ]; then
        echo "📏 RULES (reference):"
        echo "  $rules"
        echo ""
    fi
fi

# スキル一覧は codex-config-info.sh が .agents / .codex を集約して表示する。
