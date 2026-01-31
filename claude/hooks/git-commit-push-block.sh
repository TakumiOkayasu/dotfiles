#!/bin/sh
# PreToolUse hook - git commit/push をブロック
# CLAUDE.mdルール: git commit/push はユーザーのみ操作可能
#
# 使い方 (手動実行):
#   echo '{"tool_input":{"command":"git commit -m test"}}' | ./git-commit-push-block.sh
#
# Claude Code hook として自動実行される場合は stdin から JSON を受け取る

set -e

# 手動実行時のヘルプ
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    cat <<'EOF'
git-commit-push-block.sh - git commit/push をブロック

使い方:
  echo '{"tool_input":{"command":"git commit -m test"}}' | ./git-commit-push-block.sh

説明:
  Claude Code の PreToolUse hook として動作し、git commit/push を
  検出した場合に exit 2 でブロックします。
  CLAUDE.md ルール: git commit/push はユーザーのみ操作可能
EOF
    exit 0
fi

# stdin がない場合のタイムアウト対策
if [ -t 0 ]; then
    echo "エラー: 標準入力がありません" >&2
    echo "使い方: echo '{\"tool_input\":{\"command\":\"git commit -m test\"}}' | $0" >&2
    echo "ヘルプ: $0 --help" >&2
    exit 1
fi

# Read JSON input from stdin
INPUT=$(cat)

# Extract command from tool_input
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")

# git commit または git push を検出
# コマンド内のどこにあっても検出（セキュリティ優先）
# 対応: 直接実行, チェーン(; && ||), パイプ(|), サブシェル($() ``), グループ(() {}), 制御構文(then do else)
if echo "$COMMAND" | grep -qE '\bgit\s+(commit|push)(\s|$)'; then
    # exit 2 でブロック、stderr にメッセージ
    echo "[CLAUDE.md ルール違反] git commit/push はユーザーのみ操作可能です。コミットの準備ができたらユーザーに依頼してください。" >&2
    exit 2
fi

exit 0
