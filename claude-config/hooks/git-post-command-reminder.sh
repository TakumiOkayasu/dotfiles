#!/bin/bash
# Git command post-hook - ブランチ関連操作後のリマインド

set -e

# Read JSON input from stdin
INPUT=$(cat)

# Extract command from tool_input
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")

# Check if this is a git-related command
if echo "$COMMAND" | grep -qE '^git\s+'; then

    # PRマージ検出 (gh pr merge, git pull after merge)
    if echo "$COMMAND" | grep -qE '(gh\s+pr\s+merge|git\s+pull)'; then
        cat <<'EOF'
{
  "hookSpecificOutput": {
    "additionalContext": "[CLAUDE.md リマインド] PRマージ/pull検出: マージされたブランチがあれば、ユーザーに「マージされたブランチ [ブランチ名] を削除しますか?」と確認してください。"
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
    "additionalContext": "[CLAUDE.md リマインド] mainブランチに移動しました。マージ済みのブランチがあれば削除確認をユーザーに行ってください。"
  }
}
EOF
        exit 0
    fi

    # git branch -d 検出 (ブランチ削除)
    if echo "$COMMAND" | grep -qE 'git\s+branch\s+-[dD]'; then
        cat <<'EOF'
{
  "hookSpecificOutput": {
    "additionalContext": "[CLAUDE.md リマインド] ブランチ削除が実行されました。削除完了を報告してください。"
  }
}
EOF
        exit 0
    fi
fi

# No reminder needed
exit 0
