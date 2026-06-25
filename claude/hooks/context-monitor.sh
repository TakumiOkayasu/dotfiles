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
# 依存: jaq or jq

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

DEFAULT_CONTEXT_WINDOW_SIZE=200000
USABLE_CONTEXT_RATIO_NUM=4
USABLE_CONTEXT_RATIO_DEN=5
PERCENT_SCALE=100

# context-model-getter.sh は同一 hooks ディレクトリに symlink される兄弟スクリプト
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd) || SCRIPT_DIR=""
GETTER="${SCRIPT_DIR}/context-model-getter.sh"

trim() {
    awk '{
        sub(/^[[:space:]]+/, "")
        sub(/[[:space:]]+$/, "")
        print
    }'
}

hook_context_window_size() {
    # shellcheck disable=SC2016
    printf '%s\n' "$INPUT" | "$JQ" -r '
        [
            .context_window.max_tokens?,
            .context_window.maxTokens?,
            .context_window.size?,
            .contextWindowSize?,
            .model.context_window?,
            .model.contextWindow?,
            .model.context_window_size?,
            .model.contextWindowSize?
        ]
        | map(select(. != null and . != ""))
        | .[0] // ""
    ' 2>/dev/null || true
}

hook_model_identifier() {
    # shellcheck disable=SC2016
    printf '%s\n' "$INPUT" | "$JQ" -r '
        def model_text($m):
            if ($m | type) == "string" then $m
            elif ($m | type) == "object" then
                [($m.id? // ""), ($m.display_name? // $m.displayName? // "")]
                | map(select(. != ""))
                | join(" ")
            else "" end;
        [
            model_text(.model?),
            (.model_id? // ""),
            (.modelId? // "")
        ]
        | map(select(. != ""))
        | .[0] // ""
    ' 2>/dev/null | trim || true
}

transcript_model_identifier() {
    # shellcheck disable=SC2016
    tail -200 "$TRANSCRIPT_PATH" | "$JQ" -s -r '
        def model_text($m):
            if ($m | type) == "string" then $m
            elif ($m | type) == "object" then
                [($m.id? // ""), ($m.display_name? // $m.displayName? // "")]
                | map(select(. != ""))
                | join(" ")
            else "" end;
        [
            .[]
            | select((.isSidechain // false) == false)
            | select((.isApiErrorMessage // false) == false)
            | select(.message.usage != null)
        ]
        | (max_by(.timestamp // "") // {}) as $latest
        | [
            model_text($latest.message.model?),
            model_text($latest.model?),
            ($latest.message.model_id? // ""),
            ($latest.message.modelId? // ""),
            ($latest.model_id? // ""),
            ($latest.modelId? // "")
        ]
        | map(select(. != ""))
        | .[0] // ""
    ' 2>/dev/null | trim || true
}

# 使用率の分母として、auto-compact が実際に効く実効上限 (usableTokens) を
# context-model-getter.sh から取得する。window size 算出ロジックは getter に集約し、
# ここでは入力 (context window size / model identifier) の受け渡しだけを担う。
resolve_model_limit() {
    context_window_size=$(hook_context_window_size)
    model_identifier=$(hook_model_identifier)
    if [ -z "$model_identifier" ]; then
        model_identifier=$(transcript_model_identifier)
    fi

    if [ -x "$GETTER" ]; then
        set --
        if [ -n "$context_window_size" ]; then
            set -- "$@" --context-window-size "$context_window_size"
        fi
        if [ -n "$model_identifier" ]; then
            set -- "$@" -- "$model_identifier"
        fi

        getter_json=$("$GETTER" "$@" 2>/dev/null) || getter_json=""
        usable_tokens=$(printf '%s\n' "$getter_json" \
            | "$JQ" -r '.usableTokens // ""' 2>/dev/null) || usable_tokens=""
        if [ -n "$usable_tokens" ] && [ "$usable_tokens" -gt 0 ] 2>/dev/null; then
            printf '%s\n' "$usable_tokens"
            return 0
        fi
    fi

    # getter 不在時のフォールバック: 既定 window の実効上限 (0.8)
    printf '%s\n' "$((DEFAULT_CONTEXT_WINDOW_SIZE * USABLE_CONTEXT_RATIO_NUM / USABLE_CONTEXT_RATIO_DEN))"
}

# transcript がなければスキップ
if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
    exit 0
fi

# --- コンテキスト使用率算出 ---
# transcript JSONL の末尾から最新の usage を持つ非sidechain行を取得
# timestamp 最大 (ISO 文字列の辞書順 = 時系列順) の usage を jq で抽出
# jq変数 $latest をシェル展開させないため単一引用符で囲む (二重引用符だと空展開で常に0になる)
# shellcheck disable=SC2016
USAGE_LINE=$(tail -200 "$TRANSCRIPT_PATH" | "$JQ" -s -r '
    [ .[]
        | select((.isSidechain // false) == false)
        | select((.isApiErrorMessage // false) == false)
        | select(.message.usage != null) ]
        | (max_by(.timestamp // "") // null) as $latest
        | if $latest == null then 0
      else (($latest.message.usage.input_tokens // 0) + ($latest.message.usage.cache_read_input_tokens // 0))
    end
' 2>/dev/null || echo "0")

if [ "$USAGE_LINE" -eq 0 ] 2>/dev/null; then
    exit 0
fi

# 分母は full window ではなく auto-compact が効く実効上限 (usableTokens)
USABLE_LIMIT=$(resolve_model_limit)

# 使用率算出 (整数パーセント)
USAGE_PCT=$((USAGE_LINE * PERCENT_SCALE / USABLE_LIMIT))

# --- 閾値判定 ---
WARN_THRESHOLD=50
CRITICAL_THRESHOLD=75

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
