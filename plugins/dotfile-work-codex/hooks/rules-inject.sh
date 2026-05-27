#!/bin/sh
# rules-inject.sh - quiet/compact rules activation for Codex.
# It records the exact rules checksum for hooks and injects only a compact model-visible contract.
# Full markdown text can be read explicitly with codex-rules read or @rules-required.

INPUT=""
[ ! -t 0 ] && INPUT=$(cat)
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
    if command -v sha256sum >/dev/null 2>&1; then sha256sum | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then shasum -a 256 | awk '{print $1}'
    else cksum | awk '{print $1}'
    fi
}

mktemp_safe() { mktemp 2>/dev/null || printf '%s\n' "/tmp/codex-rules-inject.$$.$1"; }

add_rule_dir() {
    _dir="$1"
    [ -d "$_dir" ] || return 0
    find -L "$_dir" -maxdepth 1 -type f -name '*.md' \
        ! -name 'RULES_BUNDLE.md' ! -name 'RULES_INDEX.md' 2>/dev/null
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

needs_enforcement() {
    _p=$(printf '%s\n' "$PROMPT" | tr '[:upper:]' '[:lower:]')
    case "$_p" in
        *'@feat'*|*'$feat'*|*'@fix'*|*'$fix'*|*'@review'*|*'$review'*|*'@deep-review'*|*'$deep-review'*|*'@security-review'*|*'$security-review'*|*'@test'*|*'$test'*|*'@refactor'*|*'$refactor'*|*'@rules-required'*|*'$rules-required'*|*'@rules-compliance-review'*|*'$rules-compliance-review'*) return 0 ;;
        *実装*|*修正*|*変更*|*追加*|*削除*|*作成*|*更新*|*レビュー*|*テスト*|*リファクタ*|*バグ*|*障害*|*fix*|*feat*|*add*|*update*|*delete*|*remove*|*create*|*review*|*test*|*refactor*|*patch*) return 0 ;;
    esac
    return 1
}

FILES_TMP=$(mktemp_safe files)
collect_rule_files "$FILES_TMP"
[ ! -s "$FILES_TMP" ] && { rm -f "$FILES_TMP"; exit 0; }

CHECKSUM=$(while IFS= read -r f; do
    [ -f "$f" ] || continue
    # Use basename, not absolute path, so plugin cache/local path differences do not change checksum.
    printf 'FILE:%s\n' "$(basename "$f")"
    cat "$f"
done < "$FILES_TMP" | hash_cmd)

MARKER_DIR="$CWD/codex_tmp"
MARKER="$MARKER_DIR/.codex_rules_loaded"
mkdir -p "$MARKER_DIR" 2>/dev/null || true
TOTAL_BYTES=$(while IFS= read -r f; do [ -f "$f" ] && wc -c < "$f"; done < "$FILES_TMP" | awk '{s+=$1} END{print s+0}')
MODE="core"
needs_enforcement && MODE="enforced"
[ "${CODEX_RULES_FORCE_ENFORCED:-0}" = "1" ] && MODE="enforced"

cat > "$MARKER" <<EOF_MARKER
checksum=$CHECKSUM
mode=$MODE
bytes=$TOTAL_BYTES
event=$HOOK_EVENT
EOF_MARKER
while IFS= read -r f; do printf 'file=%s\n' "$f"; done < "$FILES_TMP" >> "$MARKER"

# Keep output compact. CODEX_RULES_CONTEXT_MODE=none disables even this short contract.
if [ "${CODEX_RULES_CONTEXT_MODE:-compact}" != "none" ]; then
    cat <<EOF_CONTEXT
📚 [Codex rules active: ${MODE}]
Mandatory rules checksum: ${CHECKSUM}
Apply codex/rules/*.md. Deterministic checks run after edits and before final answer.
Key enforced items: strict equality, no any, no direct console/print in production, no Promise chain, no empty/broad catch, no toBeDefined-only tests, no unapproved dependency changes, no commented-out code.
Use @rules-required or codex-rules read for full text.
EOF_CONTEXT
fi

rm -f "$FILES_TMP"
exit 0
