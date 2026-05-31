#!/bin/sh
# session-resume.sh - セッション開始時の自動コンテキスト復帰
#
# 責務:
#   - PROGRESS.md の検出 & 内容注入
#   - checkpoint の検出 & 内容注入
#   - compact 後の自動復帰
#
# 発動: SessionStart (startup|resume|compact|clear)
# 出力: stdout → Claude のコンテキストに注入
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

SOURCE=$(printf '%s\n' "$INPUT" | "$JQ" -r '.source // "startup"' 2>/dev/null) || SOURCE="startup"
CWD=$(printf '%s\n' "$INPUT" | "$JQ" -r '.cwd // ""' 2>/dev/null) || CWD=""

PROGRESS_FILE="${CWD}/.claude/progress.md"
CHECKPOINT_FILE="${CWD}/.claude/checkpoints/latest.md"

# clear 後は復帰不要(意図的なリセット)
if [ "$SOURCE" = "clear" ]; then
    exit 0
fi

HAS_CONTEXT=false

# --- compact 後の特別メッセージ ---
if [ "$SOURCE" = "compact" ]; then
    echo ""
    echo "🔄 [Session Continuity] auto-compact が発生しました。以下の情報から文脈を復元してください。"
    echo ""
    HAS_CONTEXT=true
fi

# --- PROGRESS.md の注入 (省エネ: 全文でなく要点のみ抽出) ---
# 全文 cat は compact 毎に大量注入となり固定コンテキスト費が嵩むため、
# 「現在のタスク」節 + 未完了 `- [ ]` 行 + 「判断ログ」節の直近10行のみ注入する
if [ -f "$PROGRESS_FILE" ]; then
    echo "📋 [PROGRESS.md] 前回のタスク状況 (要点抽出):"
    echo ""
    awk '
        /^## / { intask = ($0 ~ /現在のタスク/); inlog = ($0 ~ /判断ログ/); logn = 0 }
        intask { print; next }
        inlog { if (logn < 10) { print; logn++ }; next }
        /^- \[ \]/ { print }
    ' "$PROGRESS_FILE"
    echo ""
    echo "(全文は .claude/progress.md を参照)"
    HAS_CONTEXT=true

    # 未完了タスクのカウント
    INCOMPLETE=$(grep -c '^\- \[ \]' "$PROGRESS_FILE" 2>/dev/null || echo "0")
    if [ "$INCOMPLETE" -gt 0 ]; then
        echo "⚡ 未完了タスク: ${INCOMPLETE}件"
        echo ""
    fi
fi

# --- checkpoint の注入(compact 後 or resume 時、先頭40行にキャップ) ---
if [ "$SOURCE" = "compact" ] || [ "$SOURCE" = "resume" ]; then
    if [ -f "$CHECKPOINT_FILE" ]; then
        echo "📦 [Checkpoint] 最終チェックポイント (先頭40行):"
        echo ""
        head -40 "$CHECKPOINT_FILE"
        echo ""
        HAS_CONTEXT=true
    fi
fi

# --- 復帰指示 ---
if [ "$HAS_CONTEXT" = true ]; then
    echo "---"
    echo "👆 上記の情報を元に、前回の作業を継続してください。"
    echo "   PROGRESS.md の更新も忘れずに行ってください。"
fi

exit 0
