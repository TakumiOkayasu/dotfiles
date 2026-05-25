#!/bin/sh
# primary-source-reminder.sh - 一次ソース確認リマインド (SessionStart)
#
# 責務:
#   - セッション開始時に「推測でコードを書かない」リマインドを表示
#   - 一次ソースの確認先一覧を表示
#
# 配置先: codex/hooks/primary-source-reminder.sh

echo ""
echo "🔍 一次ソース確認リマインダー:"
echo "  **必ず一次ソースを確認すること**"
echo "  **確認後一次ソースの確認先を出力すること**"
echo "  ❌**推測禁止**"
echo ""

exit 0
