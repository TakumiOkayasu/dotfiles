#!/bin/sh
# prompt-command-expand.sh - prompt command を prompts/commands/<name>.md に展開する
#
# 重要:
#   Codex CLI は先頭 `/` を built-in slash command として先に解釈する。
#   未登録の `/prompt:*` は UserPromptSubmit hook に届く前に拒否されるため、
#   interactive CLI では `prompt:<name>` または `prompt <name>` を使う。
#
# 対応形式:
#   prompt:feat ユーザー検索
#   prompt feat ユーザー検索
#   /prompt:feat ユーザー検索   # 非interactive/将来互換用。CLI TUIでは通常届かない。
#   /prompt feat ユーザー検索    # 非interactive/将来互換用。CLI TUIでは通常届かない。

# set -e を使わない（hookエラーで通常入力を壊さない）

[ -t 0 ] && exit 0

INPUT=$(cat)
JQ=$(command -v jaq 2>/dev/null || command -v jq 2>/dev/null || echo "")

if [ -n "$JQ" ]; then
    PROMPT=$(printf '%s\n' "$INPUT" | "$JQ" -r '.prompt // .user_prompt // .input // .message.content // ""' 2>/dev/null) || PROMPT=""
    CWD=$(printf '%s\n' "$INPUT" | "$JQ" -r '.cwd // ""' 2>/dev/null) || CWD=""
else
    PROMPT=$(printf '%s\n' "$INPUT" | sed -n 's/.*"prompt"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    CWD=""
fi

[ -z "$PROMPT" ] && exit 0

FIRST=$(printf '%s\n' "$PROMPT" | awk 'NR==1 { print $1 }')

case "$FIRST" in
    prompt:*)
        NAME=$(printf '%s' "$FIRST" | sed 's#^prompt:##')
        ARGS=$(printf '%s\n' "$PROMPT" | sed "1s#^prompt:${NAME}[[:space:]]*##")
        DISPLAY="prompt:${NAME}"
        ;;
    prompt)
        NAME=$(printf '%s\n' "$PROMPT" | awk 'NR==1 { print $2 }')
        ARGS=$(printf '%s\n' "$PROMPT" | sed "1s#^prompt[[:space:]]\+${NAME}[[:space:]]*##")
        DISPLAY="prompt ${NAME}"
        ;;
    /prompt:*)
        NAME=$(printf '%s' "$FIRST" | sed 's#^/prompt:##')
        ARGS=$(printf '%s\n' "$PROMPT" | sed "1s#^/prompt:${NAME}[[:space:]]*##")
        DISPLAY="/prompt:${NAME}"
        ;;
    /prompt)
        NAME=$(printf '%s\n' "$PROMPT" | awk 'NR==1 { print $2 }')
        ARGS=$(printf '%s\n' "$PROMPT" | sed "1s#^/prompt[[:space:]]\+${NAME}[[:space:]]*##")
        DISPLAY="/prompt ${NAME}"
        ;;
    *)
        exit 0
        ;;
esac

if [ -z "$NAME" ]; then
    exit 0
fi

case "$NAME" in
    list|help)
        ;;
    *[!A-Za-z0-9_-]*)
        echo "⚠️ [prompt-command] prompt name に使用できるのは英数字・_・- のみです: ${NAME}"
        exit 0
        ;;
esac

if SCRIPT_DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd -P); then
    :
else
    SCRIPT_DIR=$(dirname "$0")
fi

list_dirs() {
    [ -n "$CWD" ] && printf '%s\n' "$CWD/codex/prompts/commands"
    [ -n "$CWD" ] && printf '%s\n' "$CWD/.codex/prompts/commands"
    printf '%s\n' "$HOME/.codex/prompts/commands"
    printf '%s\n' "$SCRIPT_DIR/../prompts/commands"
}

list_commands() {
    list_dirs | while IFS= read -r dir; do
        [ -d "$dir" ] || continue
        find "$dir" -maxdepth 1 -type f -name '*.md' 2>/dev/null | sed 's#.*/##; s#\.md$##'
    done | sort -u
}

if [ "$NAME" = "list" ] || [ "$NAME" = "help" ]; then
    COMMANDS=$(list_commands | tr '\n' ' ' | sed 's/[[:space:]]*$//')
    cat <<HELP
📚 [prompt-command] 使用可能なカスタムプロンプト

${COMMANDS}

使用例:
- prompt:feat ユーザー検索機能を追加
- prompt:fix 特定入力で500になる
- prompt:deep-review HEADとの差分

注意:
- Codex CLI TUI では /prompt:* は未登録 slash command として拒否されます。
- 先頭スラッシュなしの prompt:* を使ってください。
HELP
    exit 0
fi

PROMPT_FILE=""
list_dirs | while IFS= read -r dir; do
    [ -n "$PROMPT_FILE" ] && continue
    [ -f "$dir/${NAME}.md" ] && printf '%s\n' "$dir/${NAME}.md"
done | {
    read -r PROMPT_FILE
    if [ -z "$PROMPT_FILE" ]; then
        echo "⚠️ [prompt-command] 未定義のカスタムプロンプト: prompt:${NAME}"
        echo "利用可能一覧は prompt:list を入力してください。"
        exit 0
    fi

    BODY=$(cat "$PROMPT_FILE")
    EXPANDED=$(printf '%s\n' "$BODY" | awk -v args="$ARGS" '{ gsub(/\$ARGUMENTS/, args); print }')

    cat <<OUT
📌 [prompt-command expanded: prompt:${NAME}]

ユーザーは repo-local custom prompt command "${DISPLAY}" を実行しました。
下記の展開済みプロンプトを、このターンの主指示として扱ってください。
元の "${DISPLAY}" 文字列は実行対象ではなく、展開トリガーです。

## Arguments

${ARGS}

## Expanded prompt

${EXPANDED}
OUT
}

exit 0
