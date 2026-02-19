#!/bin/sh
# commit-checkpoint.sh - git commit 後の自動チェックポイント
#
# 責務:
#   - git commit 検知時に .claude/checkpoints/latest.md を更新
#   - commit メッセージ・変更ファイル・ブランチ名を機械的に保存
#   - フリーズ時のフォールバック用
#
# 発動: PostToolUse (Bash) - git commit を含むコマンドのみ
# 依存: jaq or jq

# set -e を使わない（exit 1 = hookエラー = 許可扱いリスク）

if [ -t 0 ]; then
    exit 0
fi

INPUT=$(cat)

# jaq優先、jqフォールバック（見つからない場合は空文字→許可）
JQ=$(command -v jaq 2>/dev/null || command -v jq 2>/dev/null || echo "")
if [ -z "$JQ" ]; then
    exit 0
fi

# Bash コマンドを取得
COMMAND=$(printf '%s\n' "$INPUT" | "$JQ" -r '.tool_input.command // ""' 2>/dev/null) || COMMAND=""
CWD=$(printf '%s\n' "$INPUT" | "$JQ" -r '.cwd // ""' 2>/dev/null) || CWD=""

# git commit を含むコマンドのみ対象
case "$COMMAND" in
    *"git commit"*)
        ;;
    *)
        exit 0
        ;;
esac

# git リポジトリ確認
cd "$CWD" 2>/dev/null || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

CHECKPOINT_DIR="${CWD}/.claude/checkpoints"
mkdir -p "$CHECKPOINT_DIR"

CHECKPOINT_FILE="${CHECKPOINT_DIR}/latest.md"

{
    echo "# Commit Checkpoint"
    echo ""
    echo "- **Timestamp:** $(date '+%Y-%m-%d %H:%M:%S')"
    echo "- **Branch:** $(git branch --show-current 2>/dev/null || echo 'detached')"
    echo ""
    echo "## Recent Commits"
    echo ""
    git log --oneline -5 2>/dev/null | sed 's/^/- /'
    echo ""
    echo "## Last Commit Changes"
    echo ""
    git diff --name-only HEAD~1 2>/dev/null | sed 's/^/- /' || echo "- (no previous commit)"
    echo ""

    # PROGRESS.md があれば含める
    PROGRESS_FILE="${CWD}/.claude/progress.md"
    if [ -f "$PROGRESS_FILE" ]; then
        echo "## PROGRESS.md (at commit time)"
        echo ""
        cat "$PROGRESS_FILE"
    fi
} > "$CHECKPOINT_FILE"

exit 0
