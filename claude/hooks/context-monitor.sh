#!/bin/sh
# context-monitor.sh - コンテキスト使用率監視 & PROGRESS.md更新催促
#
# 責務:
#   - transcript JSONL を解析してコンテキスト使用率を算出
#   - 閾値超過時にClaude側へ PROGRESS.md 更新を催促
#   - UserPromptSubmit / PostToolUse から呼ばれる
#
# 出力形式:
#   - UserPromptSubmit: プレーンテキスト(stdout → Claudeのコンテキストに注入)
#   - PostToolUse: JSON(additionalContext)
#
# 依存: jaq or jq, perl

# set -e を使わない（exit 1 = hookエラー = 許可扱いリスク）

# stdin がない場合はスキップ
if [ -t 0 ]; then
    exit 0
fi

INPUT=$(cat)

# jaq優先、jqフォールバック（見つからない場合は空文字→許可）
JQ=$(command -v jaq 2>/dev/null || command -v jq 2>/dev/null || echo "")
if [ -z "$JQ" ]; then
    exit 0
fi

HOOK_EVENT=$(printf '%s\n' "$INPUT" | "$JQ" -r '.hook_event_name // ""' 2>/dev/null) || HOOK_EVENT=""
TRANSCRIPT_PATH=$(printf '%s\n' "$INPUT" | "$JQ" -r '.transcript_path // ""' 2>/dev/null) || TRANSCRIPT_PATH=""
CWD=$(printf '%s\n' "$INPUT" | "$JQ" -r '.cwd // ""' 2>/dev/null) || CWD=""

# transcript がなければスキップ
if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
    exit 0
fi

# --- コンテキスト使用率算出 ---
# transcript JSONL の末尾から最新の usage を持つ非sidechain行を取得
# perl で高速に末尾から逆順走査
USAGE_LINE=$(tail -200 "$TRANSCRIPT_PATH" | perl -MJSON::PP -ne '
    BEGIN { $latest = undef; $latest_ts = ""; }
    chomp;
    eval {
        my $d = decode_json($_);
        return if ($d->{isSidechain} // 0);
        return if ($d->{isApiErrorMessage} // 0);
        return unless $d->{message} && $d->{message}{usage};
        my $ts = $d->{timestamp} // "";
        if ($ts gt $latest_ts) {
            $latest_ts = $ts;
            $latest = $d->{message}{usage};
        }
    };
    END {
        if ($latest) {
            my $input = ($latest->{input_tokens} // 0);
            my $cache = ($latest->{cache_read_input_tokens} // 0);
            print $input + $cache;
        } else {
            print "0";
        }
    }
' 2>/dev/null || echo "0")

# モデルのコンテキスト上限 (tokens)
# Sonnet: 200k, Opus: 200k
MODEL_LIMIT=200000

if [ "$USAGE_LINE" -eq 0 ] 2>/dev/null; then
    exit 0
fi

# 使用率算出 (整数パーセント)
USAGE_PCT=$((USAGE_LINE * 100 / MODEL_LIMIT))

# --- 閾値判定 ---
WARN_THRESHOLD=70
CRITICAL_THRESHOLD=85

if [ "$USAGE_PCT" -lt "$WARN_THRESHOLD" ]; then
    # 安全圏: 何もしない
    exit 0
fi

# PROGRESS.md のパス
PROGRESS_FILE="${CWD}/.claude/progress.md"

# メッセージ生成
if [ "$USAGE_PCT" -ge "$CRITICAL_THRESHOLD" ]; then
    MSG="🚨 [Context ${USAGE_PCT}%] コンテキスト使用率が${USAGE_PCT}%に到達。auto-compact間近です。即座に ${PROGRESS_FILE} を更新してください。現在のタスク状況・設計判断の理由・未完了事項を漏れなく記録してください。Planモード中の場合は一度抜けてファイルを更新し、再度Planに戻ってください。"
else
    MSG="⚠️ [Context ${USAGE_PCT}%] コンテキスト使用率が${USAGE_PCT}%です。${PROGRESS_FILE} が最新か確認し、必要なら更新してください。特に設計判断の理由(Why)は失われやすいので優先的に記録してください。"
fi

# --- 出力(呼び出し元に応じたフォーマット) ---
case "$HOOK_EVENT" in
    UserPromptSubmit)
        # stdout がそのまま Claude のコンテキストに注入される
        echo "$MSG"
        ;;
    PostToolUse|PostToolUseFailure)
        # PostToolUse hook: JSON で additionalContext
        ESCAPED_MSG=$(printf '%s' "$MSG" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
        cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "${ESCAPED_MSG}"
  }
}
EOF
        ;;
    *)
        # 未知の呼び出し元: stderr に出力(verbose mode)
        echo "$MSG" >&2
        ;;
esac

exit 0
