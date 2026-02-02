#!/bin/sh
# PreToolUse hook - 管理者権限コマンドをブロック
# sudo, --admin, -u root 等の実行を防止

set -e

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    cat <<'EOF'
admin-command-block.sh - 管理者権限コマンドをブロック

使い方:
  echo '{"tool_input":{"command":"sudo apt update"}}' | ./admin-command-block.sh

説明:
  Claude Code の PreToolUse hook として動作し、sudo, su, doas 等の
  管理者権限コマンドを検出した場合に exit 2 でブロックします。

依存関係:
  jaq または jq が必要です (jaq優先)
  - macOS: brew install jaq
  - Ubuntu/Debian: apt install jq (または cargo install jaq)
  - Arch: pacman -S jq (または paru -S jaq)
  - Windows: scoop install jaq (または winget install jqlang.jq)
EOF
    exit 0
fi

[ -t 0 ] && exit 1

INPUT=$(cat)

# jaq優先、jqフォールバック
JQ=$(command -v jaq || command -v jq || echo "jq")

COMMAND=$(echo "$INPUT" | $JQ -r '.tool_input.command // ""' 2>/dev/null || echo "")

ADMIN_PATTERN='(^|\s)(sudo|su\s+-|doas|pkexec)(\s|$)|--admin(\s|=|$)|-u\s+root(\s|$)|--user[=\s]+root(\s|$)'

if echo "$COMMAND" | grep -qE "$ADMIN_PATTERN"; then
    echo "[管理者権限禁止] このコマンドには管理者権限が含まれています。ユーザーに確認してください。" >&2
    exit 2
fi

exit 0
