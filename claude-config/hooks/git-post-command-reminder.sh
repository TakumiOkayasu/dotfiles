#!/bin/bash
# Git command post-hook - ブランチ関連操作後のリマインド

set -e

# Read JSON input from stdin
INPUT=$(cat)

# Extract command from tool_input
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")

# PRマージ検出 (gh pr merge, git pull after merge)
if echo "$COMMAND" | grep -qE '(gh\s+pr\s+merge|git\s+pull)'; then
    cat <<'EOF'
{
  "hookSpecificOutput": {
    "additionalContext": "[CLAUDE.md リマインド] PRマージ/pull検出: マージされたブランチがあれば、ユーザーに「git-cleanup-branch でブランチを削除しますか?」と確認してください。"
  }
}
EOF
    exit 0
fi

# git checkout main/master 検出 (マージ後のmain移動)
if echo "$COMMAND" | grep -qE 'git\s+checkout\s+(main|master)'; then
    cat <<'EOF'
{
  "hookSpecificOutput": {
    "additionalContext": "[CLAUDE.md リマインド] mainブランチに移動しました。マージ済みのブランチがあれば git-cleanup-branch で削除確認をユーザーに行ってください。"
  }
}
EOF
    exit 0
fi

# git-cleanup-branch 検出
if echo "$COMMAND" | grep -qE 'git-cleanup-branch'; then
    cat <<'EOF'
{
  "hookSpecificOutput": {
    "additionalContext": "[CLAUDE.md リマインド] ブランチ削除が実行されました。削除完了を報告してください。"
  }
}
EOF
    exit 0
fi

# No reminder needed
exit 0
