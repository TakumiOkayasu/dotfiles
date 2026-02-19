#!/bin/sh
# PreToolUse hook - 長時間コマンドのrun_in_background確認

# set -e を使わない（exit 1 = hookエラー = 許可扱いリスク）

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    cat <<'EOF'
background-command-check.sh - 長時間コマンドのバックグラウンド実行チェック

使い方:
  echo '{"tool_input":{"command":"npm install"}}' | ./background-command-check.sh

説明:
  Claude Code の PreToolUse hook として動作し、npm install, cargo build 等の
  長時間コマンドに対して run_in_background=true を推奨します。

依存関係:
  jaq または jq が必要です (jaq優先)
  - macOS: brew install jaq
  - Ubuntu/Debian: apt install jq (または cargo install jaq)
  - Arch: pacman -S jq (または paru -S jaq)
  - Windows: scoop install jaq (または winget install jqlang.jq)
EOF
    exit 0
fi

[ -t 0 ] && exit 0

INPUT=$(cat)

# jaq優先、jqフォールバック（見つからない場合は空文字→許可）
JQ=$(command -v jaq 2>/dev/null || command -v jq 2>/dev/null || echo "")
if [ -z "$JQ" ]; then
    exit 0
fi

COMMAND=$(printf '%s\n' "$INPUT" | "$JQ" -r '.tool_input.command // ""' 2>/dev/null) || COMMAND=""
RUN_IN_BG=$(printf '%s\n' "$INPUT" | "$JQ" -r '.tool_input.run_in_background // false' 2>/dev/null) || RUN_IN_BG="false"

[ "$RUN_IN_BG" = "true" ] && exit 0

LONG_PATTERN='(^|\s)(go\s+(build|test|mod)|npm\s+(install|test|run|ci)|yarn(\s|$)|pnpm(\s|$)|cargo\s+(build|test)|make(\s|$)|cmake(\s|$)|gradle(\s|$)|mvn(\s|$)|pytest|phpunit|jest|mocha|docker\s+build|docker-compose\s+up|docker\s+compose\s+up)'

if printf '%s\n' "$COMMAND" | grep -qE "$LONG_PATTERN"; then
    echo "[警告] このコマンドは長時間かかる可能性があります。run_in_background=true を推奨します。" >&2
fi

exit 0
