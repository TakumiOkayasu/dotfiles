#!/bin/sh
# rules-inject.sh - inject markdown rules with stable checksum.
#
# Recovery hotfix:
# - Checksum is logical rule basename + content, not absolute path.
# - Generated RULES_BUNDLE.md / RULES_INDEX.md are not part of checksum.
# - SessionStart injects core/index only; task prompts inject full rules.

INPUT=""
if [ ! -t 0 ]; then
    INPUT=$(cat)
fi

JQ=$(command -v jaq 2>/dev/null || command -v jq 2>/dev/null || echo "")
if [ -n "$JQ" ] && [ -n "$INPUT" ]; then
    CWD=$(printf '%s\n' "$INPUT" | "$JQ" -r '.cwd // empty' 2>/dev/null) || CWD=""
    HOOK_EVENT=$(printf '%s\n' "$INPUT" | "$JQ" -r '.hook_event_name // empty' 2>/dev/null) || HOOK_EVENT=""
    PROMPT=$(printf '%s\n' "$INPUT" | "$JQ" -r '.prompt // empty' 2>/dev/null) || PROMPT=""
else
    CWD=""
    HOOK_EVENT=""
    PROMPT=""
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

mktemp_safe() { mktemp 2>/dev/null || printf '%s\n' "/tmp/codex-rules.$$.$1"; }

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
    add_rule_dir_entries "$_p" "$WORK_ROOT/.codex/rules" >> "$_entries"; _p=$((_p + 10))
    add_rule_dir_entries "$_p" "$WORK_ROOT/codex/rules" >> "$_entries"; _p=$((_p + 10))
    add_rule_dir_entries "$_p" "$CWD/.codex/rules" >> "$_entries"; _p=$((_p + 10))
    add_rule_dir_entries "$_p" "$CWD/codex/rules" >> "$_entries"; _p=$((_p + 10))
    [ -n "$PLUGIN_ROOT" ] && add_rule_dir_entries "$_p" "$PLUGIN_ROOT/rules" >> "$_entries"; _p=$((_p + 10))
    add_rule_dir_entries "$_p" "$HOME/.codex/rules" >> "$_entries"
    TAB=$(printf '\t')
    sort -t "$TAB" -k2,2 -k1,1n "$_entries" 2>/dev/null \
        | awk -F '\t' '!seen[$2]++ { print $3 }' > "$_out"
    rm -f "$_entries"
}

find_rule_file() {
    _name="$1"
    for _base in \
        "$WORK_ROOT/.codex/rules" \
        "$WORK_ROOT/codex/rules" \
        "$CWD/.codex/rules" \
        "$CWD/codex/rules" \
        "$PLUGIN_ROOT/rules" \
        "$HOME/.codex/rules"; do
        [ -n "$_base" ] || continue
        [ -f "$_base/$_name" ] && { printf '%s\n' "$_base/$_name"; return 0; }
    done
    return 1
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

needs_full_rules() {
    _p=$(printf '%s\n' "$PROMPT" | tr '[:upper:]' '[:lower:]')
    case "$_p" in
        *'@feat'*|*'$feat'*|*'@fix'*|*'$fix'*|*'@review'*|*'$review'*|*'@deep-review'*|*'$deep-review'*|*'@security-review'*|*'$security-review'*|*'@test'*|*'$test'*|*'@refactor'*|*'$refactor'*|*'@rules-required'*|*'$rules-required'*) return 0 ;;
        *実装*|*修正*|*変更*|*追加*|*削除*|*作成*|*更新*|*レビュー*|*テスト*|*リファクタ*|*バグ*|*障害*|*fix*|*feat*|*add*|*update*|*delete*|*remove*|*create*|*review*|*test*|*refactor*|*patch*|*api*|*db*|*schema*|*migration*|*auth*|*secret*) return 0 ;;
    esac
    return 1
}

FILES_TMP=$(mktemp_safe files)
collect_rule_files "$FILES_TMP"
if [ ! -s "$FILES_TMP" ]; then
    rm -f "$FILES_TMP"
    exit 0
fi

CHECKSUM=$(rules_checksum "$FILES_TMP")
MARKER_DIR="$WORK_ROOT/codex_tmp"
MARKER="$MARKER_DIR/.codex_rules_loaded"
mkdir -p "$MARKER_DIR" 2>/dev/null || true

CORE_FILE=$(find_rule_file RULES_CORE.md || true)
INDEX_FILE=$(find_rule_file RULES_INDEX.md || true)
MAX_BYTES="${CODEX_RULES_MAX_BYTES:-500000}"
TOTAL_BYTES=$(while IFS= read -r f; do [ -f "$f" ] && wc -c < "$f"; done < "$FILES_TMP" | awk '{s+=$1} END{print s+0}')

FULL=false
case "${CODEX_RULES_INJECT_LEVEL:-auto}" in
    full) FULL=true ;;
    core) FULL=false ;;
    off) rm -f "$FILES_TMP"; exit 0 ;;
    *)
        if [ "$HOOK_EVENT" = "SessionStart" ]; then
            FULL=false
        elif needs_full_rules; then
            FULL=true
        fi
        ;;
esac

if [ "$FULL" != "true" ]; then
    cat <<EOF2
📚 [Codex rules core loaded]
- Read-only commands are allowed.
- Mutating operations require full rules.
- Rule checksum: $CHECKSUM
EOF2
    [ -n "$CORE_FILE" ] && { printf '\n---\n\n## RULES_CORE\n\n'; cat "$CORE_FILE"; printf '\n'; }
    [ -n "$INDEX_FILE" ] && { printf '\n---\n\n## RULES_INDEX\n\n'; cat "$INDEX_FILE"; printf '\n'; }
    cat > "$MARKER" <<EOF2
checksum=$CHECKSUM
mode=core
bytes=$TOTAL_BYTES
event=$HOOK_EVENT
root=$WORK_ROOT
algorithm=logical-basename-v3
EOF2
    rm -f "$FILES_TMP"
    exit 0
fi

if [ "$TOTAL_BYTES" -gt "$MAX_BYTES" ]; then
    cat <<EOF2
🚨 [Codex rules NOT fully injected]
- Rules size ${TOTAL_BYTES} bytes exceeds CODEX_RULES_MAX_BYTES=${MAX_BYTES}.
- Mutating operations will be blocked until full rules are injected.
EOF2
    cat > "$MARKER" <<EOF2
checksum=$CHECKSUM
mode=too-large
bytes=$TOTAL_BYTES
event=$HOOK_EVENT
root=$WORK_ROOT
algorithm=logical-basename-v3
EOF2
    rm -f "$FILES_TMP"
    exit 0
fi

cat <<EOF2
📚 [Codex rules full content injected]
Treat the following rules as mandatory for this task before editing, reviewing, testing, or making implementation conclusions.

Rule checksum: $CHECKSUM
Rule files:
EOF2
while IFS= read -r f; do printf -- '- `%s` as `%s`\n' "$f" "$(basename "$f")"; done < "$FILES_TMP"

while IFS= read -r f; do
    [ -f "$f" ] || continue
    printf '\n---\n\n## RULE FILE: `%s`\n\n' "$(basename "$f")"
    cat "$f"
    printf '\n'
done < "$FILES_TMP"

cat > "$MARKER" <<EOF2
checksum=$CHECKSUM
mode=full
bytes=$TOTAL_BYTES
event=$HOOK_EVENT
root=$WORK_ROOT
algorithm=logical-basename-v3
EOF2
while IFS= read -r f; do printf 'file=%s\n' "$f"; done < "$FILES_TMP" >> "$MARKER"

rm -f "$FILES_TMP"
exit 0
