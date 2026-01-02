#!/bin/bash
# PreToolUse hook - git commit/push をブロック
# CLAUDE.mdルール: git commit/push はユーザーのみ操作可能

set -e

# Read JSON input from stdin
INPUT=$(cat)

# Extract command from tool_input
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")

# git commit または git push を検出
if echo "$COMMAND" | grep -qE '^\s*git\s+(commit|push)(\s|$)'; then
    # exit 2 でブロック、stderr にメッセージ
    echo "[CLAUDE.md ルール違反] git commit/push はユーザーのみ操作可能です。コミットの準備ができたらユーザーに依頼してください。" >&2
    exit 2
fi

exit 0
