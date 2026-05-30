#!/bin/sh
# sycophancy-check.sh - 応答冒頭の追従句 (おべっか) を検出して警告 (Stop)
#
# 責務:
#   - 直近の実ユーザー入力に対する Claude の応答冒頭に追従句
#     (You're right / おっしゃる通り / いい質問です 等) があれば警告する
#   - 停止はブロックしない (警告のみ)。global_CLAUDE.md の追従句禁止と整合させる
#
# 出力: 検出時のみ systemMessage を JSON で返す。停止は常に許可 (exit 0)
# 依存: jaq or jq, perl
#
# 配置先: ~/.claude/hooks/sycophancy-check.sh

# stdin がない場合はスキップ
if [ -t 0 ]; then
    exit 0
fi

INPUT=$(cat)

# jaq優先、jqフォールバック (見つからなければ何もしない)
JQ=$(command -v jaq 2>/dev/null || command -v jq 2>/dev/null || echo "")
if [ -z "$JQ" ]; then
    exit 0
fi

TRANSCRIPT_PATH=$(printf '%s\n' "$INPUT" | "$JQ" -r '.transcript_path // ""' 2>/dev/null) || TRANSCRIPT_PATH=""
if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
    exit 0
fi

# --- 直近の実ユーザーターン以降の「最初の assistant text」の冒頭を抽出 ---
# 実ユーザー入力 (tool_result でない user 行) でリセットし、その後の最初の text を取る
# 先頭の ASCII 記号を除いた冒頭 90 文字のみを判定対象にする
HEAD=$(tail -200 "$TRANSCRIPT_PATH" | "$JQ" -s -r '
    [ .[] | select(.isSidechain != true) ] as $rows
    | ( [ $rows | to_entries[]
          | select(.value.type == "user"
              and (.value.isMeta != true)
              and (.value.message.content as $c | ($c | type) as $ct
                   | ($ct == "string"
                      and (($c | (startswith("<task-notification>")
                                  or startswith("Stop hook feedback:")
                                  or startswith("Your tool call was malformed")
                                  or startswith("[Request interrupted"))) | not))
                     or ($ct == "array" and ($c | map(.type) | any(. == "text")))))
          | .key ] | (.[-1]) ) as $u
    | (($u // -1) + 1) as $start
    | [ $rows[$start:][]
        | select(.type == "assistant")
        | .message.content[]?
        | select(.type == "text") | .text ]
    | (.[0] // "")
    | sub("^[\\s>#*\"\\u0027`\\-]+"; "")
    | .[0:90]
' 2>/dev/null) || HEAD=""

if [ -z "$HEAD" ]; then
    exit 0
fi

# --- 追従句パターン (global_CLAUDE.md の禁止句と整合) ---
# 大文字小文字を無視するため小文字化した版で英語句を判定
HEAD_LOWER=$(printf '%s' "$HEAD" | tr 'A-Z' 'a-z')

HIT=""
# 英語の追従句 (小文字化後に部分一致)
for kw in "you're right" "you are right" "you're absolutely right" "good question" "great question" "excellent question"; do
    case "$HEAD_LOWER" in
        *"$kw"*) HIT="$kw"; break ;;
    esac
done

# 日本語の追従句 (原文で部分一致)
if [ -z "$HIT" ]; then
    for kw in "おっしゃる通り" "仰る通り" "いい質問" "良い質問" "鋭いご指摘" "鋭い指摘" "素晴らしいご質問" "さすが"; do
        case "$HEAD" in
            *"$kw"*) HIT="$kw"; break ;;
        esac
    done
fi

if [ -z "$HIT" ]; then
    exit 0
fi

# --- 警告のみ (停止はブロックしない) ---
MSG="⚠️ [おべっか検出] 応答冒頭に追従句「${HIT}」を検出しました。global_CLAUDE.md の方針: 同意は根拠とセットでのみ示し、追従句で応答を始めない。次の応答から是正してください。"

# jq で安全に JSON 化 (systemMessage はユーザーに表示される)
printf '%s' "$MSG" | "$JQ" -R -s '{systemMessage: .}' 2>/dev/null || exit 0

exit 0
