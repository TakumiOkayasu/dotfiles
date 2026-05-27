#!/bin/sh
# rules-guard.sh - block mutating tools unless markdown rules are active and unchanged.

INPUT=""
[ ! -t 0 ] && INPUT=$(cat)
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

hash_cmd() {
    if command -v sha256sum >/dev/null 2>&1; then sha256sum | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then shasum -a 256 | awk '{print $1}'
    else cksum | awk '{print $1}'
    fi
}
mktemp_safe() { mktemp 2>/dev/null || printf '%s\n' "/tmp/codex-rules-guard.$$.$1"; }
add_rule_dir() {
    _dir="$1"
    [ -d "$_dir" ] || return 0
    find -L "$_dir" -maxdepth 1 -type f -name '*.md' \
        ! -name 'RULES_BUNDLE.md' ! -name 'RULES_INDEX.md' 2>/dev/null
}

FILES_TMP=$(mktemp_safe files)
: > "$FILES_TMP"
[ -n "${PLUGIN_ROOT:-}" ] && add_rule_dir "${PLUGIN_ROOT}/rules" >> "$FILES_TMP"
add_rule_dir "$HOME/.codex/rules" >> "$FILES_TMP"
add_rule_dir "$CWD/.codex/rules" >> "$FILES_TMP"
add_rule_dir "$CWD/codex/rules" >> "$FILES_TMP"
if command -v git >/dev/null 2>&1; then
    ROOT=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null || echo "")
    [ -n "$ROOT" ] && add_rule_dir "$ROOT/codex/rules" >> "$FILES_TMP"
    [ -n "$ROOT" ] && add_rule_dir "$ROOT/.codex/rules" >> "$FILES_TMP"
fi
sort -u "$FILES_TMP" -o "$FILES_TMP"
[ ! -s "$FILES_TMP" ] && { rm -f "$FILES_TMP"; exit 0; }

CHECKSUM=$(while IFS= read -r f; do
    [ -f "$f" ] || continue
    printf 'FILE:%s\n' "$(basename "$f")"
    cat "$f"
done < "$FILES_TMP" | hash_cmd)
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
