#!/bin/sh
# PreToolUse hook - コマンド内の秘密情報ハードコード検出
# PASS/SECRET/TOKEN/API_KEY/AUTH に平文値が直接指定されている場合をブロック
# 環境変数($VAR)経由の参照は許可

[ -t 0 ] && exit 0

INPUT=$(cat)

JQ=$(command -v jaq 2>/dev/null || command -v jq 2>/dev/null || echo "")
[ -z "$JQ" ] && exit 0

COMMAND=$(printf '%s\n' "$INPUT" | "$JQ" -r '.tool_input.command // ""' 2>/dev/null) || COMMAND=""
[ -z "$COMMAND" ] && exit 0

# パターン: PASS='plaintext' / CLI引数 / Authorization header 等。
# $変数参照は除外する。
PATTERN_ENV="(PASS(WORD)?|SECRET|TOKEN|API[_-]?KEY|AUTH|BEARER)=[\"'][^\$\"']{4,}[\"']"
PATTERN_CLI="(--token|--api-key|--password)[= ][^ \$'\";]{4,}"
PATTERN_AUTH_HEADER="Authorization:[[:space:]]*Bearer[[:space:]]+[A-Za-z0-9._~+/-]{10,}"

if printf '%s\n' "$COMMAND" | grep -qEi "$PATTERN_ENV|$PATTERN_CLI|$PATTERN_AUTH_HEADER"; then
    echo "BLOCK: コマンドに秘密情報がハードコードされています。.envに記載し環境変数(\$VAR)経由で渡してください。" >&2
    exit 2
fi

exit 0
