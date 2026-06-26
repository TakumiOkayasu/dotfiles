#!/bin/sh
# context-notifier.sh - コンテキスト使用率から auto-compact 推奨を通知する
#
# 責務:
#   - statusLine payload (stdin) の used_percentage を読み、閾値超過時に
#     statusLine へ追記する推奨メッセージを stdout へ 1 行出す
#   - 閾値未満・取得不能・不正値のときは何も出さない (statusLine をそのまま保つ)
#
# 背景:
#   used_percentage は statusLine の rich payload のみが持つ事前計算値
#   (https://code.claude.com/docs/en/statusline.md)。hook stdin には渡らないため、
#   本スクリプトは statusLine wrapper から payload を受け取って判定する。
#
# 入力: statusLine payload JSON (.context_window.used_percentage)
# 出力: 推奨メッセージ 1 行、または空

# 閾値 (used_percentage)。WARN=軽警告、COMPACT=auto-compact 推奨
WARN_THRESHOLD=50
COMPACT_THRESHOLD=75

# 単体実行 (TTY) では stdin が無く cat がハングするため即終了する
[ -t 0 ] && exit 0

JQ=$(command -v jaq 2>/dev/null || command -v jq 2>/dev/null || echo "")
[ -z "$JQ" ] && exit 0

INPUT=$(cat)
RAW=$(printf '%s' "$INPUT" | "$JQ" -r '.context_window.used_percentage // empty' 2>/dev/null)
[ -z "$RAW" ] && exit 0

# 整数部のみ採用 (小数点以下切り捨て)
INT=${RAW%%.*}

# 10 進数字のみ許容。符号/全角/文字/空 (".5" 等) は誤通知せず無出力
case "$INT" in
    '' | *[!0-9]*) exit 0 ;;
esac

# 先頭ゼロ除去 (8 進誤解釈と桁数誤判定を防ぐ。シェル組み込みで fork を避ける)
while [ "${INT#0}" != "$INT" ] && [ "${#INT}" -gt 1 ]; do
    INT="${INT#0}"
done

# 桁あふれガード: 4 桁以上 (>=1000%) は破損値とみなし無出力
[ "${#INT}" -gt 3 ] && exit 0

PCT=$INT
[ "$PCT" -gt 100 ] && PCT=100

if [ "$PCT" -ge "$COMPACT_THRESHOLD" ]; then
    printf '🚨 %d%% /compact 推奨' "$PCT"
elif [ "$PCT" -ge "$WARN_THRESHOLD" ]; then
    printf '⚠️ %d%%' "$PCT"
fi
exit 0
