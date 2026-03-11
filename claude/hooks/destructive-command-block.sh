#!/bin/sh
# PreToolUse hook - git commit/push および破壊的操作をブロック
# CLAUDE.mdルール: git commit/push はユーザーのみ操作可能
#
# 使い方 (手動実行):
#   echo '{"tool_input":{"command":"git commit -m test"}}' | ./destructive-command-block.sh
#
# Claude Code hook として自動実行される場合は stdin から JSON を受け取る

# set -e を使わない（exit 1 = hookエラー = 許可扱いリスク）

# 手動実行時のヘルプ
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    cat <<'EOF'
destructive-command-block.sh - git commit/push および破壊的操作をブロック

使い方:
  echo '{"tool_input":{"command":"git commit -m test"}}' | ./destructive-command-block.sh

説明:
  Claude Code の PreToolUse hook として動作し、以下を検出した場合に
  exit 2 でブロックします。
  - git commit / git push (ユーザーのみ操作可能)
  - git reset --hard / git clean -f / git checkout -- . / git restore (破壊的操作)
  - git rebase / git branch -D / git stash drop|clear (履歴・ブランチ破壊)
  - git filter-branch / git reflog expire (低頻度だが危険)
  - rm -rf (再帰強制削除)
  - docker volume rm / docker system prune (データ損失)
  - gh repo delete (リポジトリ削除)
  - truncate / shred / dd (ファイル破壊)

依存関係:
  jaq または jq が必要です (jaq優先)
  - macOS: brew install jaq
  - Ubuntu/Debian: apt install jq (または cargo install jaq)
  - Arch: pacman -S jq (または paru -S jaq)
  - Windows: scoop install jaq (または winget install jqlang.jq)
EOF
    exit 0
fi

# stdin がない場合のタイムアウト対策
if [ -t 0 ]; then
    echo "エラー: 標準入力がありません" >&2
    echo "使い方: echo '{\"tool_input\":{\"command\":\"git commit -m test\"}}' | $0" >&2
    echo "ヘルプ: $0 --help" >&2
    exit 1
fi

# Read JSON input from stdin
INPUT=$(cat)

# jaq優先、jqフォールバック（見つからない場合は空文字→許可）
JQ=$(command -v jaq 2>/dev/null || command -v jq 2>/dev/null || echo "")
if [ -z "$JQ" ]; then
    exit 0
fi

# Extract command from tool_input
COMMAND=$(printf '%s\n' "$INPUT" | "$JQ" -r '.tool_input.command // ""' 2>/dev/null) || COMMAND=""

# --- 検出ロジック（ルール定義から分離） ---

block_command() {
    pattern="$1"; msg="$2"
    if printf '%s\n' "$COMMAND" | grep -qE -- "$pattern"; then
        echo "[安全ガード] $msg" >&2
        exit 2
    fi
}

block_flag() {
    cmd_pattern="$1"; flag_pattern="$2"; msg="$3"
    if printf '%s\n' "$COMMAND" | grep -qE -- "$cmd_pattern" && \
       printf '%s\n' "$COMMAND" | grep -qE -- "$flag_pattern"; then
        echo "[安全ガード] $msg" >&2
        exit 2
    fi
}

block_both_flags() {
    cmd_pattern="$1"; flag1="$2"; flag2="$3"; msg="$4"
    if printf '%s\n' "$COMMAND" | grep -qE -- "$cmd_pattern" && \
       printf '%s\n' "$COMMAND" | grep -qE -- "$flag1" && \
       printf '%s\n' "$COMMAND" | grep -qE -- "$flag2"; then
        echo "[安全ガード] $msg" >&2
        exit 2
    fi
}

# === ルール定義（テーブル） ===

# --- case-sensitive: -D と -d を区別する必要があるルール ---
block_flag '\bgit\s+branch\b' '-D\b|--delete.*--force|--force.*--delete' 'git branch -D/--delete --force は禁止されています。-d を使用してください。'

# --- 以降は lowercase で検査（パターン簡素化） ---
COMMAND=$(printf '%s\n' "$COMMAND" | tr '[:upper:]' '[:lower:]')

# --- 1. コマンド自体がブロック対象 ---
block_command '\bgit\s+(commit|push)(\s|$)'    'git commit/push はユーザーのみ操作可能です。コミットの準備ができたらユーザーに依頼してください。'
block_command '\bgit\s+rebase\b'               'git rebase は禁止されています。'
block_command '\bgit\s+restore\s+'             'git restore は禁止されています。'
block_command '\bgit\s+checkout\s+--\s*\.'     'git checkout -- . は禁止されています。'
block_command '\bgit\s+filter-branch\b'        'git filter-branch は禁止されています。'
block_command '\bgit\s+reflog\s+expire\b'      'git reflog expire は禁止されています。'
block_command '\bgit\s+stash\s+(drop|clear)(\s|$)' 'git stash drop/clear は禁止されています。'
block_command '\bdocker\s+volume\s+rm\b'       'docker volume rm は禁止されています。'
block_command '\bdocker\s+system\s+prune\b'    'docker system prune は禁止されています。'
block_command '\bgh\s+repo\s+delete\b'         'gh repo delete は禁止されています。'
block_command '(^|[;&|]\s*)truncate\b'         'truncate は禁止されています。'
block_command '(^|[;&|]\s*)shred\b'            'shred は禁止されています。'
block_command '\bdd\s+'                        'dd は禁止されています。'

# --- 2. コマンド+危険フラグの組み合わせでブロック ---
block_flag '\bgit\s+reset\b'  '--hard\b'  'git reset --hard は禁止されています。'
block_flag '\bgit\s+clean\b'  '-[a-z]*f'  'git clean -f は禁止されています。'
block_flag '\brm\b' '(^|\s)-[a-z]*r[a-z]*f|(^|\s)-[a-z]*f[a-z]*r' 'rm -rf は禁止されています。'
block_both_flags '\brm\b' '(^|\s)-[a-z]*r(\s|$)|--recursive\b' '(^|\s)-[a-z]*f(\s|$)|--force\b' 'rm -rf は禁止されています。'

exit 0
