#!/bin/sh
# PreToolUse hook - 管理者権限コマンドをブロック
# sudo, --admin, -u root 等の実行を防止

# set -e を使わない（exit 1 = hookエラー = 許可扱いリスク）

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

[ -t 0 ] && exit 0

INPUT=$(cat)

# jaq優先、jqフォールバック（見つからない場合は空文字→許可）
JQ=$(command -v jaq 2>/dev/null || command -v jq 2>/dev/null || echo "")
if [ -z "$JQ" ]; then
    exit 0
fi

COMMAND=$(printf '%s\n' "$INPUT" | "$JQ" -r '.tool_input.command // ""' 2>/dev/null) || COMMAND=""

ADMIN_PATTERN='(^|[[:space:]])(sudo|su[[:space:]]+-|doas|pkexec)([[:space:]]|$)|(^|[[:space:]])--admin([[:space:]]|=|$)|(^|[[:space:]])-u[[:space:]]+root([[:space:]]|$)|(^|[[:space:]])--user(=|[[:space:]]+)root([[:space:]]|$)'

if printf '%s\n' "$COMMAND" | grep -qE "$ADMIN_PATTERN"; then
    echo "[管理者権限禁止] このコマンドには管理者権限が含まれています。ユーザーに確認してください。" >&2
    exit 2
fi

exit 0
