#!/bin/sh
# rules-guard.sh - block mutating tools until rules were injected.

INPUT=""
if [ ! -t 0 ]; then
    INPUT=$(cat)
fi

JQ=$(command -v jaq 2>/dev/null || command -v jq 2>/dev/null || echo "")
if [ -n "$JQ" ] && [ -n "$INPUT" ]; then
    CWD=$(printf '%s\n' "$INPUT" | "$JQ" -r '.cwd // empty' 2>/dev/null) || CWD=""
    TOOL_NAME=$(printf '%s\n' "$INPUT" | "$JQ" -r '.tool_name // empty' 2>/dev/null) || TOOL_NAME=""
else
    CWD=""
    TOOL_NAME=""
fi
[ -n "$CWD" ] || CWD=$(pwd 2>/dev/null || echo "$HOME")

case "$TOOL_NAME" in
    Bash|Edit|Write|MultiEdit|apply_patch|ApplyPatch) ;;
    *) exit 0 ;;
esac

hash_cmd() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 | awk '{print $1}'
    else
        cksum | awk '{print $1}'
    fi
}

add_rule_dir() {
    _dir="$1"
    [ -d "$_dir" ] || return 0
    find -L "$_dir" -maxdepth 1 -type f -name '*.md' \
        ! -name 'RULES_BUNDLE.md' ! -name 'RULES_INDEX.md' 2>/dev/null
}

mktemp_safe() {
    mktemp 2>/dev/null || printf '%s\n' "/tmp/codex-rules-guard.$$.$1"
}

FILES_TMP=$(mktemp_safe files)
: > "$FILES_TMP"
add_rule_dir "$HOME/.codex/rules" >> "$FILES_TMP"
add_rule_dir "$CWD/.codex/rules" >> "$FILES_TMP"
add_rule_dir "$CWD/codex/rules" >> "$FILES_TMP"
if command -v git >/dev/null 2>&1; then
    ROOT=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null || echo "")
    [ -n "$ROOT" ] && add_rule_dir "$ROOT/codex/rules" >> "$FILES_TMP"
    [ -n "$ROOT" ] && add_rule_dir "$ROOT/.codex/rules" >> "$FILES_TMP"
fi
sort -u "$FILES_TMP" -o "$FILES_TMP"

# No rule files means nothing to enforce.
if [ ! -s "$FILES_TMP" ]; then
    rm -f "$FILES_TMP"
    exit 0
fi

CHECKSUM=$(while IFS= read -r f; do
    [ -f "$f" ] || continue
    printf '%s\n' "FILE:$f"
    cat "$f"
done < "$FILES_TMP" | hash_cmd)

MARKER="$CWD/codex_tmp/.codex_rules_loaded"
if [ ! -f "$MARKER" ]; then
    echo "[rules-guard] BLOCK: Codex rules have not been injected/read for this worktree." >&2
    echo "Submit the prompt again, run /prompt:rules, or run codex-rules bundle/read before mutating tools." >&2
    rm -f "$FILES_TMP"
    exit 2
fi

if ! grep -q '^mode=full$' "$MARKER" 2>/dev/null; then
    echo "[rules-guard] BLOCK: Rules marker exists but full rules content was not injected." >&2
    rm -f "$FILES_TMP"
    exit 2
fi

if ! grep -q "^checksum=$CHECKSUM$" "$MARKER" 2>/dev/null; then
    echo "[rules-guard] BLOCK: Codex rules changed after injection. Re-read rules before modifying files." >&2
    echo "expected checksum: $CHECKSUM" >&2
    rm -f "$FILES_TMP"
    exit 2
fi

rm -f "$FILES_TMP"
exit 0
