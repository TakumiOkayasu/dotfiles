#!/bin/sh
# ビルド/インストールコマンドをDocker外で実行しようとした場合に警告

# stdin からJSON入力を読み取る
if [ -t 0 ]; then
    exit 0
fi

INPUT=$(cat)

# jaq優先、jqフォールバック（見つからない場合は空文字→許可）
JQ=$(command -v jaq 2>/dev/null || command -v jq 2>/dev/null || echo "")
if [ -n "$JQ" ]; then
    CMD=$(printf '%s\n' "$INPUT" | "$JQ" -r '.tool_input.command // ""' 2>/dev/null) || CMD=""
else
    CMD=""
fi

# コマンドが空なら即許可
if [ -z "$CMD" ]; then
    exit 0
fi

# cdプレフィックスを考慮した許可チェック用パターン
CD_PREFIX='^[[:space:]]*(cd[[:space:]]+[^[:space:]]+[[:space:]]*(&&|;)[[:space:]]*)*'

# 許可: docker / docker-compose / docker compose (コンテナ内実行)
printf '%s\n' "$CMD" | grep -qE "${CD_PREFIX}docker[ -]" && exit 0

# 許可: システムパッケージマネージャ (システム管理は許可)
printf '%s\n' "$CMD" | grep -qE "${CD_PREFIX}(apt|apt-get|brew|pacman|dnf|yum|apk)\b" && exit 0

# 許可: git (git add等がACTIONSパターンに誤マッチするのを防止)
# チェーンコマンド (git add && npm install) はlocal-command-block.shがnpmを検知
printf '%s\n' "$CMD" | grep -qE "${CD_PREFIX}git\b" && exit 0

# 検知: 環境を変更するアクション
ACTIONS='install|add|build|ci|init|setup|require|update|upgrade|compile|link'

if printf '%s\n' "$CMD" | grep -qE "\b($ACTIONS)\b"; then
    echo "[Docker推奨] このコマンドはDocker内で実行してください。" >&2
    echo "検知: $CMD" >&2
    exit 2
fi

exit 0
