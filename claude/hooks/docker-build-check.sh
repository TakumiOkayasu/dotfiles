#!/bin/bash
# ビルド/インストールコマンドをDocker外で実行しようとした場合に警告

CMD="${CLAUDE_TOOL_INPUT:-}"

# 許可チェック（コマンドがこれらで始まる場合のみ許可）

# 許可: docker / docker-compose / docker compose (コンテナ内実行)
echo "$CMD" | grep -qE '^\s*docker[ -]' && exit 0

# 許可: システムパッケージマネージャ (システム管理は許可)
echo "$CMD" | grep -qE '^\s*(apt|apt-get|brew|pacman|dnf|yum|apk)\b' && exit 0

# 注意: git は許可リストから除外
# `npm install && git status` のような場合、npm install を検知するため

# 検知: 環境を変更するアクション
ACTIONS='install|add|build|ci|init|setup|require|update|upgrade|compile|link'

if echo "$CMD" | grep -qE "\b($ACTIONS)\b"; then
    echo "[Docker推奨] このコマンドはDocker内で実行してください。" >&2
    echo "検知: $CMD" >&2
    exit 2
fi

exit 0
