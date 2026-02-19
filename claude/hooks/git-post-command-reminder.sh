#!/bin/sh
# Git command post-hook - ブランチ関連操作後のリマインド・自動削除
#
# 使い方 (手動実行):
#   echo '{"tool_input":{"command":"git pull"}}' | ./git-post-command-reminder.sh
#
# Claude Code hook として自動実行される場合は stdin から JSON を受け取る

# set -e を使わない（exit 1 = hookエラー = サイレント停止リスク）

# 手動実行時のヘルプ
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    cat <<'EOF'
git-post-command-reminder.sh - Git操作後のリマインド・自動削除

使い方:
  echo '{"tool_input":{"command":"git pull"}}' | ./git-post-command-reminder.sh

対応コマンド:
  - git pull / gh pr merge: マージ済みローカルブランチを自動削除
  - git checkout main: ブランチ削除のリマインド
  - git-cleanup-branch: 削除完了の報告

依存関係:
  jaq または jq が必要です (jaq優先)
  - macOS: brew install jaq
  - Ubuntu/Debian: apt install jq (または cargo install jaq)
  - Arch: pacman -S jq (または paru -S jaq)
  - Windows: scoop install jaq (または winget install jqlang.jq)
EOF
    exit 0
fi

# stdin がない場合のタイムアウト対策 (POSIX互換)
if [ -t 0 ]; then
    echo "エラー: 標準入力がありません" >&2
    echo "使い方: echo '{\"tool_input\":{\"command\":\"git pull\"}}' | $0" >&2
    echo "ヘルプ: $0 --help" >&2
    exit 1
fi

# Read JSON input from stdin
INPUT=$(cat)

# jaq優先、jqフォールバック（見つからない場合は空文字→許可）
JQ=$(command -v jaq 2>/dev/null || command -v jq 2>/dev/null || echo "")
if [ -z "$JQ" ]; then
    exit 0
fi

# Extract command and cwd from tool_input
COMMAND=$(printf '%s\n' "$INPUT" | "$JQ" -r '.tool_input.command // ""' 2>/dev/null) || COMMAND=""
CWD=$(printf '%s\n' "$INPUT" | "$JQ" -r '.cwd // ""' 2>/dev/null) || CWD=""

# CWD が指定されていればそこに移動（別プロジェクト対応）
if [ -n "$CWD" ] && [ -d "$CWD" ]; then
    cd "$CWD" 2>/dev/null || true
fi

# PRマージ/pull検出 - マージ済みローカルブランチを自動削除
if printf '%s\n' "$COMMAND" | grep -qE '(gh\s+pr\s+merge|git\s+pull)'; then
    # mainブランチにいる場合のみ自動削除
    CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
    MAIN_BRANCH=$(git config --local --get claude.mainBranch 2>/dev/null || echo "main")

    if [ "$CURRENT_BRANCH" = "$MAIN_BRANCH" ]; then
        # マージ済みブランチを検出
        MERGED_BRANCHES=$(git branch --merged "$MAIN_BRANCH" 2>/dev/null | grep -vE "^\*|^\s*(main|master)\s*$" | tr -d ' ' || echo "")

        if [ -n "$MERGED_BRANCHES" ]; then
            # 削除実行
            DELETED=""
            for branch in $MERGED_BRANCHES; do
                if git branch -d "$branch" 2>/dev/null; then
                    DELETED="${DELETED}${branch}, "
                fi
            done

            if [ -n "$DELETED" ]; then
                DELETED=$(echo "$DELETED" | sed 's/, $//')
                cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "[自動削除] マージ済みローカルブランチを削除しました: ${DELETED}"
  }
}
EOF
                exit 0
            fi
        fi
    fi

    # 自動削除対象がない場合はリマインドのみ
    cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "[CLAUDE.md リマインド] PRマージ/pull検出: mainブランチでgit pullするとマージ済みローカルブランチが自動削除されます。"
  }
}
EOF
    exit 0
fi

# git checkout main/master 検出 (マージ後のmain移動)
if printf '%s\n' "$COMMAND" | grep -qE 'git\s+checkout\s+(main|master)'; then
    cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "[CLAUDE.md リマインド] mainブランチに移動しました。マージ済みのブランチがあれば git-cleanup-branch で削除確認をユーザーに行ってください。"
  }
}
EOF
    exit 0
fi

# git-cleanup-branch 検出
if printf '%s\n' "$COMMAND" | grep -qE 'git-cleanup-branch'; then
    cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "[CLAUDE.md リマインド] ブランチ削除が実行されました。削除完了を報告してください。"
  }
}
EOF
    exit 0
fi

# No reminder needed
exit 0
