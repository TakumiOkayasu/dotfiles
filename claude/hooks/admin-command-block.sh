#!/bin/sh
# PreToolUse hook - 管理者権限コマンドをブロック
# sudo, --admin, -u root 等の実行を防止

set -e

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    cat <<'EOF'
admin-command-block.sh - 管理者権限コマンドをブロック
EOF
    exit 0
fi

[ -t 0 ] && exit 1

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")

ADMIN_PATTERN='(^|\s)(sudo|su\s+-|doas|pkexec)(\s|$)|--admin(\s|=|$)|-u\s+root(\s|$)|--user[=\s]+root(\s|$)'

if echo "$COMMAND" | grep -qE "$ADMIN_PATTERN"; then
    echo "[管理者権限禁止] このコマンドには管理者権限が含まれています。ユーザーに確認してください。" >&2
    exit 2
fi

exit 0
