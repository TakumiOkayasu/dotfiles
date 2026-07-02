#!/bin/sh
# rules-guard.sh - block mutating tools unless markdown rules are active and unchanged.

INPUT=""
[ ! -t 0 ] && INPUT=$(cat)
SCRIPT_DIR=$(dirname "$0")
SCRIPT_DIR=$(cd "$SCRIPT_DIR" 2>/dev/null && pwd -P) || SCRIPT_DIR=$(dirname "$0")
CODEX_ROOT=$(cd "$SCRIPT_DIR/.." 2>/dev/null && pwd -P || echo "")
RULES_LIB="${SCRIPT_DIR}/rules-lib.sh"
if [ -f "$RULES_LIB" ]; then
    # SC1090: RULES_LIB は実行時に解決する動的パス
    # shellcheck disable=SC1090
    . "$RULES_LIB"
else
    echo "[rules-guard] ERROR: rules-lib.sh not found" >&2
    exit 1
fi

JQ=$(command -v jaq 2>/dev/null || command -v jq 2>/dev/null || echo "")
if [ -n "$JQ" ] && [ -n "$INPUT" ]; then
    CWD=$(printf '%s\n' "$INPUT" | "$JQ" -r '.cwd // empty' 2>/dev/null) || CWD=""
    TOOL_NAME=$(printf '%s\n' "$INPUT" | "$JQ" -r '.tool_name // empty' 2>/dev/null) || TOOL_NAME=""
    COMMAND=$(printf '%s\n' "$INPUT" | "$JQ" -r '.tool_input.command // .tool_input.patch // empty' 2>/dev/null) || COMMAND=""
else
    CWD=""
    TOOL_NAME=""
    COMMAND=""
fi
[ -n "$CWD" ] || CWD=$(pwd 2>/dev/null || echo "$HOME")

is_mutating_bash() {
    _cmd=$(printf '%s\n' "$1" | tr '[:upper:]' '[:lower:]')
    # Redirects / tee modify files.
    printf '%s\n' "$_cmd" | grep -qE '(^|[[:space:]])(>|>>|tee)([[:space:]]|$)' && return 0
    printf '%s\n' "$_cmd" | grep -qE '(^|[;&|][[:space:]]*)?(apply_patch|touch|mkdir|rm|mv|cp|chmod|chown)([[:space:]]|$)' && return 0
    printf '%s\n' "$_cmd" | grep -qE 'sed[[:space:]].*-i|perl[[:space:]].*-p[iI]' && return 0
    printf '%s\n' "$_cmd" | grep -qE '(^|[;&|][[:space:]]*)git[[:space:]]+(add|commit|push|reset|clean|restore)([[:space:]]|$)' && return 0
    printf '%s\n' "$_cmd" | grep -qE '(^|[;&|][[:space:]]*)(npm[[:space:]]+install|pnpm[[:space:]]+add|yarn[[:space:]]+add|pip[[:space:]]+install)([[:space:]]|$)' && return 0
    printf '%s\n' "$_cmd" | grep -qE '(^|[;&|][[:space:]]*)docker[[:space:]]+(system[[:space:]]+prune|volume[[:space:]]+rm)([[:space:]]|$)' && return 0
    printf '%s\n' "$_cmd" | grep -qE '(^|[;&|][[:space:]]*)gh[[:space:]]+repo[[:space:]]+delete([[:space:]]|$)' && return 0
    printf '%s\n' "$_cmd" | grep -qE '(^|[;&|][[:space:]]*)glab[[:space:]]+issue[[:space:]]+(create|edit|close)([[:space:]]|$)' && return 0
    return 1
}


case "$TOOL_NAME" in
    Edit|Write|MultiEdit|apply_patch|ApplyPatch) MUTATING=1 ;;
    Bash) is_mutating_bash "$COMMAND" && MUTATING=1 || MUTATING=0 ;;
    *) MUTATING=0 ;;
esac
[ "${MUTATING:-0}" = "1" ] || exit 0

FILES_TMP=$(rules_mktemp_file guard-files)
rules_collect_rule_files "$CWD" "$FILES_TMP" "$CODEX_ROOT"
[ ! -s "$FILES_TMP" ] && { rm -f "$FILES_TMP"; exit 0; }

CHECKSUM=$(rules_checksum_file_list "$FILES_TMP")
MARKER="$CWD/codex_tmp/.codex_rules_loaded"

if [ ! -f "$MARKER" ]; then
    echo "[rules-guard] BLOCK: rules are not active for this worktree. Submit @rules-required or restart Codex so rules-inject can run." >&2
    rm -f "$FILES_TMP"; exit 2
fi
if ! grep -Eq '^(mode=full|mode=enforced)$' "$MARKER" 2>/dev/null; then
    echo "[rules-guard] BLOCK: only core rules are active; enforced rules are required before mutation. Use @rules-required." >&2
    rm -f "$FILES_TMP"; exit 2
fi
if ! grep -q "^checksum=$CHECKSUM$" "$MARKER" 2>/dev/null; then
    echo "[rules-guard] BLOCK: rules changed after activation. Re-run @rules-required before modifying files." >&2
    echo "expected checksum: $CHECKSUM" >&2
    rm -f "$FILES_TMP"; exit 2
fi

rm -f "$FILES_TMP"
exit 0
