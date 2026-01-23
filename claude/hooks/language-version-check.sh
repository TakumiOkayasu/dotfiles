#!/bin/sh
# 言語イメージのバージョン固定を禁止（検証用途は latest 推奨）

CMD="${CLAUDE_TOOL_INPUT:-}"

# docker関連コマンドのみチェック
echo "$CMD" | grep -qE 'docker.*(run|build|pull|from)' || exit 0

# 言語/ランタイムイメージ
LANGS="python|node|golang|go|openjdk|ruby|rust|php|perl|swift|elixir|erlang|haskell|julia|dotnet"

# バージョン番号指定を検知 (例: python:3.9, node:18)
if echo "$CMD" | grep -qE "(${LANGS}):[0-9]"; then
    echo "⚠️ 検証用途は latest を使用してください"
    echo ""
    echo "検知: $CMD"
    echo ""
    echo "推奨: python:slim, node:slim, golang:alpine 等"
    echo "BLOCK"
    exit 0
fi

exit 0
