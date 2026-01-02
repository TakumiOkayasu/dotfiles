#!/bin/bash
# PreToolUse hook - mainブランチでのコード変更を警告
# CLAUDE.mdルール: コード変更前にブランチを確認・作成

set -e

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
