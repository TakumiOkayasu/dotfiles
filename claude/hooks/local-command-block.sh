#!/bin/sh
# PreToolUse hook - ローカル環境のコマンド実行をブロック
# Dockerコンテナ内で実行するべきコマンドを直接実行しようとした場合にブロック
#
# 使い方 (手動実行):
#   echo '{"tool_input":{"command":"python3 script.py"}}' | ./local-command-block.sh

set -e

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    cat <<'EOF'
local-command-block.sh - ローカル環境のコマンド実行をブロック

使い方:
  echo '{"tool_input":{"command":"python3 script.py"}}' | ./local-command-block.sh

説明:
  Python, Node.js, PHP, Ruby, Go などのコマンドを
  Docker外で直接実行しようとした場合にブロックします。
  docker exec/run/compose 経由の実行は許可されます。
EOF
    exit 0
fi

if [ -t 0 ]; then
    echo "エラー: 標準入力がありません" >&2
    exit 1
fi

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")

# Docker経由の実行は許可
if echo "$COMMAND" | grep -qE '^\s*(docker\s+(exec|run|compose)|docker-compose)'; then
    exit 0
fi

# ブロック対象のコマンドパターン
# python, python3, node, npm, npx, yarn, pnpm, php, ruby, go, perl, cargo, rustc
BLOCKED_PATTERN='^\s*(python[0-9.]*|node|npm|npx|yarn|pnpm|php|ruby|go|perl|cargo|rustc)(\s|$)'

if echo "$COMMAND" | grep -qE "$BLOCKED_PATTERN"; then
    echo "[ローカルコマンド禁止] このコマンドはDockerコンテナ内で実行してください。" >&2
    echo "例: docker exec <container> $COMMAND" >&2
    exit 2
fi

exit 0
