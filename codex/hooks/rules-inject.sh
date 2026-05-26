#!/bin/sh
# rules-inject.sh - inject mandatory Codex rules into context.
#
# UserPromptSubmit / SessionStart hook. It concatenates ~/.codex/rules/*.md,
# project codex/rules/*.md and project .codex/rules/*.md into the model context
# once per rules checksum. This is the strongest practical guard for "read rules
# before work" without relying on the model to remember to open files manually.

# set -e は使わない。hook error が許可扱いになる環境があるため。

INPUT=""
if [ ! -t 0 ]; then
    INPUT=$(cat)
fi

JQ=$(command -v jaq 2>/dev/null || command -v jq 2>/dev/null || echo "")
if [ -n "$JQ" ] && [ -n "$INPUT" ]; then
    CWD=$(printf '%s\n' "$INPUT" | "$JQ" -r '.cwd // empty' 2>/dev/null) || CWD=""
    HOOK_EVENT=$(printf '%s\n' "$INPUT" | "$JQ" -r '.hook_event_name // empty' 2>/dev/null) || HOOK_EVENT=""
else
    CWD=""
    HOOK_EVENT=""
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

add_rule_dir() {
    _dir="$1"
    [ -d "$_dir" ] || return 0
    # shellcheck disable=SC2012
    find -L "$_dir" -maxdepth 1 -type f -name '*.md' \
        ! -name 'RULES_BUNDLE.md' ! -name 'RULES_INDEX.md' 2>/dev/null
}

collect_rule_files() {
    _tmp="$1"
    : > "$_tmp"

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

mktemp_safe() {
    mktemp 2>/dev/null || printf '%s\n' "/tmp/codex-rules.$$.$1"
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

MODE="${CODEX_RULES_INJECT_MODE:-full}"
MAX_BYTES="${CODEX_RULES_MAX_BYTES:-500000}"
ALWAYS="${CODEX_RULES_INJECT_ALWAYS:-0}"

TOTAL_BYTES=$(while IFS= read -r f; do [ -f "$f" ] && wc -c < "$f"; done < "$FILES_TMP" | awk '{s+=$1} END{print s+0}')

# 既に同一 checksum を注入済みなら、短い強制メッセージだけを出す。
if [ "$ALWAYS" != "1" ] && [ -f "$MARKER" ] && grep -q "^checksum=$CHECKSUM$" "$MARKER" 2>/dev/null; then
    cat <<EOF
📚 [Codex rules loaded]
- checksum: $CHECKSUM
- rule files are already injected for this session/worktree.
- Before editing or reviewing code, continue to obey the injected rules. If unsure, run `/prompt:rules` or read `~/.codex/rules/*.md`.
EOF
    rm -f "$FILES_TMP"
    exit 0
fi

if [ "$MODE" = "off" ]; then
    rm -f "$FILES_TMP"
    exit 0
fi

if [ "$TOTAL_BYTES" -gt "$MAX_BYTES" ]; then
    cat <<EOF
🚨 [Codex rules NOT fully injected]
- Rules size ${TOTAL_BYTES} bytes exceeds CODEX_RULES_MAX_BYTES=${MAX_BYTES}.
- Editing will be blocked by rules-guard.sh until rules are injected or the limit is raised.
- Set CODEX_RULES_MAX_BYTES to a larger value or run: cat ~/.codex/rules/*.md
EOF
    rm -f "$FILES_TMP"
    exit 0
fi

cat <<EOF
📚 [Codex Rules Required - full content injected]
You must treat the following rule files as mandatory instructions for this task.
If a project-local rule conflicts with a global rule, prefer the nearer project-local rule and report the conflict.
Do not edit files, run mutating commands, or provide implementation conclusions before applying these rules.

Rule checksum: $CHECKSUM
Rule files:
EOF
while IFS= read -r f; do
    printf -- '- `%s`\n' "$f"
done < "$FILES_TMP"

while IFS= read -r f; do
    [ -f "$f" ] || continue
    printf '\n---\n\n## RULE FILE: `%s`\n\n' "$f"
    cat "$f"
    printf '\n'
done < "$FILES_TMP"

cat <<EOF > "$MARKER"
checksum=$CHECKSUM
mode=full
bytes=$TOTAL_BYTES
event=$HOOK_EVENT
EOF
while IFS= read -r f; do printf 'file=%s\n' "$f"; done < "$FILES_TMP" >> "$MARKER"

rm -f "$FILES_TMP"
exit 0
