#!/bin/sh
# write-execute-guard.sh - Write+Execute 攻撃検知hook
#
# 動作モード:
#   PostToolUse(Write): 書き込まれたファイルパスをセンチネルファイルに記録
#   PreToolUse(Bash):   実行コマンドが記録済みファイルを参照していたらブロック
#
# センチネルファイル: /tmp/.claude_written_files
#   (session-start-reminder.sh でセッション開始時にクリア)
#
# 使い方 (手動実行):
#   # Write記録
#   echo '{"tool_name":"Write","tool_input":{"file_path":"/tmp/evil.sh"}}' | ./write-execute-guard.sh
#   # Bash検知
#   echo '{"tool_name":"Bash","tool_input":{"command":"bash /tmp/evil.sh"}}' | ./write-execute-guard.sh

# set -e を使わない（exit 1 = hookエラー = 許可扱いリスク）

SENTINEL="/tmp/.claude_written_files"

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    cat <<'EOF'
write-execute-guard.sh - Write+Execute 攻撃を検知してブロック

使い方:
  # PostToolUse(Write): ファイルパスを記録
  echo '{"tool_name":"Write","tool_input":{"file_path":"/tmp/script.sh"}}' | ./write-execute-guard.sh

  # PreToolUse(Bash): 記録済みファイルの実行をブロック
  echo '{"tool_name":"Bash","tool_input":{"command":"bash /tmp/script.sh"}}' | ./write-execute-guard.sh

説明:
  Writeツールで作成したスクリプトをBashツールで実行するパターンを検知します。
  センチネルファイル (/tmp/.claude_written_files) にパスを記録し、
  Bash実行時にそのファイルが参照されていないか確認します。

依存関係:
  jaq または jq が必要です (jaq優先)
EOF
    exit 0
fi

if [ -t 0 ]; then
    echo "エラー: 標準入力がありません" >&2
    exit 1
fi

INPUT=$(cat)

# jaq優先、jqフォールバック（見つからない場合は空文字→許可）
JQ=$(command -v jaq 2>/dev/null || command -v jq 2>/dev/null || echo "")
if [ -z "$JQ" ]; then
    exit 0
fi

TOOL_NAME=$(printf '%s\n' "$INPUT" | "$JQ" -r '.tool_name // ""' 2>/dev/null) || TOOL_NAME=""

# --- PostToolUse(Write): ファイルパスを記録 ---
if [ "$TOOL_NAME" = "Write" ]; then
    FILE_PATH=$(printf '%s\n' "$INPUT" | "$JQ" -r '.tool_input.file_path // ""' 2>/dev/null) || FILE_PATH=""
    if [ -n "$FILE_PATH" ]; then
        echo "$FILE_PATH" >> "$SENTINEL"
    fi
    exit 0
fi

# --- PreToolUse(Bash): 記録済みファイルの実行をブロック ---
if [ "$TOOL_NAME" = "Bash" ]; then
    COMMAND=$(printf '%s\n' "$INPUT" | "$JQ" -r '.tool_input.command // ""' 2>/dev/null) || COMMAND=""
    if [ -z "$COMMAND" ] || [ ! -f "$SENTINEL" ]; then
        exit 0
    fi

    # 記録済みファイルパスがコマンドに含まれているかチェック
    while IFS= read -r written_file; do
        [ -z "$written_file" ] && continue
        # ファイル名がコマンドに含まれているか (完全パスまたはbasename)
        basename_file=$(basename "$written_file")
        if printf '%s\n' "$COMMAND" | grep -qF "$written_file" || \
           printf '%s\n' "$COMMAND" | grep -qE "(sh|bash|zsh|source|\.)\s+.*$(echo "$basename_file" | sed 's/[.[\*^$()+?{|\\]/\\&/g')"; then
            echo "[Write+Execute検知] 直前にWriteで作成されたファイルの実行はブロックされました。" >&2
            echo "  対象ファイル: $written_file" >&2
            echo "  docker 経由で実行するか、ユーザーが直接実行してください。" >&2
            exit 2
        fi
    done < "$SENTINEL"
fi

exit 0
