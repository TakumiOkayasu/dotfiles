#!/bin/sh
# plan-mode-question-detect.sh - Planモード中のインテント検出
#
# 責務: Planモード中にrewind/fork/完了の意図を検出し、コマンドを提案
# イベント: UserPromptSubmit
# 出力: stdout → Claudeのコンテキストに注入
# 依存: jaq or jq

if [ -t 0 ]; then
    exit 0
fi

INPUT=$(cat)

JQ=$(command -v jaq 2>/dev/null || command -v jq 2>/dev/null || echo "")
if [ -z "$JQ" ]; then
    exit 0
fi

USER_PROMPT=$(printf '%s\n' "$INPUT" | "$JQ" -r '.user_prompt // ""' 2>/dev/null) || USER_PROMPT=""
TRANSCRIPT_PATH=$(printf '%s\n' "$INPUT" | "$JQ" -r '.transcript_path // ""' 2>/dev/null) || TRANSCRIPT_PATH=""

if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
    exit 0
fi

if [ -z "$USER_PROMPT" ]; then
    exit 0
fi

# Planモード判定 (末尾200行: 長いPlanセッション対応)
if ! tail -200 "$TRANSCRIPT_PATH" | grep -q "Plan mode is active" 2>/dev/null; then
    exit 0
fi

# インテント検出 (case文: grep 3回→外部プロセス0回)
# 英語キーワードは小文字化して統一比較
PROMPT_LOWER=$(printf '%s' "$USER_PROMPT" | tr '[:upper:]' '[:lower:]')

case "$PROMPT_LOWER" in
    *戻る*|*やり直*|*前の状態*|*元に戻*|*取り消*|*巻き戻*|*undo*|*revert*|*rewind*)
        echo "💡 /rewind で前の状態に戻せます" ;;
    *分岐*|*別の方法*|*代替案*|*もう一つの案*|*別アプローチ*|*別案*|*他の方法*|*fork*)
        echo "💡 /fork で別の実装案を分岐できます" ;;
    *これでいい*|*問題ない*|*以上です*|*質問なし*|*実装に入*|*進めて*|*実装して*)
        echo "💡 Planモード終了→実装開始: Shift+Tab (ExitPlanMode)" ;;
esac

exit 0
