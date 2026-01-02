#!/bin/bash
# Documentation consistency reminder - ドキュメント変更時の整合性チェックリマインド

set -e

# Read JSON input from stdin
INPUT=$(cat)

# Extract file path from tool_input
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null || echo "")

# Check if this is a documentation file
if echo "$FILE_PATH" | grep -qiE '\.(md|markdown|rst|txt)$|README|CLAUDE|SKILL'; then
    cat <<'EOF'
{
  "hookSpecificOutput": {
    "additionalContext": "[ドキュメント整合性チェック] ドキュメントを変更しました。以下を確認してください:\n- README.md: 機能一覧は最新か?\n- CLAUDE.md: 手順・コマンド名は正確か?\n- skills/: 関連スキルとの整合性\n- hooks/: リマインドメッセージとの整合性"
  }
}
EOF
fi

exit 0
