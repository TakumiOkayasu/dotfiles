#!/bin/sh
# rules-guard.sh - require full markdown rules only before mutating operations.
#
# Recovery hotfix:
# - Read-only Bash commands are not blocked.
# - Checksum is based on logical rule name + content, not absolute paths.
# - Generated RULES_BUNDLE.md / RULES_INDEX.md are excluded from checksum.
# - Marker is stored at git-root/codex_tmp/.codex_rules_loaded.

INPUT=""
if [ ! -t 0 ]; then
    INPUT=$(cat)
fi

JQ=$(command -v jaq 2>/dev/null || command -v jq 2>/dev/null || echo "")
if [ -n "$JQ" ] && [ -n "$INPUT" ]; then
    CWD=$(printf '%s\n' "$INPUT" | "$JQ" -r '.cwd // empty' 2>/dev/null) || CWD=""
    TOOL_NAME=$(printf '%s\n' "$INPUT" | "$JQ" -r '.tool_name // empty' 2>/dev/null) || TOOL_NAME=""
    COMMAND=$(printf '%s\n' "$INPUT" | "$JQ" -r '.tool_input.command // empty' 2>/dev/null) || COMMAND=""
else
    CWD=""
    TOOL_NAME=""
    COMMAND=""
fi
[ -n "$CWD" ] || CWD=$(pwd 2>/dev/null || echo "$HOME")

SCRIPT_DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd -P || dirname "$0")
[ -n "${PLUGIN_ROOT:-}" ] || PLUGIN_ROOT=$(cd "$SCRIPT_DIR/.." 2>/dev/null && pwd -P || echo "")

if command -v git >/dev/null 2>&1; then
    WORK_ROOT=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null || echo "$CWD")
else
    WORK_ROOT="$CWD"
fi

hash_cmd() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 | awk '{print $1}'
    else
        cksum | awk '{print $1}'
    fi
}

mktemp_safe() { mktemp 2>/dev/null || printf '%s\n' "/tmp/codex-rules-guard.$$.$1"; }

canonical_dir() {
    _d="$1"
    [ -n "$_d" ] || return 1
    [ -d "$_d" ] || return 1
    (cd "$_d" 2>/dev/null && pwd -P) || return 1
}

add_rule_dir_entries() {
    _priority="$1"
    _dir="$2"
    _canon=$(canonical_dir "$_dir") || return 0
    find -L "$_canon" -maxdepth 1 -type f -name '*.md' \
        ! -name 'RULES_BUNDLE.md' ! -name 'RULES_INDEX.md' 2>/dev/null \
        | sort | while IFS= read -r _f; do
            _base=$(basename "$_f")
            printf '%s\t%s\t%s\n' "$_priority" "$_base" "$_f"
        done
}

collect_rule_files() {
    _out="$1"
    _entries=$(mktemp_safe entries)
    : > "$_entries"
    _p=10
    # Priority: project-local > repo codex > cwd-local > plugin > home.
    add_rule_dir_entries "$_p" "$WORK_ROOT/.codex/rules" >> "$_entries"; _p=$((_p + 10))
    add_rule_dir_entries "$_p" "$WORK_ROOT/codex/rules" >> "$_entries"; _p=$((_p + 10))
    add_rule_dir_entries "$_p" "$CWD/.codex/rules" >> "$_entries"; _p=$((_p + 10))
    add_rule_dir_entries "$_p" "$CWD/codex/rules" >> "$_entries"; _p=$((_p + 10))
    [ -n "$PLUGIN_ROOT" ] && add_rule_dir_entries "$_p" "$PLUGIN_ROOT/rules" >> "$_entries"; _p=$((_p + 10))
    add_rule_dir_entries "$_p" "$HOME/.codex/rules" >> "$_entries"

    # De-duplicate by rule basename. Checksum intentionally ignores absolute paths.
    # Use a real tab as separator without relying on non-portable sort -t literals.
    TAB=$(printf '\t')
    sort -t "$TAB" -k2,2 -k1,1n "$_entries" 2>/dev/null \
        | awk -F '\t' '!seen[$2]++ { print $3 }' > "$_out"
    rm -f "$_entries"
}

rules_checksum() {
    _files="$1"
    while IFS= read -r f; do
        [ -f "$f" ] || continue
        printf '%s\n' "RULE:$(basename "$f")"
        cat "$f"
        printf '\n'
    done < "$_files" | hash_cmd
}

