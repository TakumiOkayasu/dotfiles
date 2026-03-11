#!/bin/sh
# PreToolUse hook - git commit/push および破壊的操作をブロック
# CLAUDE.mdルール: git commit/push はユーザーのみ操作可能
#
# 使い方 (手動実行):
#   echo '{"tool_input":{"command":"git commit -m test"}}' | ./git-commit-push-block.sh
#
# Claude Code hook として自動実行される場合は stdin から JSON を受け取る

# set -e を使わない（exit 1 = hookエラー = 許可扱いリスク）

# 手動実行時のヘルプ
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    cat <<'EOF'
git-commit-push-block.sh - git commit/push および破壊的操作をブロック

使い方:
  echo '{"tool_input":{"command":"git commit -m test"}}' | ./git-commit-push-block.sh

説明:
  Claude Code の PreToolUse hook として動作し、以下を検出した場合に
  exit 2 でブロックします。
  - git commit / git push (ユーザーのみ操作可能)
  - git reset --hard / git clean -f / git checkout -- . / git restore (破壊的操作)

依存関係:
  jaq または jq が必要です (jaq優先)
  - macOS: brew install jaq
  - Ubuntu/Debian: apt install jq (または cargo install jaq)
  - Arch: pacman -S jq (または paru -S jaq)
  - Windows: scoop install jaq (または winget install jqlang.jq)
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

# jaq優先、jqフォールバック（見つからない場合は空文字→許可）
JQ=$(command -v jaq 2>/dev/null || command -v jq 2>/dev/null || echo "")
if [ -z "$JQ" ]; then
    exit 0
fi

# Extract command from tool_input
COMMAND=$(printf '%s\n' "$INPUT" | "$JQ" -r '.tool_input.command // ""' 2>/dev/null) || COMMAND=""

# git commit/push を検出
# コマンド内のどこにあっても検出（セキュリティ優先）
# 対応: 直接実行, チェーン(; && ||), パイプ(|), サブシェル($() ``), グループ(() {}), 制御構文(then do else)
if printf '%s\n' "$COMMAND" | grep -qE '\bgit\s+(commit|push)(\s|$)'; then
    echo "[CLAUDE.md ルール違反] git commit/push はユーザーのみ操作可能です。コミットの準備ができたらユーザーに依頼してください。" >&2
    exit 2
fi

# 破壊的 git 操作を検出 (git push は上でブロック済み)
if printf '%s\n' "$COMMAND" | grep -qE '\bgit\s+reset\b' && printf '%s\n' "$COMMAND" | grep -qE -- '--hard\b'; then
    echo "[安全ガード] git reset --hard は禁止されています。" >&2
    exit 2
fi
if printf '%s\n' "$COMMAND" | grep -qE '\bgit\s+clean\s+-[a-zA-Z]*f'; then
    echo "[安全ガード] git clean -f は禁止されています。" >&2
    exit 2
fi
if printf '%s\n' "$COMMAND" | grep -qE '\bgit\s+checkout\s+--\s*\.'; then
    echo "[安全ガード] git checkout -- . は禁止されています。" >&2
    exit 2
fi
if printf '%s\n' "$COMMAND" | grep -qE '\bgit\s+restore\s+'; then
    echo "[安全ガード] git restore は禁止されています。" >&2
    exit 2
fi

exit 0
