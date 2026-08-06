#!/bin/sh
# PreToolUse hook - mainブランチでのコード変更を警告
# AGENTS.mdルール: コード変更前にブランチを確認・作成
#
# 使い方 (手動実行):
#   echo '{"tool_input":{"file_path":"src/main.py"}}' | ./main-branch-code-warning.sh
#
# Codex hook として自動実行される場合は stdin から JSON を受け取る

# set -e を使わない（exit 1 = hookエラー = 許可扱いリスク）

# 手動実行時のヘルプ
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    cat <<'EOF'
main-branch-code-warning.sh - mainブランチでのコード変更を警告

使い方:
  echo '{"tool_input":{"file_path":"src/main.py"}}' | ./main-branch-code-warning.sh

説明:
  Codex の PreToolUse hook として動作し、mainブランチでコードファイルを変更しようとした場合に警告を出します。(ドキュメントや設定ファイルはスキップ)

依存関係:
  jaq または jq が必要です (jaq優先)
  - macOS: brew install jaq
  - Ubuntu/Debian: apt install jq (または cargo install jaq)
  - Arch: pacman -S jq (または paru -S jaq)
  - Windows: scoop install jaq (または winget install jqlang.jq)
EOF
    exit 0
fi

# stdin がない場合のタイムアウト対策
if [ -t 0 ]; then
    echo "エラー: 標準入力がありません" >&2
    echo "使い方: echo '{\"tool_input\":{\"file_path\":\"src/main.py\"}}' | $0" >&2
    echo "ヘルプ: $0 --help" >&2
    exit 1
fi

# Read JSON input from stdin
INPUT=$(cat)

# jaq優先、jqフォールバック（見つからない場合は空文字→許可）
JQ=$(command -v jaq 2>/dev/null || command -v jq 2>/dev/null || echo "")
if [ -z "$JQ" ]; then
    exit 0
fi

TOOL_NAME=$(printf '%s\n' "$INPUT" | "$JQ" -r '.tool_name // ""' 2>/dev/null) || TOOL_NAME=""

is_doc_or_config_path() {
    printf '%s\n' "$1" | grep -qiE '\.(md|markdown|rst|txt|json|yaml|yml|toml|ini|conf|config)$'
}

extract_paths_from_patch() {
    printf '%s\n' "$1" | sed -n \
        -e 's/^\*\*\* Add File: //p' \
        -e 's/^\*\*\* Update File: //p' \
        -e 's/^\*\*\* Delete File: //p' \
        -e 's/^\*\*\* Move to: //p'
}

targets_code_path() {
    while IFS= read -r _path; do
        [ -z "$_path" ] && continue
        is_doc_or_config_path "$_path" && continue
        return 0
    done
    return 1
}

case "$TOOL_NAME" in
    apply_patch|ApplyPatch)
        PATCH_TEXT=$(printf '%s\n' "$INPUT" | "$JQ" -r '.tool_input.command // .tool_input.patch // ""' 2>/dev/null) || PATCH_TEXT=""
        [ -z "$PATCH_TEXT" ] && exit 0
        TARGET_PATHS=$(extract_paths_from_patch "$PATCH_TEXT")
        ;;
    Edit|Write|MultiEdit)
        FILE_PATH=$(printf '%s\n' "$INPUT" | "$JQ" -r '.tool_input.file_path // .tool_input.path // ""' 2>/dev/null) || FILE_PATH=""
        [ -z "$FILE_PATH" ] && exit 0
        TARGET_PATHS="$FILE_PATH"
        ;;
    *)
        exit 0
        ;;
esac

printf '%s\n' "$TARGET_PATHS" | targets_code_path || exit 0

# Gitリポジトリ内かチェック
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    exit 0
fi

# 現在のブランチを取得
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")

# mainまたはmasterブランチの場合に警告
if [ "$CURRENT_BRANCH" = "main" ] || [ "$CURRENT_BRANCH" = "master" ]; then
    echo "[mainブランチ保護] 現在 ${CURRENT_BRANCH} ブランチです。コードファイルの変更は作業ブランチで行ってください。" >&2
    echo "例: git-new-feature 機能名" >&2
    exit 2
fi

exit 0
