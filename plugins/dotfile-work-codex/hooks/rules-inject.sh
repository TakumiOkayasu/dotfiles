#!/bin/sh
# rules-inject.sh - performance-profiled rules injection for Codex.
#
# SessionStart:
#   inject RULES_CORE + RULES_INDEX only.
# UserPromptSubmit:
#   inject full RULES_BUNDLE when the prompt looks mutating/reviewing or explicitly asks for rules.
#   otherwise inject core/index only.
# PreToolUse guard still blocks mutating tools unless full rules were injected.

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

hash_cmd() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 | awk '{print $1}'
    else
        cksum | awk '{print $1}'
    fi
}

mktemp_safe() {
    mktemp 2>/dev/null || printf '%s\n' "/tmp/codex-rules.$$.$1"
}

add_rule_dir() {
    _dir="$1"
    [ -d "$_dir" ] || return 0
    find -L "$_dir" -maxdepth 1 -type f -name '*.md' \
        ! -name 'RULES_BUNDLE.md' ! -name 'RULES_INDEX.md' 2>/dev/null
}

find_first_file() {
    _name="$1"
    for _base in \
        "${PLUGIN_ROOT:-}/rules" \
        "$CWD/.codex/rules" \
        "$CWD/codex/rules" \
        "$HOME/.codex/rules"; do
        [ -n "$_base" ] || continue
        [ -f "$_base/$_name" ] && { printf '%s\n' "$_base/$_name"; return 0; }
    done
    if command -v git >/dev/null 2>&1; then
        _root=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null || echo "")
        [ -n "$_root" ] && [ -f "$_root/codex/rules/$_name" ] && { printf '%s\n' "$_root/codex/rules/$_name"; return 0; }
        [ -n "$_root" ] && [ -f "$_root/.codex/rules/$_name" ] && { printf '%s\n' "$_root/.codex/rules/$_name"; return 0; }
    fi
    return 1
}

collect_rule_files() {
    _tmp="$1"
    : > "$_tmp"
    [ -n "${PLUGIN_ROOT:-}" ] && add_rule_dir "${PLUGIN_ROOT}/rules" >> "$_tmp"
    add_rule_dir "$HOME/.codex/rules" >> "$_tmp"
    add_rule_dir "$CWD/.codex/rules" >> "$_tmp"
    add_rule_dir "$CWD/codex/rules" >> "$_tmp"
    if command -v git >/dev/null 2>&1; then
        _root=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null || echo "")
        [ -n "$_root" ] && add_rule_dir "$_root/codex/rules" >> "$_tmp"
        [ -n "$_root" ] && add_rule_dir "$_root/.codex/rules" >> "$_tmp"
    fi
    sort -u "$_tmp" -o "$_tmp"
}

needs_full_rules() {
    _p=$(printf '%s\n' "$PROMPT" | tr '[:upper:]' '[:lower:]')
    case "$_p" in
        *'@feat'*|*'$feat'*|*'@fix'*|*'$fix'*|*'@review'*|*'$review'*|*'@deep-review'*|*'$deep-review'*|*'@security-review'*|*'$security-review'*|*'@test'*|*'$test'*|*'@refactor'*|*'$refactor'*|*'@rules-required'*|*'$rules-required'*) return 0 ;;
        *実装*|*修正*|*変更*|*追加*|*削除*|*作成*|*更新*|*レビュー*|*テスト*|*リファクタ*|*バグ*|*障害*|*調査*|*fix*|*feat*|*add*|*update*|*delete*|*remove*|*create*|*review*|*test*|*refactor*|*patch*|*api*|*db*|*schema*|*migration*|*auth*|*secret*) return 0 ;;
    esac
    return 1
}

FILES_TMP=$(mktemp_safe files)
collect_rule_files "$FILES_TMP"
if [ ! -s "$FILES_TMP" ]; then
    rm -f "$FILES_TMP"
    exit 0
fi

CHECKSUM=$(while IFS= read -r f; do
    [ -f "$f" ] || continue
    printf '%s\n' "FILE:$f"
    cat "$f"
done < "$FILES_TMP" | hash_cmd)

