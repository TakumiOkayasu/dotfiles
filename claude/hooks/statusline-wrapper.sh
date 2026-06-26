#!/bin/sh
# statusline-wrapper.sh - statusLine wrapper (ccstatusline + auto-compact 通知)
#
# 責務:
#   - statusLine payload を ccstatusline へ渡して statusline を表示する
#   - 同じ payload を context-notifier.sh へ渡し、閾値超過時の auto-compact
#     推奨メッセージを statusline 末尾へ追記する
#   - ccstatusline のバージョンを固定し @latest の破壊的変更を避ける
#
# 有効化: settings.json の statusLine.command を本スクリプトに向ける
# 出力: ccstatusline の statusline 表示 (+ 推奨メッセージ)

CCSTATUSLINE="ccstatusline@latest"

# stdin が無ければ表示のみ (payload 無しでは通知判定不可)
if [ -t 0 ]; then
    exec bunx -y "$CCSTATUSLINE"
fi

SCRIPT_DIR=$(dirname "$0")
INPUT=$(cat)
STATUS=$(printf '%s' "$INPUT" | bunx -y "$CCSTATUSLINE")
NOTE=$(printf '%s' "$INPUT" | "$SCRIPT_DIR/context-notifier.sh" 2>/dev/null)

# STATUS が空 (ccstatusline 失敗) でも先頭空白を出さない
printf '%s\n' "${STATUS:+$STATUS }$NOTE"

