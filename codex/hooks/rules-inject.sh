#!/bin/sh
# rules-inject.sh - quiet/compact rules activation for Codex.
# It records the exact rules checksum for hooks and injects only a compact model-visible contract.
# Full markdown text can be read explicitly with codex-rules read or @rules-required.

INPUT=""
[ ! -t 0 ] && INPUT=$(cat)
SCRIPT_DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd -P || dirname "$0")
CODEX_ROOT=$(cd "$SCRIPT_DIR/.." 2>/dev/null && pwd -P || echo "")
RULES_LIB="${SCRIPT_DIR}/rules-lib.sh"
if [ -f "$RULES_LIB" ]; then
    . "$RULES_LIB"
else
    echo "[rules-inject] ERROR: rules-lib.sh not found" >&2
    exit 1
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

needs_enforcement() {
    _p=$(printf '%s\n' "$PROMPT" | tr '[:upper:]' '[:lower:]')
    case "$_p" in
        *'@feat'*|*'$feat'*|*'@fix'*|*'$fix'*|*'@review'*|*'$review'*|*'@deep-review'*|*'$deep-review'*|*'@security-review'*|*'$security-review'*|*'@test'*|*'$test'*|*'@refactor'*|*'$refactor'*|*'@rules-required'*|*'$rules-required'*|*'@rules-compliance-review'*|*'$rules-compliance-review'*) return 0 ;;
        *実装*|*修正*|*変更*|*追加*|*削除*|*作成*|*更新*|*レビュー*|*テスト*|*リファクタ*|*バグ*|*障害*|*fix*|*feat*|*add*|*update*|*delete*|*remove*|*create*|*review*|*test*|*refactor*|*patch*) return 0 ;;
    esac
    return 1
}

FILES_TMP=$(rules_mktemp_file inject-files)
rules_collect_rule_files "$CWD" "$FILES_TMP" "$CODEX_ROOT"
[ ! -s "$FILES_TMP" ] && { rm -f "$FILES_TMP"; exit 0; }

CHECKSUM=$(rules_checksum_file_list "$FILES_TMP")

MARKER_DIR="$CWD/codex_tmp"
MARKER="$MARKER_DIR/.codex_rules_loaded"
mkdir -p "$MARKER_DIR" 2>/dev/null || true
TOTAL_BYTES=$(rules_total_bytes "$FILES_TMP")
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
