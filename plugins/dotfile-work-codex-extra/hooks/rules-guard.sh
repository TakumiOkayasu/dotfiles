#!/bin/sh
# rules-guard.sh - concise, quiet PreToolUse guard
#
# Blocks only mutating operations when the quiet rules marker is missing or
# stale. Read-only commands are allowed to avoid deadlocks and noisy output.

# POSIX sh. Avoid set -e for predictable hook behavior.

[ -t 0 ] && exit 0
INPUT=$(cat)

JQ=$(command -v jaq 2>/dev/null || command -v jq 2>/dev/null || echo "")
[ -z "$JQ" ] && exit 0

HOOK_EVENT_NAME=$(printf '%s\n' "$INPUT" | "$JQ" -r '.hook_event_name // ""' 2>/dev/null) || HOOK_EVENT_NAME=""
TOOL_NAME=$(printf '%s\n' "$INPUT" | "$JQ" -r '.tool_name // ""' 2>/dev/null) || TOOL_NAME=""
CWD=$(printf '%s\n' "$INPUT" | "$JQ" -r '.cwd // ""' 2>/dev/null) || CWD=""
[ -z "$CWD" ] && CWD=$(pwd)

# Only PreToolUse should be guarded.
[ "$HOOK_EVENT_NAME" = "PreToolUse" ] || exit 0

COMMAND=""
case "$TOOL_NAME" in
  Bash)
    COMMAND=$(printf '%s\n' "$INPUT" | "$JQ" -r '.tool_input.command // ""' 2>/dev/null) || COMMAND=""
    ;;
esac

is_mutating_bash() {
  _cmd=$(printf '%s\n' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  [ -z "$_cmd" ] && return 1

  # Explicitly allow common read-only inspection commands.
  case "$_cmd" in
    git\ status*|git\ diff*|git\ log*|git\ show*|git\ grep*|git\ branch\ --show-current*|git\ rev-parse*|git\ ls-files*|git\ remote\ -v*|git\ config\ --get*)
      return 1 ;;
    glab\ issue\ view*|glab\ mr\ view*|glab\ api\ -X\ GET*|gh\ issue\ view*|gh\ pr\ view*|gh\ api\ repos/*)
      return 1 ;;
    ls*|pwd|cat\ *|head\ *|tail\ *|rg\ *|grep\ *|find\ *|sed\ -n\ *|awk\ *|wc\ *|sort\ *|uniq\ *|jq\ *|jaq\ *)
      return 1 ;;
    codex-rules*|*/codex-rules*|*rules-inject.sh*|*rules-required*)
      return 1 ;;
  esac

  # Detect obvious mutations.
  printf '%s\n' "$_cmd" | grep -Eq '(^|[;&|][[:space:]]*)(touch|mkdir|rm|mv|cp|chmod|chown|ln|tee|truncate|shred|dd)([[:space:]]|$)' && return 0
  printf '%s\n' "$_cmd" | grep -Eq '(^|[;&|][[:space:]]*)git[[:space:]]+(add|commit|push|reset|clean|restore|checkout|rebase|merge|stash|branch[[:space:]]+-D)([[:space:]]|$)' && return 0
  printf '%s\n' "$_cmd" | grep -Eq '(^|[;&|][[:space:]]*)(npm|pnpm|yarn)[[:space:]]+(install|add|remove|update|upgrade|i)([[:space:]]|$)' && return 0
  printf '%s\n' "$_cmd" | grep -Eq '(^|[;&|][[:space:]]*)(pip|pip3|poetry|uv)[[:space:]]+(install|add|remove|sync|lock)([[:space:]]|$)' && return 0
  printf '%s\n' "$_cmd" | grep -Eq '(^|[;&|][[:space:]]*)docker[[:space:]]+(system[[:space:]]+prune|volume[[:space:]]+rm)([[:space:]]|$)' && return 0
  printf '%s\n' "$_cmd" | grep -Eq '(^|[;&|][[:space:]]*)(gh|glab)[[:space:]]+(repo[[:space:]]+delete|issue[[:space:]]+(create|edit|close|delete)|pr[[:space:]]+(create|edit|close|merge))([[:space:]]|$)' && return 0
  printf '%s\n' "$_cmd" | grep -Eq '(^|[^<])>>?[^&]' && return 0
  printf '%s\n' "$_cmd" | grep -Eq 'sed[[:space:]].*-i|perl[[:space:]].*-pi' && return 0

  return 1
}

NEEDS_RULES=0
case "$TOOL_NAME" in
  Edit|Write|MultiEdit|apply_patch|ApplyPatch)
    NEEDS_RULES=1
    ;;
  Bash)
    if is_mutating_bash "$COMMAND"; then
      NEEDS_RULES=1
    fi
    ;;
  *)
    NEEDS_RULES=0
    ;;
esac

[ "$NEEDS_RULES" -eq 1 ] || exit 0

# Recompute the same stable checksum as rules-inject.sh.
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

CURRENT_CHECKSUM=$(checksum_rules 2>/dev/null || echo "unavailable")
MARKER="${CWD}/codex_tmp/.codex_rules_loaded"

deny() {
  _reason="$1"
  # Keep stderr short. This appears in the UI only on actual block.
  echo "[rules-guard] BLOCK: $_reason" >&2
  exit 2
}

[ -f "$MARKER" ] || deny "rules marker missing. Start a new turn or run rules-required before editing."

EXPECTED=$(sed -n 's/^checksum=//p' "$MARKER" | head -1)
[ -n "$EXPECTED" ] || deny "rules marker invalid."

if [ "$EXPECTED" != "$CURRENT_CHECKSUM" ]; then
  deny "rules changed. Start a new turn or run rules-required before editing."
fi

exit 0
