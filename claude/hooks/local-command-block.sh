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

依存関係:
  jaq または jq が必要です (jaq優先)
  - macOS: brew install jaq
  - Ubuntu/Debian: apt install jq (または cargo install jaq)
  - Arch: pacman -S jq (または paru -S jaq)
  - Windows: scoop install jaq (または winget install jqlang.jq)
EOF
    exit 0
fi

if [ -t 0 ]; then
    echo "エラー: 標準入力がありません" >&2
    exit 1
fi

INPUT=$(cat)

# jaq優先、jqフォールバック
JQ=$(command -v jaq || command -v jq || echo "jq")

COMMAND=$(echo "$INPUT" | $JQ -r '.tool_input.command // ""' 2>/dev/null || echo "")

# ブロック対象のコマンドパターン
# python, python3, node, npm, npx, yarn, pnpm, php, ruby, go, perl, cargo, rustc
BLOCKED_PATTERN='\b(python[0-9.]*|node|npm|npx|yarn|pnpm|php|ruby|go|perl|cargo|rustc)\b'

# ブロック対象が含まれているかチェック
if echo "$COMMAND" | grep -qE "$BLOCKED_PATTERN"; then
    # Docker経由（docker exec/run/compose）の場合は許可
    # dockerがコマンドの先頭（cd後でもOK）にある場合のみ許可
    # 許可: `docker run python3`, `cd "/path with spaces" && docker run python3`
    # ブロック: `python3 && docker run`
    # [^;&|]+ でスペース含むパスや変数も対応
    if echo "$COMMAND" | grep -qE '^\s*(cd\s+[^;&|]+\s*(&&|;)\s*)*(docker\s+(exec|run|compose)|docker-compose)\b'; then
        exit 0
    fi
    echo "[ローカルコマンド禁止] このコマンドはDockerコンテナ内で実行してください。" >&2
    echo "例: docker exec <container> $COMMAND" >&2
    exit 2
fi

exit 0
