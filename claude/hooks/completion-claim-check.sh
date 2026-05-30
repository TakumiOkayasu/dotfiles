#!/bin/sh
# completion-claim-check.sh - テスト pass ログ無しの完了報告を警告 (Stop)
#
# 責務:
#   - 直近の実ユーザーターン以降の応答に「完了報告」表現があり、かつ
#     同区間にテスト実行の痕跡 (Bash tool_use) が無い場合に警告する (停止はブロックしない)
#   - global_CLAUDE.md「テスト pass のログを示してから完了報告する」と整合させる
#   - 実ユーザーターン判定では isMeta 行とハーネス注入 (task-notification 等) を除外する
#
# 出力: 該当時のみ {"systemMessage":...} を返す。それ以外は exit 0
# 二重発火抑制: stop_hook_active が true の場合は判定を skip
# 依存: jaq or jq
#
# 配置先: ~/.claude/hooks/completion-claim-check.sh

# stdin がない場合はスキップ
if [ -t 0 ]; then
    exit 0
fi

INPUT=$(cat)

JQ=$(command -v jaq 2>/dev/null || command -v jq 2>/dev/null || echo "")
if [ -z "$JQ" ]; then
    exit 0
fi

# ループ防止: 既に Stop hook 起因で再実行中なら判定しない
STOP_ACTIVE=$(printf '%s\n' "$INPUT" | "$JQ" -r '.stop_hook_active // false' 2>/dev/null) || STOP_ACTIVE="false"
if [ "$STOP_ACTIVE" = "true" ]; then
    exit 0
fi

TRANSCRIPT_PATH=$(printf '%s\n' "$INPUT" | "$JQ" -r '.transcript_path // ""' 2>/dev/null) || TRANSCRIPT_PATH=""
if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
    exit 0
fi

# --- 直近の実ユーザーターン以降の「応答テキスト全文」と「Bash コマンド群」を抽出 ---
# 出力形式: text を結合し、区切り "<<<CMDS>>>" 以降に Bash command を結合 (jq で一括抽出)
EXTRACT=$(tail -300 "$TRANSCRIPT_PATH" | "$JQ" -s -r '
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
    | $rows[$start:] as $resp
    | ([ $resp[] | select(.type == "assistant") | .message.content[]?
         | select(.type == "text") | .text ] | join("\n"))
      + "\n<<<CMDS>>>\n"
      + ([ $resp[] | select(.type == "assistant") | .message.content[]?
           | select(.type == "tool_use" and .name == "Bash") | .input.command ] | join("\n"))
' 2>/dev/null) || EXTRACT=""

if [ -z "$EXTRACT" ]; then
    exit 0
fi

RESPONSE_TEXT=${EXTRACT%%<<<CMDS>>>*}
BASH_CMDS=${EXTRACT#*<<<CMDS>>>}

# --- 完了報告表現の検出 ---
# 誤検知を抑えるため、明確な「完了」断定のみを対象にする
CLAIM=""
for kw in "完了しました" "実装が完了" "修正が完了" "対応が完了" "実装できました" "修正できました" "対応できました" "実装しました" "修正しました" "対応しました" "完成しました" "完了です"; do
    case "$RESPONSE_TEXT" in
        *"$kw"*) CLAIM="$kw"; break ;;
    esac
done

# 完了報告が無ければ何もしない
if [ -z "$CLAIM" ]; then
    exit 0
fi

# --- テスト実行痕跡の検出 (Bash command 内) ---
# いずれかにマッチすればテストを実行したとみなしブロックしない
HAS_TEST=0
for tp in "pytest" "jest" "vitest" " test" "test " "go test" "cargo test" "npm t" "yarn test" "pnpm test" "gradlew" "mvn test" "dotnet test" "rspec" "phpunit" "compose" "docker run"; do
    case "$BASH_CMDS" in
        *"$tp"*) HAS_TEST=1; break ;;
    esac
done

if [ "$HAS_TEST" -eq 1 ]; then
    exit 0
fi

# --- テスト痕跡無しの完了報告 → 警告 (停止はブロックしない) ---
MSG="⚠️ [完了報告チェック] 完了報告「${CLAIM}」を検出しましたが、直近の応答にテスト/検証コマンドの実行痕跡がありません。global_CLAUDE.md の方針: テスト pass のログを示してから完了報告する。テストを実行して pass を確認するか、検証をスキップした理由を明示してください。"

printf '%s' "$MSG" | "$JQ" -R -s '{systemMessage: .}' 2>/dev/null || exit 0

exit 0
