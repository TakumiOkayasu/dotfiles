#!/bin/sh
# primary-source-check.sh - 実装指示時の一次ソース確認チェックリスト (UserPromptSubmit)
#
# 責務:
#   - ユーザーの入力が実装・修正指示を含む場合にチェックリストを表示
#   - Codexのコンテキストに一次ソース確認を注入
#
# 配置先: codex/hooks/primary-source-check.sh

[ "${CODEX_PRIMARY_SOURCE_CHECK_MODE:-}" = "quiet" ] && exit 0

# stdin がない場合はスキップ
if [ -t 0 ]; then
    exit 0
fi

INPUT=$(cat)

# jaq優先、jqフォールバック
JQ=$(command -v jaq 2>/dev/null || command -v jq 2>/dev/null || echo "")
if [ -z "$JQ" ]; then
    exit 0
fi

PROMPT=$(printf '%s\n' "$INPUT" | "$JQ" -r '.prompt // ""' 2>/dev/null) || PROMPT=""

if [ -z "$PROMPT" ]; then
    exit 0
fi

# 実装・修正系キーワードの検出
case "$PROMPT" in
    *実装*|*修正*|*追加*|*変更*|*作成*|*削除*|*更新*|*fix*|*feat*|*add*|*update*|*create*|*delete*|*remove*|*カラム*|*テーブル*|*API*|*エンドポイント*)
        cat <<'CHECKLIST'
⚠️ [一次ソース確認] 実装前に以下を**必ず**確認してください:
    - [ ] DB名/カラム名は実際に存在するか？
    - [ ] API/関数は実際に存在するか？
    - ❌**推測は厳禁**
CHECKLIST
        ;;
esac

exit 0
