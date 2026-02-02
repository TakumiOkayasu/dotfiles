#!/bin/sh
# PostToolUse hook - ブランチ作成時にmainから分岐しているか確認
#
# 使い方 (手動実行):
#   echo '{"tool_input":{"command":"git checkout -b feat/test"}}' | ./branch-from-main-check.sh
#
# Claude Code hook として自動実行される場合は stdin から JSON を受け取る

set -e

# 手動実行時のヘルプ
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    cat <<'EOF'
branch-from-main-check.sh - ブランチがmainから分岐しているか確認

使い方:
  echo '{"tool_input":{"command":"git checkout -b feat/test"}}' | ./branch-from-main-check.sh

説明:
  Claude Code の PostToolUse hook として動作し、git checkout -b で
  作成されたブランチが main の最新から分岐しているか確認します。

  手動で実行する場合は、上記のように JSON を標準入力で渡してください。

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
    echo "使い方: echo '{\"tool_input\":{\"command\":\"git checkout -b feat/test\"}}' | $0" >&2
    echo "ヘルプ: $0 --help" >&2
    exit 1
fi

# Read JSON input from stdin
INPUT=$(cat)

# jaq優先、jqフォールバック
JQ=$(command -v jaq || command -v jq || echo "jq")

# Extract command from tool_input
COMMAND=$(echo "$INPUT" | $JQ -r '.tool_input.command // ""' 2>/dev/null || echo "")

# git checkout -b を検出 (新規ブランチ作成)
if echo "$COMMAND" | grep -qE 'git\s+checkout\s+-b'; then
    # 現在のブランチの親がmainか確認
    MAIN_BRANCH=$(git config --local --get claude.mainBranch 2>/dev/null || echo "main")
    CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")

    # 新しいブランチがmainから分岐しているか確認
    if [ -n "$CURRENT_BRANCH" ]; then
        MERGE_BASE=$(git merge-base "$MAIN_BRANCH" "$CURRENT_BRANCH" 2>/dev/null || echo "")
        MAIN_HEAD=$(git rev-parse "$MAIN_BRANCH" 2>/dev/null || echo "")

        if [ "$MERGE_BASE" != "$MAIN_HEAD" ]; then
            cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "[警告] ブランチが ${MAIN_BRANCH} の最新から分岐していない可能性があります。\n推奨: git-new-feature コマンドを使用してください。このコマンドは自動で ${MAIN_BRANCH} を最新化してからブランチを作成します。"
  }
}
EOF
            exit 0
        fi
    fi

    # 問題なし
    cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "[OK] ブランチは main の最新から分岐しています。"
  }
}
EOF
    exit 0
fi

# git checkout -b 以外のコマンドは何も出力しない (不要なコンテキスト追加を防ぐ)
exit 0
