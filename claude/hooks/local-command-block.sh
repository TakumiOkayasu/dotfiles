#!/bin/sh
# PreToolUse hook - ローカル環境のコマンド実行をブロック
# Dockerコンテナ内で実行するべきコマンドを直接実行しようとした場合にブロック
# + 難読化によるバイパス検知 (文字列分割, base64, hex, eval, curl|sh 等)
# + コマンドチェーン/パイプ/サブシェル内のコマンドも検知
#
# 使い方 (手動実行):
#   echo '{"tool_input":{"command":"python3 script.py"}}' | ./local-command-block.sh
#
# デバッグ:
#   CLAUDE_HOOK_DEBUG=1 で /tmp/claude_hook_debug.log にログ出力

# set -e もtrap ERRも使わない（POSIX sh非互換 + exit 1 = 許可扱いリスク）
# 代わりに各操作で明示的にエラーチェックし、失敗時は安全側（ブロック: exit 2）にフォールバック

# --- デバッグログ ---
DEBUG_LOG="/tmp/claude_hook_debug.log"
debug_log() {
    [ "${CLAUDE_HOOK_DEBUG:-0}" = "1" ] || return 0
    printf '[%s] local-command-block: %s\n' "$(date '+%H:%M:%S')" "$1" >> "$DEBUG_LOG"
}

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    cat <<'EOF'
local-command-block.sh - ローカル環境のコマンド実行をブロック

使い方:
  echo '{"tool_input":{"command":"python3 script.py"}}' | ./local-command-block.sh

説明:
  Python, Node.js, PHP, Ruby, Go などのコマンドを
  Docker外で直接実行しようとした場合にブロックします。
  docker exec/run/compose 経由の実行は許可されます。
  難読化によるバイパス (base64, eval, hex, curl|sh 等) も検知します。
  チェーンコマンド (&&, ||, ;) やサブシェル $() 内のコマンドも検知します。

デバッグ:
  CLAUDE_HOOK_DEBUG=1 で /tmp/claude_hook_debug.log にログ出力

依存関係:
  jaq または jq が必要です (jaq優先)
EOF
    exit 0
fi

if [ -t 0 ]; then
    echo "エラー: 標準入力がありません" >&2
    exit 1
fi

# --- コンテナ内判定: 早期exit ---
# 既にコンテナ内で作業中ならDocker経由強制は不要
# CLAUDE_HOOK_TEST_MODE=1 はテストハーネス専用（本hookがDocker内テストで常時スキップされるのを防ぐ）
if [ "${CLAUDE_HOOK_TEST_MODE:-0}" != "1" ]; then
    if [ -f /.dockerenv ] || [ -n "${REMOTE_CONTAINERS:-}" ]; then
        debug_log "CONTAINER_DETECTED: 早期許可"
        exit 0
    fi
fi

INPUT=$(cat)
debug_log "RAW_INPUT: $INPUT"

# --- ブロック対象パターン（jqチェックより前に定義すること） ---
# 言語ランタイム
_BLOCKED_RUNTIME='python[0-9.]*|node|bun|deno|php|ruby|go|perl'
# パッケージマネージャ / ビルドツール
_BLOCKED_PACKAGE='npm|npx|yarn|pnpm|corepack|pip3?|poetry|pipenv|conda|cargo|rustc|gem|bundler?|composer|mvn|gradlew?|sbt|dotnet|nuget'
# 注: バージョン/環境マネージャ (uv,pyenv,nvm,fnm,asdf,mise,volta等) はブロック対象外
BLOCKED_EXACT="^(${_BLOCKED_RUNTIME}|${_BLOCKED_PACKAGE})$"

# --- Docker経由かチェックする関数 ---
is_docker_command() {
    printf '%s\n' "$1" | grep -qE '^\s*(cd\s+[^;&|]+\s*(&&|;)\s*)*(docker\s+(exec|run|compose)|docker-compose)\b'
}

# --- コマンドセグメントから実行コマンド名を抽出 ---
get_first_command() {
    printf '%s' "$1" | awk '{
        for (i=1; i<=NF; i++) {
            if ($i ~ /^[A-Za-z_][A-Za-z0-9_]*=/) continue
            if ($i == "env") {
                i++
                while (i<=NF) {
                    if ($i ~ /^-.*[uSC]$/) { i += 2; continue }
                    if ($i ~ /^-/) { i++; continue }
                    if ($i ~ /^[A-Za-z_][A-Za-z0-9_]*=/) { i++; continue }
                    break
                }
                if (i>NF) exit
            }
            n = split($i, parts, "/")
            print parts[n]
            exit
        }
    }'
}

