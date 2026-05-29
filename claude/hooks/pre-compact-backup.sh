#!/bin/sh
# pre-compact-backup.sh - compact 前の自動バックアップ
#
# 責務:
#   - PROGRESS.md の内容を含むサマリーを latest.md に保存
#   - transcript から直近のユーザーリクエスト・変更ファイルを抽出
#   - .claude/checkpoints/latest.md に集約
#
# 発動: PreCompact (auto|manual)
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

TRANSCRIPT_PATH=$(printf '%s\n' "$INPUT" | "$JQ" -r '.transcript_path // ""' 2>/dev/null) || TRANSCRIPT_PATH=""
CWD=$(printf '%s\n' "$INPUT" | "$JQ" -r '.cwd // ""' 2>/dev/null) || CWD=""
TRIGGER=$(printf '%s\n' "$INPUT" | "$JQ" -r '.trigger // "unknown"' 2>/dev/null) || TRIGGER="unknown"

CHECKPOINT_DIR="${CWD}/.claude/checkpoints"
PROGRESS_FILE="${CWD}/.claude/progress.md"

mkdir -p "$CHECKPOINT_DIR"

# 旧タイムスタンプ付きファイルを削除 (latest.md のみ残す)
for _old in "$CHECKPOINT_DIR"/progress-*.md "$CHECKPOINT_DIR"/pre-compact-*.md; do
    [ -f "$_old" ] && rm -f "$_old"
done

# --- transcript からサマリー抽出 → latest.md に直接書き出し ---
SUMMARY_FILE="${CHECKPOINT_DIR}/latest.md"

{
    echo "# Pre-Compact Backup"
    echo ""
    echo "- **Timestamp:** $(date '+%Y-%m-%d %H:%M:%S')"
    echo "- **Trigger:** ${TRIGGER}"
    echo "- **Branch:** $(cd "$CWD" && git branch --show-current 2>/dev/null || echo 'N/A')"
    echo ""

    # 直近のユーザーリクエスト抽出
    if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
        echo "## User Requests (recent)"
        echo ""
        tail -500 "$TRANSCRIPT_PATH" | "$JQ" -s -r '
            .[]
            | select(.message.role == "user")
            | .message.content
            | if type == "array" then (.[] | select(.type == "text") | .text)
              elif type == "string" then .
              else empty end
            | gsub("\n"; " ")
            | .[0:200]
            | "- " + .
        ' 2>/dev/null || echo "- (transcript parse failed)"
        echo ""
    fi

    # git 変更ファイル一覧
    echo "## Recent Changes"
    echo ""
    if cd "$CWD" 2>/dev/null && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "### Uncommitted"
        git diff --name-only 2>/dev/null | head -20 | sed 's/^/- /'
        git diff --cached --name-only 2>/dev/null | head -20 | sed 's/^/- (staged) /'
        echo ""
        echo "### Recent Commits"
        git log --oneline -10 2>/dev/null | sed 's/^/- /'
    else
        echo "- (not a git repo)"
    fi
    echo ""

    # PROGRESS.md の内容も含める
    if [ -f "$PROGRESS_FILE" ]; then
        echo "## PROGRESS.md (at compact time)"
        echo ""
        cat "$PROGRESS_FILE"
    fi
} > "$SUMMARY_FILE"

exit 0
