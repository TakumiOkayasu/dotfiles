#!/bin/sh
# SessionStart hook: vendor スキルを1日1回 git pull で更新

VENDOR_DIR="${HOME}/.claude/vendor/agent-skills"
STAMP_FILE="${VENDOR_DIR}/.last-update"
INTERVAL=86400  # 24時間（秒）

# vendor未導入ならスキップ
[ ! -d "$VENDOR_DIR/.git" ] && exit 0

# 最終更新から24時間以内ならスキップ
if [ -f "$STAMP_FILE" ]; then
    last=$(cat "$STAMP_FILE" 2>/dev/null || echo 0)
    case "$last" in *[!0-9]*) last=0 ;; esac
    now=$(date +%s)
    elapsed=$((now - last))
    [ "$elapsed" -lt "$INTERVAL" ] && exit 0
fi

# タイムアウト付きでpull（起動を遅くしない）
_timeout_cmd=""
command -v timeout >/dev/null 2>&1 && _timeout_cmd="timeout 5"
if ${_timeout_cmd:-} git -C "$VENDOR_DIR" pull --quiet 2>/dev/null; then
    date +%s > "$STAMP_FILE"
fi

exit 0
