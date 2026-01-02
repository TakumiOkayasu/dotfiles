#!/bin/bash
# PreToolUse hook - mainブランチでのコード変更を警告
# CLAUDE.mdルール: コード変更前にブランチを確認・作成
#
# 使い方 (手動実行):
#   echo '{"tool_input":{"file_path":"src/main.py"}}' | ./main-branch-code-warning.sh
#
# Claude Code hook として自動実行される場合は stdin から JSON を受け取る

set -e

# 手動実行時のヘルプ
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    cat <<'EOF'
main-branch-code-warning.sh - mainブランチでのコード変更を警告

使い方:
  echo '{"tool_input":{"file_path":"src/main.py"}}' | ./main-branch-code-warning.sh

説明:
  Claude Code の PreToolUse hook として動作し、mainブランチで
  コードファイルを変更しようとした場合に警告を出します。
  (ドキュメントや設定ファイルはスキップ)
EOF
    exit 0
fi

# stdin がない場合のタイムアウト対策
if [[ -t 0 ]]; then
    echo "エラー: 標準入力がありません" >&2
    echo "使い方: echo '{\"tool_input\":{\"file_path\":\"src/main.py\"}}' | $0" >&2
    echo "ヘルプ: $0 --help" >&2
    exit 1
fi

# Read JSON input from stdin
INPUT=$(cat)

# Extract file path from tool_input
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null || echo "")

# ファイルパスがない場合はスキップ
[[ -z "$FILE_PATH" ]] && exit 0

# ドキュメントファイルはスキップ (CLAUDE.md編集などは許可)
if echo "$FILE_PATH" | grep -qiE '\.(md|markdown|rst|txt)$'; then
    exit 0
fi

# 設定ファイルもスキップ (settings.json など)
if echo "$FILE_PATH" | grep -qiE '\.(json|yaml|yml|toml|ini|conf|config)$'; then
    exit 0
fi

# Gitリポジトリ内かチェック
if ! git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
    exit 0
fi

# 現在のブランチを取得
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")

# mainまたはmasterブランチの場合に警告
if [[ "$CURRENT_BRANCH" == "main" || "$CURRENT_BRANCH" == "master" ]]; then
    cat <<EOF
{
  "hookSpecificOutput": {
    "additionalContext": "[警告] 現在 ${CURRENT_BRANCH} ブランチです。コードファイルを変更しようとしています。\n- git-new-feature でブランチを作成してから作業してください\n- 例: git-new-feature 機能名"
  }
}
EOF
fi

exit 0
