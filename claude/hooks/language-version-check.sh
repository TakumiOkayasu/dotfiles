#!/bin/sh
# 言語イメージのバージョン固定を禁止（検証用途は latest 推奨）

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

# バージョン番号指定を検知 (例: python:3.9, node:18)
if printf '%s\n' "$CMD" | grep -qE "(${LANGS}):[0-9]"; then
    echo "⚠️ 検証用途は latest を使用してください"
    echo ""
    echo "検知: $CMD"
    echo ""
    echo "推奨: python:slim, node:slim, golang:alpine 等"
    echo "BLOCK"
    exit 0
fi

exit 0
