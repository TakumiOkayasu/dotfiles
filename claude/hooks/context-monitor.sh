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

# 入力フィールドを 1 回の jq で取得 (高頻度 hook のため fork を最小化)
# jq は値ごとに改行出力するため、空フィールドも空行として位置を保てる
{
    read -r HOOK_EVENT
    read -r TRANSCRIPT_PATH
    read -r CWD
    read -r SESSION_ID
} <<EOF
$(printf '%s\n' "$INPUT" | "$JQ" -r '.hook_event_name // "", .transcript_path // "", .cwd // "", .session_id // ""' 2>/dev/null)
EOF

# パストラバーサル対策: session_id は外部 (Claude Code) 由来。
# キャッシュファイル名に使うため、パス要素として安全な文字のみ許容する
SESSION_ID=$(printf '%s' "$SESSION_ID" | tr -cd 'A-Za-z0-9_-')
[ "${#SESSION_ID}" -gt 128 ] && SESSION_ID=""

DEFAULT_CONTEXT_WINDOW_SIZE=200000
USABLE_CONTEXT_RATIO_NUM=4
USABLE_CONTEXT_RATIO_DEN=5
PERCENT_SCALE=100
WARN_THRESHOLD=50
CRITICAL_THRESHOLD=75
CACHE_MAX_AGE_SEC=90

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

# NOTE: PostToolUse / UserPromptSubmit hook の stdin には context_window も model も
# 渡されない (公式仕様 https://code.claude.com/docs/en/hooks.md)。下記 2 関数は当該
# イベントでは常に空文字を返すが、将来 API が hook へ model/context_window を渡す変更に
# 備えて保持する。通常の使用率算出は statusline キャッシュ経由 (下記) が担う。
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
    tail -200 -- "$TRANSCRIPT_PATH" | "$JQ" -s -r '
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

# statusline wrapper が書いた権威あるキャッシュから "実効上限 使用トークン" を解決する。
# 新鮮 (CACHE_MAX_AGE_SEC 以内) かつ context_window_size が有効な場合のみ 1 行出力する。
# 出力なし (空) = キャッシュ無効 → 呼び出し側で resolve_model_limit にフォールバックさせる。
resolve_from_cache() {
    cache_file="${XDG_CACHE_HOME:-$HOME/.cache}/claude-context/context-${SESSION_ID}.json"
    [ -n "$SESSION_ID" ] && [ -f "$cache_file" ] || return 0

    # macOS の date は %s 非対応のケースあり。空なら新鮮さ判定をスキップ (安全側 = fallback)
    now=$(date +%s 2>/dev/null || echo "")
    mtime=$(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null || echo "")
    [ -n "$now" ] && [ -n "$mtime" ] && [ "$((now - mtime))" -le "$CACHE_MAX_AGE_SEC" ] || return 0

    # cache の 2 値を 1 回の jq で取得 (値ごと改行 → 空行で位置保持)
    {
        read -r cache_window
        read -r cache_length
    } <<EOF
$("$JQ" -r '.context_window_size // "", .context_length // ""' "$cache_file" 2>/dev/null)
EOF
    [ -n "$cache_window" ] && [ "$cache_window" -gt 0 ] 2>/dev/null || return 0

    usable=$((cache_window * USABLE_CONTEXT_RATIO_NUM / USABLE_CONTEXT_RATIO_DEN))
    if [ -n "$cache_length" ] && [ "$cache_length" -gt 0 ] 2>/dev/null; then
        printf '%s %s\n' "$usable" "$cache_length"
    else
        printf '%s %s\n' "$usable" "$USAGE_LINE"
    fi
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
USAGE_LINE=$(tail -200 -- "$TRANSCRIPT_PATH" | "$JQ" -s -r '
    [ .[]
        | select((.isSidechain // false) == false)
        | select((.isApiErrorMessage // false) == false)
        | select(.message.usage != null) ]
        | (max_by(.timestamp // "") // null) as $latest
        | if $latest == null then 0
      else (($latest.message.usage.input_tokens // 0) + ($latest.message.usage.cache_read_input_tokens // 0) + ($latest.message.usage.cache_creation_input_tokens // 0))
    end
' 2>/dev/null || echo "0")

if [ "$USAGE_LINE" -eq 0 ] 2>/dev/null; then
    exit 0
fi

# --- 分母 (window) と分子 (使用トークン) の決定 ---
# 優先: statusline wrapper が書いた権威あるキャッシュ (真の context_window_size)。
# hook stdin には context_window/model が来ない (公式仕様) ため、これが唯一の正確な源。
# フォールバック: model id 推定 (resolve_model_limit) + transcript 由来の使用トークン。
cache_resolved=$(resolve_from_cache)
if [ -n "$cache_resolved" ]; then
    USABLE_LIMIT=${cache_resolved% *}
    USED_TOKENS=${cache_resolved#* }
else
    USABLE_LIMIT=$(resolve_model_limit)
    USED_TOKENS="$USAGE_LINE"
fi

# 使用率算出 (整数パーセント、100% でキャップ = ccstatusline 準拠)
USAGE_PCT=$((USED_TOKENS * PERCENT_SCALE / USABLE_LIMIT))
if [ "$USAGE_PCT" -gt "$PERCENT_SCALE" ]; then
    USAGE_PCT="$PERCENT_SCALE"
fi

# --- 閾値判定 ---
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
        # PostToolUse hook: JSON で additionalContext (jq でエスケープを確実化)
        printf '%s' "$MSG" | "$JQ" -Rs '{
            hookSpecificOutput: {
                hookEventName: "PostToolUse",
                additionalContext: .
            }
        }'
        ;;
    *)
        # 未知の呼び出し元: stderr に出力(verbose mode)
        echo "$MSG" >&2
        ;;
esac

exit 0
