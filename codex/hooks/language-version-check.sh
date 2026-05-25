#!/bin/sh
# 言語イメージの floating tag を警告（project pin / LTS明示を優先）

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

# docker関連コマンドのみチェック
printf '%s\n' "$CMD" | grep -qE 'docker.*(run|build|pull|from)' || exit 0

# 言語/ランタイムイメージ
LANGS="python|node|golang|go|openjdk|ruby|rust|php|perl|swift|elixir|erlang|haskell|julia|dotnet"

# floating tag を検知 (例: python:slim, node:latest)
if printf '%s\n' "$CMD" | grep -qE "(${LANGS}):(latest|slim|alpine|bookworm|bullseye)([[:space:]\"';]|$)"; then
    echo "[バージョン未固定] image tag が floating です。project pin または LTS の明示タグを優先してください。" >&2
    echo "検知: $CMD" >&2
    echo "例: node:<LTS>-slim, python:<version>-slim, golang:<version>-alpine" >&2
    exit 2
fi

exit 0
