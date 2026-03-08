#!/bin/sh
# PostToolUse hook - gh repo create / git push 後に delete-branch-on-merge を自動設定
#
# 使い方 (手動実行):
#   echo '{"tool_input":{"command":"gh repo create my-repo --public"}}' | ./gh-repo-auto-setup.sh
#
# Claude Code hook として自動実行される場合は stdin から JSON を受け取る

# set -e を使わない（exit 1 = hookエラー = サイレント停止リスク）

# 手動実行時のヘルプ
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    cat <<'EOF'
gh-repo-auto-setup.sh - gh repo create / git push 後に delete-branch-on-merge を自動設定

使い方:
  echo '{"tool_input":{"command":"gh repo create my-repo --public"}}' | ./gh-repo-auto-setup.sh

説明:
  Claude Code の PostToolUse hook として動作し:
  - gh repo create 後に自動で delete-branch-on-merge を有効化
  - git push (GitHub リモート) 後に未設定なら有効化（1回のみ）

依存関係:
  jaq または jq が必要です (jaq優先)
  gh (GitHub CLI) が必要です
  - macOS: brew install jaq gh
  - Ubuntu/Debian: apt install jq gh
EOF
    exit 0
fi

# stdin がない場合のタイムアウト対策 (POSIX互換)
if [ -t 0 ]; then
    echo "エラー: 標準入力がありません" >&2
    echo "使い方: echo '{\"tool_input\":{\"command\":\"gh repo create my-repo\"}}' | $0" >&2
    echo "ヘルプ: $0 --help" >&2
    exit 1
fi

# Read JSON input from stdin
INPUT=$(cat)

# jaq優先、jqフォールバック（見つからない場合はサイレントスキップ）
JQ=$(command -v jaq 2>/dev/null || command -v jq 2>/dev/null || echo "")
if [ -z "$JQ" ]; then
    exit 0
fi

# gh が使えない環境ではサイレントスキップ
if ! command -v gh >/dev/null 2>&1; then
    exit 0
fi

# Extract command and cwd from tool_input
COMMAND=$(printf '%s\n' "$INPUT" | "$JQ" -r '.tool_input.command // ""' 2>/dev/null) || COMMAND=""
CWD=$(printf '%s\n' "$INPUT" | "$JQ" -r '.cwd // ""' 2>/dev/null) || CWD=""

# CWD が指定されていればそこに移動
if [ -n "$CWD" ] && [ -d "$CWD" ]; then
    cd "$CWD" 2>/dev/null || true
fi

# --- gh repo create 検出 ---
if printf '%s\n' "$COMMAND" | grep -qE 'gh\s+repo\s+create'; then
    # delete-branch-on-merge を自動設定
    if gh repo edit --delete-branch-on-merge 2>/dev/null; then
        cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "[自動設定] delete-branch-on-merge を有効化しました。"
  }
}
EOF
    else
        cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "[警告] delete-branch-on-merge の自動設定に失敗しました。手動で gh repo edit --delete-branch-on-merge を実行してください。"
  }
}
EOF
    fi
    exit 0
fi

# --- git push 検出 (GitHub リモート) ---
if printf '%s\n' "$COMMAND" | grep -qE 'git\s+push'; then
    # リモートが GitHub か確認
    REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
    case "$REMOTE_URL" in
        *github.com*) ;;
        *) exit 0 ;;
    esac

    # リポジトリ名からスタンプファイルを生成（重複防止）
    REPO_NAME=$(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null || echo "")
    if [ -z "$REPO_NAME" ]; then
        exit 0
    fi

    # スタンプファイルで重複防止（リポジトリごと）
    STAMP_NAME=$(printf '%s' "$REPO_NAME" | tr '/' '-')
    STAMP_FILE="${TMPDIR:-/tmp}/gh-repo-setup-${STAMP_NAME}"
    if [ -f "$STAMP_FILE" ]; then
        exit 0
    fi

    # 現在の設定を確認
    CURRENT=$(gh repo view --json deleteBranchOnMerge -q '.deleteBranchOnMerge' 2>/dev/null || echo "")
    if [ "$CURRENT" = "true" ]; then
        # 既に有効 - スタンプ作成して終了
        touch "$STAMP_FILE"
        exit 0
    fi

    # 未設定なら有効化
    if gh repo edit --delete-branch-on-merge 2>/dev/null; then
        touch "$STAMP_FILE"
        cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "[自動設定] delete-branch-on-merge が未設定だったため有効化しました。"
  }
}
EOF
    fi
    exit 0
fi

# 対象外のコマンドは何も出力しない
exit 0