is_mutating_bash() {
    _cmd=$(printf '%s\n' "$COMMAND" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    [ -z "$_cmd" ] && return 1

    # Allow explicit read/list commands even before full rules. This is recovery-critical.
    case "$_cmd" in
        codex-rules*|*/codex-rules*|*rules-inject.sh*|*rules-required*) return 1 ;;
        git\ status*|git\ diff*|git\ log*|git\ show*|git\ branch\ --show-current*|git\ rev-parse*|git\ ls-files*|git\ grep*|git\ remote\ -v*) return 1 ;;
        glab\ issue\ view*|glab\ mr\ view*|glab\ api\ *|gh\ issue\ view*|gh\ pr\ view*|gh\ api\ * ) return 1 ;;
    esac

    # Obvious mutation patterns. Other safety hooks may still block risky read/write commands.
    printf '%s\n' "$_cmd" | grep -qE '(^|[;&|][[:space:]]*)(apply_patch|touch|mkdir|rm|mv|cp|chmod|chown|install|truncate|shred|dd)([[:space:]]|$)' && return 0
    printf '%s\n' "$_cmd" | grep -qE '(^|[;&|][[:space:]]*)(sed[[:space:]].*-i|perl[[:space:]].*-pi)([[:space:]]|$)' && return 0
    printf '%s\n' "$_cmd" | grep -qE '(^|[;&|][[:space:]]*)git[[:space:]]+(add|commit|push|reset|clean|restore|checkout|rebase|merge|stash)([[:space:]]|$)' && return 0
    printf '%s\n' "$_cmd" | grep -qE '(^|[;&|][[:space:]]*)(npm[[:space:]]+install|pnpm[[:space:]]+add|yarn[[:space:]]+add|pip[[:space:]]+install|pip3[[:space:]]+install|poetry[[:space:]]+add|cargo[[:space:]]+add)([[:space:]]|$)' && return 0
    printf '%s\n' "$_cmd" | grep -qE '(^|[;&|][[:space:]]*)docker[[:space:]]+(system[[:space:]]+prune|volume[[:space:]]+rm)([[:space:]]|$)' && return 0
    printf '%s\n' "$_cmd" | grep -qE '(^|[;&|][[:space:]]*)(gh|glab)[[:space:]]+(repo[[:space:]]+delete|issue[[:space:]]+(create|edit|close|reopen)|pr[[:space:]]+(create|merge|close|reopen)|mr[[:space:]]+(create|merge|close|reopen))([[:space:]]|$)' && return 0
    printf '%s\n' "$_cmd" | grep -qE '(^|[^0-9])>>?|\|[[:space:]]*tee([[:space:]]|$)' && return 0

    return 1
}

case "$TOOL_NAME" in
    Edit|Write|MultiEdit|apply_patch|ApplyPatch)
        ;;
    Bash)
        is_mutating_bash || exit 0
        ;;
    *)
        exit 0
        ;;
esac

FILES_TMP=$(mktemp_safe files)
collect_rule_files "$FILES_TMP"
[ ! -s "$FILES_TMP" ] && { rm -f "$FILES_TMP"; exit 0; }
CHECKSUM=$(rules_checksum "$FILES_TMP")

MARKER="$WORK_ROOT/codex_tmp/.codex_rules_loaded"
[ -f "$MARKER" ] || MARKER="$CWD/codex_tmp/.codex_rules_loaded"

if [ ! -f "$MARKER" ]; then
    echo "[rules-guard] BLOCK: full Codex rules have not been injected before a mutating operation." >&2
    echo "Run a read-only rules injection first: use \$rules-required or rerun the task prompt." >&2
    rm -f "$FILES_TMP"
    exit 2
fi

if ! grep -q '^mode=full$' "$MARKER" 2>/dev/null; then
    echo "[rules-guard] BLOCK: only core/index rules are loaded; full rules are required before mutating operations." >&2
    echo "Read-only commands are allowed. Use \$rules-required before editing." >&2
    rm -f "$FILES_TMP"
    exit 2
fi

LOADED=$(sed -n 's/^checksum=//p' "$MARKER" 2>/dev/null | head -1)
if [ "$LOADED" != "$CHECKSUM" ]; then
    echo "[rules-guard] BLOCK: Codex rules changed after injection. Re-read rules before mutating files." >&2
    echo "loaded checksum: ${LOADED:-<missing>}" >&2
    echo "current checksum: $CHECKSUM" >&2
    echo "Read-only commands are allowed; only mutating operations are blocked." >&2
    rm -f "$FILES_TMP"
    exit 2
fi

rm -f "$FILES_TMP"
exit 0
