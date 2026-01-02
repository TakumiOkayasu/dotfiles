#!/bin/bash
# PostToolUse hook - ブランチ作成時にmainから分岐しているか確認

set -e

# Read JSON input from stdin
INPUT=$(cat)

# Extract command from tool_input
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")

# git checkout -b を検出 (新規ブランチ作成)
if echo "$COMMAND" | grep -qE 'git\s+checkout\s+-b'; then
    # git-new-feature を使っていない場合のみ警告
    # (git-new-feature は自動でmainから分岐するので問題ない)

    # 現在のブランチの親がmainか確認
    MAIN_BRANCH=$(git config --local --get claude.mainBranch 2>/dev/null || echo "main")
    CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")

    # 新しいブランチがmainから分岐しているか確認
    if [[ -n "$CURRENT_BRANCH" ]]; then
        MERGE_BASE=$(git merge-base "$MAIN_BRANCH" "$CURRENT_BRANCH" 2>/dev/null || echo "")
        MAIN_HEAD=$(git rev-parse "$MAIN_BRANCH" 2>/dev/null || echo "")

        if [[ "$MERGE_BASE" != "$MAIN_HEAD" ]]; then
            cat <<EOF
{
  "hookSpecificOutput": {
    "additionalContext": "[警告] ブランチが ${MAIN_BRANCH} の最新から分岐していない可能性があります。\n推奨: git-new-feature コマンドを使用してください。このコマンドは自動で ${MAIN_BRANCH} を最新化してからブランチを作成します。"
  }
}
EOF
        fi
    fi
fi

exit 0
