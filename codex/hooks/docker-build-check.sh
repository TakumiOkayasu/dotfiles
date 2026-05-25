#!/bin/sh
# docker-build-check.sh - ビルド/インストールコマンドのDocker外実行を警告
#
# 責務:
#   - パッケージマネージャ/ビルドツールの検知 (ツール+アクション方式)
#   - 許可コマンドの早期判定 (case文で高速)
#
# 発動: PreToolUse (Bash)
# 依存: jaq or jq

# set -e を使わない（exit 1 = hookエラー = 許可扱いリスク）

if [ -t 0 ]; then
    exit 0
fi

INPUT=$(cat)

JQ=$(command -v jaq 2>/dev/null || command -v jq 2>/dev/null || echo "")
if [ -n "$JQ" ]; then
    CMD=$(printf '%s\n' "$INPUT" | "$JQ" -r '.tool_input.command // ""' 2>/dev/null) || CMD=""
else
    CMD=""
fi

[ -z "$CMD" ] && exit 0

# --- Fast path: case (shell built-in, subprocess なし) ---

# ブロック: git commit/push (destructive-command-block.sh と二重チェック)
case "$CMD" in
    "git commit"|"git commit "*|*" git commit"|*" git commit "*)
        echo "[AGENTS.md ルール違反] git commit/push はユーザーのみ操作可能です。" >&2
        exit 2 ;;
    "git push"|"git push "*|*" git push"|*" git push "*)
        echo "[AGENTS.md ルール違反] git commit/push はユーザーのみ操作可能です。" >&2
        exit 2 ;;
esac

# 許可: コンテナ/CLI/VCS/システムパッケージマネージャ
# cd prefix も && / ; チェーンで対応
case "$CMD" in
    docker\ *|docker-compose\ *|*"&& docker "*|*"; docker "*|*"&& docker-compose "*|*"; docker-compose "*) exit 0 ;;
    gh\ *|glab\ *|*"&& gh "*|*"&& glab "*|*"; gh "*|*"; glab "*) exit 0 ;;
    git\ *|*"&& git "*|*"; git "*) exit 0 ;;
    apt\ *|apt-get\ *|brew\ *|pacman\ *|dnf\ *|yum\ *|apk\ *) exit 0 ;;
esac

# --- Slow path: ツール+アクション検知 (1回の grep) ---

DANGEROUS='(npm|npx|yarn|pnpm|bun)\s+(install|add|ci|link|update|upgrade|init|rebuild)'
DANGEROUS="$DANGEROUS|(pip|pip3|pipx)\s+(install|download|wheel)"
DANGEROUS="$DANGEROUS|poetry\s+(install|add|update|lock)"
DANGEROUS="$DANGEROUS|uv\s+(pip\s+install|sync|lock|add)"
DANGEROUS="$DANGEROUS|gem\s+(install|update|build)"
DANGEROUS="$DANGEROUS|bundle\s+(install|update|add)"
DANGEROUS="$DANGEROUS|cargo\s+(install|add|update)"
DANGEROUS="$DANGEROUS|go\s+(install|get)"
DANGEROUS="$DANGEROUS|composer\s+(install|require|update)"
DANGEROUS="$DANGEROUS|mvn\s+(install|deploy)"
DANGEROUS="$DANGEROUS|gradle\s+(install)"
DANGEROUS="$DANGEROUS|dotnet\s+(add|restore|publish)"
DANGEROUS="$DANGEROUS|mix\s+deps\.(get|compile|update)"
DANGEROUS="$DANGEROUS|make\s+(install|build|all)"
DANGEROUS="$DANGEROUS|cmake\s"

if printf '%s\n' "$CMD" | grep -qE "$DANGEROUS"; then
    echo "[Docker推奨] このコマンドはDocker内で実行してください。" >&2
    echo "検知: $CMD" >&2
    exit 2
fi

exit 0
