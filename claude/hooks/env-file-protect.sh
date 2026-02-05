#!/bin/sh
# PreToolUse hook - .envファイルの読み取り/編集をブロック
# .envファイルの秘匿情報を保護するため、読み取り・編集操作をブロックする
# 書き込み(Write)は許可し、.env.example等のテンプレートファイルも許可する
#
# 使い方 (手動実行):
#   echo '{"tool_name":"Bash","tool_input":{"command":"cat .env"}}' | ./env-file-protect.sh
#   echo '{"tool_name":"Read","tool_input":{"file_path":"/app/.env.local"}}' | ./env-file-protect.sh

set -e

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    cat <<'EOF'
env-file-protect.sh - .envファイルの読み取り/編集をブロック

使い方:
  echo '{"tool_name":"Bash","tool_input":{"command":"cat .env"}}' | ./env-file-protect.sh
  echo '{"tool_name":"Read","tool_input":{"file_path":".env.local"}}' | ./env-file-protect.sh

説明:
  .envファイル(.env, .env.local, .env.production 等)の読み取り・編集を
  ブロックします。以下は許可されます:
    - .env.example, .env.sample, .env.template, .env.dist (テンプレート)
    - .envファイルへの新規書き込み(Write)
    - .envファイルの存在確認(test -f, ls)

依存関係:
  jaq または jq が必要です (jaq優先)
  - macOS: brew install jaq
  - Ubuntu/Debian: apt install jq (または cargo install jaq)
  - Arch: pacman -S jq (または paru -S jaq)
  - Windows: scoop install jaq (または winget install jqlang.jq)
EOF
    exit 0
fi

if [ -t 0 ]; then
    echo "エラー: 標準入力がありません" >&2
    exit 1
fi

INPUT=$(cat)

# jaq優先、jqフォールバック
JQ=$(command -v jaq || command -v jq || echo "jq")

TOOL_NAME=$(echo "$INPUT" | $JQ -r '.tool_name // ""' 2>/dev/null || echo "")

# --- ホワイトリスト(テンプレート系): これらはブロックしない ---
WHITELIST_PATTERN='\.env\.(example|sample|template|dist)\b'

# --- ブロック対象の.envファイル名パターン ---
# .env, .env.local, .env.production, .env.development.local, .env.bak, .env.old 等
ENV_FILE_PATTERN='\.env(\.[a-zA-Z0-9_.-]+)?(\s|$|"|'"'"'|;|&&|\|)'

# --- 存在確認系コマンド(許可する) ---
EXISTENCE_CHECK_PATTERN='^\s*(test\s+-[fedrwx]\s|ls\s|\[\s+-[fedrwx]\s)'

check_env_access() {
    TARGET="$1"

    # ホワイトリストに該当すればスキップ
    if echo "$TARGET" | grep -qE "$WHITELIST_PATTERN"; then
        return 1
    fi

    # .envパターンに該当すればブロック対象
    if echo "$TARGET" | grep -qE "$ENV_FILE_PATTERN"; then
        return 0
    fi

    return 1
}

case "$TOOL_NAME" in
    Bash)
        COMMAND=$(echo "$INPUT" | $JQ -r '.tool_input.command // ""' 2>/dev/null || echo "")

        # 空コマンドはスキップ
        if [ -z "$COMMAND" ]; then
            exit 0
        fi

        # 存在確認系は許可
        if echo "$COMMAND" | grep -qE "$EXISTENCE_CHECK_PATTERN"; then
            exit 0
        fi

        # コマンド内に.envパターンが含まれるかチェック
        if check_env_access "$COMMAND"; then
            echo "[.env保護] .envファイルの読み取りはブロックされました。" >&2
            echo "構造の確認には .env.example を参照してください。" >&2
            exit 2
        fi
        ;;

    Read)
        FILE_PATH=$(echo "$INPUT" | $JQ -r '.tool_input.file_path // ""' 2>/dev/null || echo "")

        if [ -z "$FILE_PATH" ]; then
            exit 0
        fi

        if check_env_access "$FILE_PATH"; then
            echo "[.env保護] .envファイルの読み取りはブロックされました。" >&2
            echo "構造の確認には .env.example を参照してください。" >&2
            exit 2
        fi
        ;;

    Edit)
        FILE_PATH=$(echo "$INPUT" | $JQ -r '.tool_input.file_path // ""' 2>/dev/null || echo "")

        if [ -z "$FILE_PATH" ]; then
            exit 0
        fi

        if check_env_access "$FILE_PATH"; then
            echo "[.env保護] .envファイルの編集はブロックされました。" >&2
            echo "値の変更が必要な場合はユーザー自身が行ってください。" >&2
            exit 2
        fi
        ;;
esac

exit 0

