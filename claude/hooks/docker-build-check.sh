#!/bin/bash
# ビルド/インストールコマンドをDocker外で実行しようとした場合に警告

CMD="${CLAUDE_TOOL_INPUT:-}"

# 許可: docker / docker-compose / docker compose
echo "$CMD" | grep -qE '^docker[ -]' && exit 0

# 許可: git (git add 等)
echo "$CMD" | grep -qE '^git ' && exit 0

# 許可: システムパッケージマネージャ
echo "$CMD" | grep -qE '^(apt|apt-get|brew|pacman|dnf|yum|apk) ' && exit 0

# 検知: 環境を変更するアクション
ACTIONS='install|add|build|ci|init|setup|require|update|upgrade|compile|link'

if echo "$CMD" | grep -qE "\b($ACTIONS)\b"; then
    echo "⚠️ Docker内で実行してください"
    echo ""
    echo "検知: $CMD"
    echo "BLOCK"
    exit 0
fi

exit 0
