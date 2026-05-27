#!/bin/sh
# rules-inject.sh - quiet Codex rules marker hook
#
# Default behavior:
#   - compute a stable checksum for markdown rules
#   - write codex_tmp/.codex_rules_loaded
#   - produce NO stdout
#
# Rationale:
#   UserPromptSubmit/SessionStart stdout is shown by Codex as hook context and
#   added as developer context. Full rules on stdout are noisy. Keep this hook
#   quiet by default and let skills/AGENTS carry the human-facing instructions.
#
# Verbose/debug:
#   CODEX_RULES_INJECT_VERBOSE=1       -> print a short JSON additionalContext
#   CODEX_RULES_INJECT_OUTPUT=full     -> print full rules as additionalContext
#   $0 --print-full                    -> print full rules to stdout manually
#   $0 --check                         -> only refresh marker, no output

# POSIX sh. Avoid set -e: hook failure should not create noisy UI failures.

MODE="marker"
case "${1:-}" in
  --print-full) MODE="print-full" ;;
  --check) MODE="marker" ;;
esac

# Read hook stdin if present, but do not require it.
INPUT=""
if [ ! -t 0 ]; then
  INPUT=$(cat)
fi

JQ=$(command -v jaq 2>/dev/null || command -v jq 2>/dev/null || echo "")
CWD=""
HOOK_EVENT_NAME=""
if [ -n "$INPUT" ] && [ -n "$JQ" ]; then
  CWD=$(printf '%s\n' "$INPUT" | "$JQ" -r '.cwd // ""' 2>/dev/null) || CWD=""
  HOOK_EVENT_NAME=$(printf '%s\n' "$INPUT" | "$JQ" -r '.hook_event_name // ""' 2>/dev/null) || HOOK_EVENT_NAME=""
fi
[ -z "$CWD" ] && CWD=$(pwd)

# Resolve plugin root from script path when this hook lives under plugins/<name>/hooks.
SCRIPT_DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd -P || dirname "$0")
PLUGIN_ROOT=$(cd "$SCRIPT_DIR/.." 2>/dev/null && pwd -P || echo "")
HOME_CODEX_RULES="${HOME}/.codex/rules"

find_git_root() {
  if command -v git >/dev/null 2>&1; then
    (cd "$CWD" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null) && return 0
  fi
  return 1
}

GIT_ROOT=$(find_git_root || echo "")

append_rule_dir() {
  _dir="$1"
  [ -d "$_dir" ] || return 0
  for _file in "$_dir"/*.md; do
    [ -f "$_file" ] || continue
    case "$(basename "$_file")" in
      RULES_BUNDLE.md|RULES_INDEX.md) continue ;;
    esac
    printf '%s\n' "$_file"
  done
}

RULE_FILES=$(
  append_rule_dir "$HOME_CODEX_RULES"
  [ -n "$PLUGIN_ROOT" ] && append_rule_dir "$PLUGIN_ROOT/rules"
  append_rule_dir "$CWD/.codex/rules"
  append_rule_dir "$CWD/codex/rules"
  [ -n "$GIT_ROOT" ] && append_rule_dir "$GIT_ROOT/.codex/rules"
  [ -n "$GIT_ROOT" ] && append_rule_dir "$GIT_ROOT/codex/rules"
  2>/dev/null | awk '!seen[$0]++' | sort
)

# Stable checksum: basename + file content. Do not include absolute paths because
# plugin cache paths and repo paths differ.
checksum_rules() {
  if command -v sha256sum >/dev/null 2>&1; then
    _sha="sha256sum"
  elif command -v shasum >/dev/null 2>&1; then
    _sha="shasum -a 256"
  else
    return 1
  fi

  {
    printf '%s\n' "$RULE_FILES" | while IFS= read -r _file; do
      [ -f "$_file" ] || continue
      printf '## %s\n' "$(basename "$_file")"
      cat "$_file"
      printf '\n'
    done
  } | $_sha | awk '{print $1}'
}

CHECKSUM=$(checksum_rules 2>/dev/null || echo "unavailable")
RULE_COUNT=$(printf '%s\n' "$RULE_FILES" | awk 'NF { c++ } END { print c+0 }')

MARKER_DIR="${CWD}/codex_tmp"
MARKER="${MARKER_DIR}/.codex_rules_loaded"
mkdir -p "$MARKER_DIR" 2>/dev/null || true

{
  printf 'checksum=%s\n' "$CHECKSUM"
  printf 'mode=quiet\n'
  printf 'hook_event_name=%s\n' "$HOOK_EVENT_NAME"
  printf 'rule_count=%s\n' "$RULE_COUNT"
  printf 'updated_at=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date)"
  printf '%s\n' "$RULE_FILES" | while IFS= read -r _file; do
    [ -n "$_file" ] && printf 'file=%s\n' "$_file"
  done
} > "$MARKER" 2>/dev/null || true

print_full_rules() {
  printf '📚 [Codex rules]\n'
  printf 'checksum: %s\n' "$CHECKSUM"
  printf 'files:\n'
  printf '%s\n' "$RULE_FILES" | while IFS= read -r _file; do
    [ -f "$_file" ] || continue
    printf -- '- %s\n' "$_file"
  done
  printf '\n'
  printf '%s\n' "$RULE_FILES" | while IFS= read -r _file; do
    [ -f "$_file" ] || continue
    printf -- '---\n'
    printf '## RULE FILE: `%s`\n\n' "$(basename "$_file")"
    cat "$_file"
    printf '\n'
  done
}

json_escape() {
  # jq is preferred; python fallback is available on most dev boxes.
  if [ -n "$JQ" ]; then
    "$JQ" -Rs .
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
  else
    sed 's/\\/\\\\/g; s/"/\\"/g; s/^/"/; s/$/"/'
  fi
}

case "$MODE" in
  print-full)
    print_full_rules
    exit 0
    ;;
esac

# Default: no stdout. This prevents noisy "hook context" blocks in the TUI.
# Optional debug modes.
if [ "${CODEX_RULES_INJECT_OUTPUT:-}" = "full" ]; then
  CONTEXT=$(print_full_rules | json_escape)
  cat <<EOF
{"hookSpecificOutput":{"hookEventName":"${HOOK_EVENT_NAME:-UserPromptSubmit}","additionalContext":$CONTEXT}}
EOF
elif [ "${CODEX_RULES_INJECT_VERBOSE:-0}" = "1" ]; then
  MSG="Codex rules marker refreshed: ${RULE_COUNT} files, checksum ${CHECKSUM}."
  ESCAPED=$(printf '%s' "$MSG" | json_escape)
  cat <<EOF
{"hookSpecificOutput":{"hookEventName":"${HOOK_EVENT_NAME:-UserPromptSubmit}","additionalContext":$ESCAPED}}
EOF
fi

exit 0