MARKER_DIR="$CWD/codex_tmp"
MARKER="$MARKER_DIR/.codex_rules_loaded"
mkdir -p "$MARKER_DIR" 2>/dev/null || true

CORE_FILE=$(find_first_file RULES_CORE.md || true)
INDEX_FILE=$(find_first_file RULES_INDEX.md || true)
MAX_BYTES="${CODEX_RULES_MAX_BYTES:-500000}"
ALWAYS="${CODEX_RULES_INJECT_ALWAYS:-0}"

TOTAL_BYTES=$(while IFS= read -r f; do [ -f "$f" ] && wc -c < "$f"; done < "$FILES_TMP" | awk '{s+=$1} END{print s+0}')

FULL=false
if [ "$HOOK_EVENT" = "SessionStart" ]; then
    FULL=false
elif [ "${CODEX_RULES_INJECT_LEVEL:-auto}" = "full" ]; then
    FULL=true
elif needs_full_rules; then
    FULL=true
fi

if [ "$FULL" != "true" ]; then
    cat <<EOF
📚 [Codex rules core loaded]
- Full markdown rules are available but not injected for this non-mutating prompt.
- Before edits/reviews/tests, full rules must be injected. Mutating tools are guarded by rules-guard.sh.
- Rule checksum: $CHECKSUM
EOF
    [ -n "$CORE_FILE" ] && { printf '\n---\n\n## RULES_CORE\n\n'; cat "$CORE_FILE"; printf '\n'; }
    [ -n "$INDEX_FILE" ] && { printf '\n---\n\n## RULES_INDEX\n\n'; cat "$INDEX_FILE"; printf '\n'; }
    cat > "$MARKER" <<EOF
checksum=$CHECKSUM
mode=core
bytes=$TOTAL_BYTES
event=$HOOK_EVENT
EOF
    rm -f "$FILES_TMP"
    exit 0
fi

if [ "$ALWAYS" != "1" ] && [ -f "$MARKER" ] && grep -q "^checksum=$CHECKSUM$" "$MARKER" 2>/dev/null && grep -q '^mode=full$' "$MARKER" 2>/dev/null; then
    cat <<EOF
📚 [Codex rules already fully loaded]
- checksum: $CHECKSUM
- Continue applying the already injected full rules.
EOF
    rm -f "$FILES_TMP"
    exit 0
fi

if [ "$TOTAL_BYTES" -gt "$MAX_BYTES" ]; then
    cat <<EOF
🚨 [Codex rules NOT fully injected]
- Rules size ${TOTAL_BYTES} bytes exceeds CODEX_RULES_MAX_BYTES=${MAX_BYTES}.
- Editing/review/test tools will be blocked by rules-guard.sh until full rules are injected.
- Raise CODEX_RULES_MAX_BYTES or reduce rules size.
EOF
    cat > "$MARKER" <<EOF
checksum=$CHECKSUM
mode=too-large
bytes=$TOTAL_BYTES
event=$HOOK_EVENT
EOF
    rm -f "$FILES_TMP"
    exit 0
fi

cat <<EOF
📚 [Codex rules full content injected]
You must treat the following rules as mandatory for this task. Apply them before editing, reviewing, testing, or giving implementation conclusions.

Rule checksum: $CHECKSUM
Rule files:
EOF
while IFS= read -r f; do printf -- '- `%s`\n' "$f"; done < "$FILES_TMP"

while IFS= read -r f; do
    [ -f "$f" ] || continue
    printf '\n---\n\n## RULE FILE: `%s`\n\n' "$f"
    cat "$f"
    printf '\n'
done < "$FILES_TMP"

cat > "$MARKER" <<EOF
checksum=$CHECKSUM
mode=full
bytes=$TOTAL_BYTES
event=$HOOK_EVENT
EOF
while IFS= read -r f; do printf 'file=%s\n' "$f"; done < "$FILES_TMP" >> "$MARKER"

rm -f "$FILES_TMP"
exit 0
