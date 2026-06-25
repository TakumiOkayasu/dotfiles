#!/bin/sh
# statusline-context-cache.sh - statusLine payload の context_window をキャッシュ
#
# 責務:
#   - statusLine の rich payload (context_window / model を含む) を受け取り、
#     権威ある context window size / 使用量をキャッシュファイルへ書く
#   - 表示は ccstatusline にパススルーする
#
# 背景:
#   context-monitor.sh は hook のため、公式仕様上 stdin に context_window も model も
#   渡されない (https://code.claude.com/docs/en/hooks.md)。これらを受け取れるのは
#   statusLine のみ。本 wrapper が橋渡しし、hook がキャッシュ経由で真の window を読む。
#
# 有効化:
#   settings.json の statusLine.command を本スクリプトに向けること。
#   直接 ccstatusline を指している場合はキャッシュが書かれない。
#
# 出力: stdin をそのまま ccstatusline へ渡した結果 (statusline 表示)

# stdin が無ければそのまま ccstatusline へ委譲
if [ -t 0 ]; then
    exec bunx -y ccstatusline@latest
fi

INPUT=$(cat)

# --- キャッシュ書き込み (失敗は無視 = 表示を壊さない) ---
# jaq 優先、jq フォールバック
JQ=$(command -v jaq 2>/dev/null || command -v jq 2>/dev/null || echo "")
if [ -n "$JQ" ] && [ -n "$HOME" ]; then
    SESSION_ID=$(printf '%s' "$INPUT" | "$JQ" -r '.session_id // ""' 2>/dev/null) || SESSION_ID=""
    # パストラバーサル対策: session_id は外部由来。パス要素として安全な文字のみ許容
    SESSION_ID=$(printf '%s' "$SESSION_ID" | tr -cd 'A-Za-z0-9_-')
    [ "${#SESSION_ID}" -gt 128 ] && SESSION_ID=""
    if [ -n "$SESSION_ID" ]; then
        CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/claude-context"
        if mkdir -p "$CACHE_DIR" 2>/dev/null; then
            # context_length = current_usage を context window 占有トークンへ正規化
            # (object 形式は input + cache_creation + cache_read、number 形式はそのまま)
            # shellcheck disable=SC2016
            printf '%s' "$INPUT" | "$JQ" -c '
                (.context_window.current_usage) as $u
                | {
                    session_id: (.session_id // ""),
                    context_window_size: (.context_window.context_window_size // null),
                    used_percentage: (.context_window.used_percentage // null),
                    context_length: (
                        if ($u | type) == "object" then
                            (($u.input_tokens // 0) + ($u.cache_creation_input_tokens // 0) + ($u.cache_read_input_tokens // 0))
                        elif ($u | type) == "number" then $u
                        else null end
                    )
                }' > "$CACHE_DIR/context-${SESSION_ID}.json" 2>/dev/null || true
        fi
    fi
fi

# 表示は必ず ccstatusline へパススルー (キャッシュ書き込みの成否に関わらず)
printf '%s' "$INPUT" | bunx -y ccstatusline@latest
