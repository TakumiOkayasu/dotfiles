#!/bin/sh
# PreToolUse hook - 長時間コマンドのrun_in_background確認

set -e

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    cat <<'EOF'
background-command-check.sh - 長時間コマンドのバックグラウンド実行チェック
EOF
    exit 0
fi

[ -t 0 ] && exit 1

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")
RUN_IN_BG=$(echo "$INPUT" | jq -r '.tool_input.run_in_background // false' 2>/dev/null || echo "false")

[ "$RUN_IN_BG" = "true" ] && exit 0

LONG_PATTERN='(^|\s)(go\s+(build|test|mod)|npm\s+(install|test|run|ci)|yarn(\s|$)|pnpm(\s|$)|cargo\s+(build|test)|make(\s|$)|cmake(\s|$)|gradle(\s|$)|mvn(\s|$)|pytest|phpunit|jest|mocha|docker\s+build|docker-compose\s+up|docker\s+compose\s+up)'

if echo "$COMMAND" | grep -qE "$LONG_PATTERN"; then
    echo "[警告] このコマンドは長時間かかる可能性があります。run_in_background=true を推奨します。" >&2
fi

exit 0
