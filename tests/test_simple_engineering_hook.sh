#!/bin/sh
# Focused regression tests for Simple Engineering UserPromptSubmit context injection.
set -eu

HOOK_DIR="${HOOK_DIR:-/workspace/hooks}"
WD=$(mktemp -d)
trap 'rm -rf "$WD"' EXIT HUP INT TERM

write_rules() {
    dir="$1"
    invariant="$2"
    mkdir -p "$dir"
    cat > "$dir/RULES_CORE.md" <<'EOF_CORE'
# RULES_CORE
core rule
EOF_CORE
    cat > "$dir/simple-engineering.md" <<EOF_SIMPLE
# Simple Engineering
PORTABILITY_NOISE
<!-- simple-engineering-invariants:start -->
## Mandatory invariants
- $invariant
<!-- simple-engineering-invariants:end -->
EOF_SIMPLE
}

write_rules "$WD/home/.codex/rules" "HOME_ONLY_INVARIANT"
write_rules "$WD/repo/.codex/rules" "REPO_INVARIANT"

CODING_INPUT=$(jq -n --arg cwd "$WD/repo" '{
    hook_event_name: "UserPromptSubmit",
    cwd: $cwd,
    prompt: "バグを修正して"
}')
NON_CODING_INPUT=$(jq -n --arg cwd "$WD/repo" '{
    hook_event_name: "UserPromptSubmit",
    cwd: $cwd,
    prompt: "READMEを要約して"
}')

printf '%s\n' "$CODING_INPUT" | env HOME="$WD/home" CODEX_RULES_CONTEXT_MODE=simple-engineering \
    "$HOOK_DIR/rules-inject.sh" > "$WD/coding.out" 2> "$WD/coding.err"
grep -Fq '[Simple Engineering: mandatory for this coding task]' "$WD/coding.out"
grep -Fq 'REPO_INVARIANT' "$WD/coding.out"
! grep -Fq 'HOME_ONLY_INVARIANT' "$WD/coding.out"
! grep -Fq 'PORTABILITY_NOISE' "$WD/coding.out"
grep -Fq 'mode=enforced' "$WD/repo/codex_tmp/.codex_rules_loaded"

printf '%s\n' "$NON_CODING_INPUT" | env HOME="$WD/home" CODEX_RULES_CONTEXT_MODE=simple-engineering \
    "$HOOK_DIR/rules-inject.sh" > "$WD/non-coding.out" 2> "$WD/non-coding.err"
[ ! -s "$WD/non-coding.out" ]
grep -Fq 'mode=core' "$WD/repo/codex_tmp/.codex_rules_loaded"

cat > "$WD/repo/.codex/rules/simple-engineering.md" <<'EOF_BROKEN'
# Simple Engineering
mandatory markers are missing
EOF_BROKEN
set +e
printf '%s\n' "$CODING_INPUT" | env HOME="$WD/home" CODEX_RULES_CONTEXT_MODE=simple-engineering \
    "$HOOK_DIR/rules-inject.sh" > "$WD/broken.out" 2> "$WD/broken.err"
BROKEN_EXIT=$?
set -e
[ "$BROKEN_EXIT" -eq 2 ]
[ ! -e "$WD/repo/codex_tmp/.codex_rules_loaded" ]
grep -Fq 'missing the mandatory invariant markers' "$WD/broken.err"

printf '%s\n' "Simple Engineering hook tests passed"