# --- 個別セグメントのブロックチェック関数 ---
check_segment() {
    _seg="$1"
    [ -z "$_seg" ] && return 0
    if is_docker_command "$_seg"; then
        return 0
    fi
    _cmd=$(get_first_command "$_seg")
    [ -z "$_cmd" ] && return 0
    if printf '%s\n' "$_cmd" | grep -qE "$BLOCKED_EXACT"; then
        debug_log "BLOCKED_SEGMENT: $_seg (cmd=$_cmd)"
        return 1
    fi
    return 0
}

# --- jq不在/JSON解析失敗時のフォールバックチェック ---
check_raw_input_fallback() {
    _raw_cmd=$(printf '%s' "$INPUT" | sed -n 's/.*"command"\s*:\s*"\([^"]*\)".*/\1/p')
    [ -z "$_raw_cmd" ] && return 0
    _fallback_segs=$(printf '%s' "$_raw_cmd" | awk '{
        gsub(/&&/, "\n"); gsub(/\|\|/, "\n"); gsub(/;/, "\n"); gsub(/\|/, "\n"); print
    }')
    _oldifs="$IFS"; IFS='
'
    for _fseg in $_fallback_segs; do
        _fseg=$(printf '%s' "$_fseg" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
        _fcmd=$(get_first_command "$_fseg")
        if [ -n "$_fcmd" ] && printf '%s\n' "$_fcmd" | grep -qE "$BLOCKED_EXACT" 2>/dev/null; then
            IFS="$_oldifs"
            return 1
        fi
    done
    IFS="$_oldifs"
    return 0
}

# jaq優先、jqフォールバック（見つからない場合は空文字）
JQ=$(command -v jaq 2>/dev/null || command -v jq 2>/dev/null || echo "")

if [ -z "$JQ" ]; then
    debug_log "JQ_NOT_FOUND: jq/jaqが見つからない"
    if ! check_raw_input_fallback; then
        echo "[安全フォールバック] jq/jaqが見つかりません。ブロック対象コマンドを検出。" >&2
        exit 2
    fi
    exit 0
fi

COMMAND=$(printf '%s\n' "$INPUT" | "$JQ" -r '.tool_input.command // ""' 2>/dev/null) || COMMAND=""
debug_log "PARSED_COMMAND: $COMMAND"

# --- jq解析失敗時の安全フォールバック ---
if [ -z "$COMMAND" ]; then
    if ! check_raw_input_fallback; then
        debug_log "SAFE_FALLBACK: JSON解析失敗、ブロック対象コマンド検出"
        echo "[安全フォールバック] JSON解析失敗。ブロック対象コマンドが含まれています。" >&2
        exit 2
    fi
    debug_log "EMPTY_COMMAND: 許可"
    exit 0
fi

# --- 層1a: メインコマンド + チェーン/パイプ/サブシェル分割チェック ---

# まずメインコマンド全体がDocker経由かチェック
if is_docker_command "$COMMAND"; then
    debug_log "DOCKER_COMMAND: 許可"
    exit 0
fi

# チェーンコマンド分割 (&&, ||, ;, | で分割して各セグメントをチェック)
# awk使用でPOSIX準拠
SEGMENTS=$(printf '%s\n' "$COMMAND" | awk '{
    gsub(/&&/, "\n"); gsub(/\|\|/, "\n"); gsub(/;/, "\n"); gsub(/\|/, "\n"); print
}')
OLDIFS="$IFS"
IFS='
'
for seg in $SEGMENTS; do
    # 前後の空白を除去
    seg=$(printf '%s\n' "$seg" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    if ! check_segment "$seg"; then
        echo "[ローカルコマンド禁止] このコマンドはDockerコンテナ内で実行してください。" >&2
        echo "検知セグメント: $seg" >&2
        IFS="$OLDIFS"
        exit 2
    fi
done
IFS="$OLDIFS"

# サブシェル展開: $(...) 内のコマンドを抽出してチェック
SUBSHELL_CMDS=$(printf '%s\n' "$COMMAND" | grep -oE '\$\([^)]+\)' 2>/dev/null || true)
if [ -n "$SUBSHELL_CMDS" ]; then
    OLDIFS="$IFS"
    IFS='
'
    for subcmd in $SUBSHELL_CMDS; do
        # $( と ) を除去
        inner=$(printf '%s\n' "$subcmd" | sed 's/^\$([[:space:]]*//; s/[[:space:]]*)$//')
        if ! check_segment "$inner"; then
            echo "[ローカルコマンド禁止] サブシェル内のコマンドはDockerコンテナ内で実行してください。" >&2
            echo "検知: $subcmd" >&2
            IFS="$OLDIFS"
            exit 2
        fi
    done
    IFS="$OLDIFS"
fi

# バッククォート展開: `...` 内のコマンドを抽出してチェック
BACKTICK_CMDS=$(printf '%s\n' "$COMMAND" | grep -oE '`[^`]+`' 2>/dev/null || true)
if [ -n "$BACKTICK_CMDS" ]; then
    OLDIFS="$IFS"
    IFS='
'
    for btcmd in $BACKTICK_CMDS; do
        inner=$(printf '%s\n' "$btcmd" | sed 's/^`//; s/`$//')
        if ! check_segment "$inner"; then
            echo "[ローカルコマンド禁止] バッククォート内のコマンドはDockerコンテナ内で実行してください。" >&2
            echo "検知: $btcmd" >&2
            IFS="$OLDIFS"
            exit 2
        fi
    done
    IFS="$OLDIFS"
fi

debug_log "LAYER1: パス"

# --- 層1b: 難読化パターン検知 (ブロック対象キーワードの有無に関わらずブロック) ---
# 注: パイプ先シェルコマンドは \|\s*(/\S*/)? で パス付き (/bin/sh) も検知しつつ
#      .sh ファイル名 (script.sh) の偽陽性を防ぐ

# パイプ先シェルコマンドの共通パターン (| sh, | /bin/bash 等)
PIPE_SHELL='\|\s*(/\S*/)?(sh|bash|zsh|dash)\b'

# base64/xxd デコード → シェル実行
DECODE_EXEC="(base64\\s+(-d|--decode)|xxd\\s+-r)\\s*${PIPE_SHELL}"
if printf '%s\n' "$COMMAND" | grep -qE "$DECODE_EXEC"; then
    debug_log "OBFUSCATION: base64/xxd decode exec"
    echo "[難読化検知] base64/xxd デコード→シェル実行パイプはブロックされました。" >&2
    exit 2
fi

# eval + 文字列連結/変数展開
EVAL_CONCAT='\beval\b.*(".*".*"|\$\{?[A-Za-z_])'
if printf '%s\n' "$COMMAND" | grep -qE "$EVAL_CONCAT"; then
    debug_log "OBFUSCATION: eval concat"
    echo "[難読化検知] eval + 文字列連結/変数展開はブロックされました。" >&2
    exit 2
fi

# printf/echo -e + hexエスケープ → シェル実行
PRINTF_EXEC="(printf|echo\\s+-e)\\s+.*\\\\x[0-9a-fA-F].*${PIPE_SHELL}"
if printf '%s\n' "$COMMAND" | grep -qE "$PRINTF_EXEC"; then
    debug_log "OBFUSCATION: printf hex exec"
    echo "[難読化検知] printf/echo hexエスケープ→シェル実行はブロックされました。" >&2
    exit 2
fi

# $'...' hex/octalエスケープ (3個以上連続)
HEX_ESCAPE="\\\$'(\\\\x[0-9a-fA-F]{2}|\\\\[0-7]{3}).*(\\\\x[0-9a-fA-F]{2}|\\\\[0-7]{3}).*(\\\\x[0-9a-fA-F]{2}|\\\\[0-7]{3})"
if printf '%s\n' "$COMMAND" | grep -qE "$HEX_ESCAPE"; then
    debug_log "OBFUSCATION: hex/octal escape"
    echo "[難読化検知] hex/octal エスケープシーケンスはブロックされました。" >&2
    exit 2
fi

# curl/wget → シェル実行パイプ
REMOTE_EXEC="\\b(curl|wget)\\b.*${PIPE_SHELL}"
if printf '%s\n' "$COMMAND" | grep -qE "$REMOTE_EXEC"; then
    debug_log "OBFUSCATION: remote exec"
    echo "[難読化検知] リモートスクリプトのパイプ実行はブロックされました。" >&2
    exit 2
fi

debug_log "LAYER2: パス → 許可"
exit 0
