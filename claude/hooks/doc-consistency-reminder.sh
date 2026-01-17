#!/bin/sh
# Documentation consistency reminder - ドキュメント変更時の整合性チェックリマインド
#
# 使い方 (手動実行):
#   echo '{"tool_input":{"file_path":"README.md"}}' | ./doc-consistency-reminder.sh
#
# Claude Code hook として自動実行される場合は stdin から JSON を受け取る

set -e

# 手動実行時のヘルプ
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    cat <<'EOF'
doc-consistency-reminder.sh - ドキュメント変更時の整合性チェックリマインド

使い方:
  echo '{"tool_input":{"file_path":"README.md"}}' | ./doc-consistency-reminder.sh

説明:
  Claude Code の PostToolUse hook として動作し、ドキュメントファイル
  (.md, .rst, .txt, README, CLAUDE など) を変更した後に
  他のドキュメントとの整合性確認をリマインドします。
EOF
    exit 0
fi

# stdin がない場合のタイムアウト対策
if [ -t 0 ]; then
    echo "エラー: 標準入力がありません" >&2
    echo "使い方: echo '{\"tool_input\":{\"file_path\":\"README.md\"}}' | $0" >&2
    echo "ヘルプ: $0 --help" >&2
    exit 1
fi

# Read JSON input from stdin
INPUT=$(cat)

# Extract file path from tool_input
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null || echo "")

# Check if this is a documentation file
if echo "$FILE_PATH" | grep -qiE '\.(md|markdown|rst|txt)$|README|CLAUDE|SKILL'; then
    cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "[ドキュメント整合性チェック] ドキュメントを変更しました。以下を確認してください:\n- README.md: 機能一覧は最新か?\n- CLAUDE.md: 手順・コマンド名は正確か?\n- skills/: 関連スキルとの整合性\n- hooks/: リマインドメッセージとの整合性"
  }
}
EOF
    exit 0
fi

# ドキュメント以外は何も出力しない
exit 0
