#!/bin/sh
# ~/.claude/hooks/failure-check.sh
# PostToolUse Hook: 失敗パターン検出→相談提案

# 設定
FAILURE_THRESHOLD=2
FAILURE_LOG="claude_tmp/failure_log.md"

# 失敗ログが存在しない場合は終了
if [ ! -f "$FAILURE_LOG" ]; then
    exit 0
fi

# 直近のエラー行を取得
LAST_LINES=$(tail -n "$FAILURE_THRESHOLD" "$FAILURE_LOG" 2>/dev/null)

# 行数チェック
LINE_COUNT=$(echo "$LAST_LINES" | wc -l)
if [ "$LINE_COUNT" -lt "$FAILURE_THRESHOLD" ]; then
    exit 0
fi

# 同じエラーが繰り返されているかチェック
UNIQUE_LINES=$(echo "$LAST_LINES" | sort -u | wc -l)

if [ "$UNIQUE_LINES" -eq 1 ]; then
    cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "[警告] 同じエラーが${FAILURE_THRESHOLD}回発生しました。\\n相談を実行: consult --check\\nまたは直接: consult \"エラーの原因を教えて\""
  }
}
EOF
fi
