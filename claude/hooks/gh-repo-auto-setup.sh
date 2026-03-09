#!/bin/sh
# gh-repo-auto-setup.sh - リポジトリ自動セットアップ
#
# 責務:
#   - 全リポジトリ: delete-branch-on-merge 有効化
#   - publicリポジトリのみ: GitHub Rulesets でmainブランチ保護
#     (deletion禁止, force push禁止, 直push禁止=PR必須)
#   - 冪等: フラグファイル + API状態チェックで重複実行を防止
#
# 発動: PostToolUse (Bash) - gh repo create / git push のみ
# 依存: jaq or jq, gh

# set -e を使わない（exit 1 = hookエラー = 許可扱いリスク）

if [ -t 0 ]; then
    exit 0
fi

INPUT=$(cat)

JQ=$(command -v jaq 2>/dev/null || command -v jq 2>/dev/null || echo "")
[ -z "$JQ" ] && exit 0
command -v gh >/dev/null 2>&1 || exit 0

COMMAND=$(printf '%s\n' "$INPUT" | "$JQ" -r '.tool_input.command // ""' 2>/dev/null) || COMMAND=""

# トリガー判定: gh repo create または git push のみ
IS_REPO_CREATE=false
IS_GIT_PUSH=false
case "$COMMAND" in
    *"gh repo create"*) IS_REPO_CREATE=true ;;
esac
printf '%s\n' "$COMMAND" | grep -qE 'git\s+push' && IS_GIT_PUSH=true
[ "$IS_REPO_CREATE" = false ] && [ "$IS_GIT_PUSH" = false ] && exit 0

# CWD 移動
CWD=$(printf '%s\n' "$INPUT" | "$JQ" -r '.cwd // ""' 2>/dev/null) || CWD=""
if [ -n "$CWD" ] && [ -d "$CWD" ]; then
    cd "$CWD" 2>/dev/null || exit 0
fi

# git push の場合、GitHubリモートか確認
if [ "$IS_GIT_PUSH" = true ]; then
    REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
    case "$REMOTE_URL" in
        *github.com*) ;;
        *) exit 0 ;;
    esac
fi

# リポジトリ情報を一括取得 (API呼び出し1回)
REPO_INFO=$(gh repo view --json nameWithOwner,deleteBranchOnMerge,visibility 2>/dev/null || echo "{}")
REPO_NAME=$(printf '%s' "$REPO_INFO" | "$JQ" -r '.nameWithOwner // ""' 2>/dev/null) || REPO_NAME=""
[ -z "$REPO_NAME" ] && exit 0

# フラグファイルで重複防止
STAMP_NAME=$(printf '%s' "$REPO_NAME" | tr '/' '-')
STAMP_FILE="${TMPDIR:-/tmp}/.gh-repo-setup-${STAMP_NAME}"
[ -f "$STAMP_FILE" ] && exit 0

# --- セットアップ実行 ---
MESSAGES=""
SETUP_COMPLETE=true

# 1. delete-branch-on-merge (全リポジトリ)
CURRENT_DBM=$(printf '%s' "$REPO_INFO" | "$JQ" -r '.deleteBranchOnMerge // false' 2>/dev/null) || CURRENT_DBM=""
if [ "$CURRENT_DBM" != "true" ]; then
    if gh repo edit --delete-branch-on-merge 2>/dev/null; then
        MESSAGES="${MESSAGES}delete-branch-on-merge を有効化\n"
    else
        SETUP_COMPLETE=false
    fi
fi

# 2. Rulesets (publicリポジトリのみ)
RULESET_NAME="main-protection"
VISIBILITY=$(printf '%s' "$REPO_INFO" | "$JQ" -r '.visibility // ""' 2>/dev/null) || VISIBILITY=""
if [ "$VISIBILITY" = "PUBLIC" ]; then
    # 既存Rulesets確認 (名前で重複チェック)
    EXISTING=$(gh api "repos/${REPO_NAME}/rulesets" 2>/dev/null \
        | "$JQ" -r '.[].name' 2>/dev/null || echo "")
    if ! printf '%s\n' "$EXISTING" | grep -qx "$RULESET_NAME"; then
        RULESET_JSON=$(cat <<'RSJSON'
{
  "name": "main-protection",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["refs/heads/main"],
      "exclude": []
    }
  },
  "rules": [
    {"type": "deletion"},
    {"type": "non_fast_forward"},
    {"type": "pull_request"}
  ]
}
RSJSON
)
        if printf '%s' "$RULESET_JSON" | gh api "repos/${REPO_NAME}/rulesets" --method POST --input - >/dev/null 2>&1; then
            MESSAGES="${MESSAGES}${RULESET_NAME} Ruleset を作成 (deletion禁止, force push禁止, PR必須)\n"
        else
            SETUP_COMPLETE=false
        fi
    fi
fi

# 全て成功した場合のみフラグ作成
if [ "$SETUP_COMPLETE" = true ]; then
    touch "$STAMP_FILE"
fi

# 結果出力
if [ -n "$MESSAGES" ]; then
    ESCAPED=$(printf '%s' "$MESSAGES" | sed 's/"/\\"/g')
    cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "[自動設定] ${ESCAPED}"
  }
}
EOF
fi

exit 0
