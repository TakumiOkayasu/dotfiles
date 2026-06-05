#!/bin/sh
# Codex hooks regression tests

PASS=0
FAIL=0
TOTAL=0

run_hook_test() {
    hook="$1"
    desc="$2"
    input="$3"
    expect_exit="$4"
    cwd="${5:-/workspace}"

    TOTAL=$((TOTAL + 1))
    actual_exit=0
    (cd "$cwd" && set -- $hook && printf '%s\n' "$input" | "$@" > /tmp/codex_hook_stdout 2> /tmp/codex_hook_stderr) || actual_exit=$?

    if [ "$actual_exit" -eq "$expect_exit" ]; then
        printf "  PASS: %s\n" "$desc"
        PASS=$((PASS + 1))
    else
        printf "  FAIL: %s (expected=%d, actual=%d)\n" "$desc" "$expect_exit" "$actual_exit"
        printf "    stderr: %s\n" "$(cat /tmp/codex_hook_stderr 2>/dev/null)"
        FAIL=$((FAIL + 1))
    fi
}

run_hook_stdout_empty_test() {
    hook="$1"
    desc="$2"
    input="$3"
    expect_exit="$4"
    cwd="${5:-/workspace}"

    TOTAL=$((TOTAL + 1))
    actual_exit=0
    (cd "$cwd" && set -- $hook && printf '%s\n' "$input" | "$@" > /tmp/codex_hook_stdout 2> /tmp/codex_hook_stderr) || actual_exit=$?

    if [ "$actual_exit" -eq "$expect_exit" ] && [ ! -s /tmp/codex_hook_stdout ]; then
        printf "  PASS: %s\n" "$desc"
        PASS=$((PASS + 1))
    else
        printf "  FAIL: %s (expected_exit=%d, actual=%d)\n" "$desc" "$expect_exit" "$actual_exit"
        printf "    stdout: %s\n" "$(cat /tmp/codex_hook_stdout 2>/dev/null)"
        printf "    stderr: %s\n" "$(cat /tmp/codex_hook_stderr 2>/dev/null)"
        FAIL=$((FAIL + 1))
    fi
}

make_input() {
    tool="$1"
    field="$2"
    value="$3"
    jq -n --arg tool "$tool" --arg field "$field" --arg value "$value" \
        '{tool_name: $tool, tool_input: {($field): $value}}'
}

make_prompt_input() {
    prompt="$1"
    jq -n --arg prompt "$prompt" '{hook_event_name: "UserPromptSubmit", cwd: "/workspace", prompt: $prompt}'
}

echo "=== Codex hooks ==="

ENV_HOOK="/workspace/hooks/env-file-protect.sh"
PATCH_ENV='*** Begin Patch
*** Update File: .env
@@
+TOKEN=x
*** End Patch'
PATCH_ENV_EXAMPLE='*** Begin Patch
*** Update File: .env.example
@@
+TOKEN=
*** End Patch'

run_hook_test "$ENV_HOOK" "apply_patch blocks .env edits" "$(make_input apply_patch command "$PATCH_ENV")" 2
run_hook_test "$ENV_HOOK" "apply_patch allows .env.example" "$(make_input apply_patch command "$PATCH_ENV_EXAMPLE")" 0
run_hook_test "$ENV_HOOK" "Write blocks .env edits" "$(make_input Write file_path ".env.local")" 2

MAIN_HOOK="/workspace/hooks/main-branch-code-warning.sh"
REPO_DIR=$(mktemp -d)
git init -b main "$REPO_DIR" >/dev/null 2>&1

PATCH_CODE='*** Begin Patch
*** Add File: src/app.py
@@
+print("x")
*** End Patch'
PATCH_DOC='*** Begin Patch
*** Update File: README.md
@@
+note
*** End Patch'

run_hook_test "$MAIN_HOOK" "main branch apply_patch blocks code files" "$(make_input apply_patch command "$PATCH_CODE")" 2 "$REPO_DIR"
run_hook_test "$MAIN_HOOK" "main branch apply_patch allows docs" "$(make_input apply_patch command "$PATCH_DOC")" 0 "$REPO_DIR"
git -C "$REPO_DIR" switch -c feat/test >/dev/null 2>&1
run_hook_test "$MAIN_HOOK" "feature branch apply_patch allows code files" "$(make_input apply_patch command "$PATCH_CODE")" 0 "$REPO_DIR"

LANG_HOOK="/workspace/hooks/language-version-check.sh"
run_hook_test "$LANG_HOOK" "blocks floating language image tag" "$(make_input Bash command "docker run --rm python:slim python -V")" 2
run_hook_test "$LANG_HOOK" "allows pinned language image tag" "$(make_input Bash command "docker run --rm python:3.12-slim python -V")" 0

DISPATCHER="/workspace/hooks/hook-dispatcher.sh"
export CODEX_HOOK_TEST_MODE=1
run_hook_test "$DISPATCHER pre-tool-use" "dispatcher allows runner build command" "$(make_input Bash command "npm run build")" 0
run_hook_test "$DISPATCHER pre-tool-use" "dispatcher blocks package install command" "$(make_input Bash command "npm install")" 2
run_hook_test "$DISPATCHER pre-tool-use" "dispatcher blocks rtk git commit command" "$(make_input Bash command "rtk git commit -m test")" 2
run_hook_test "$DISPATCHER pre-tool-use" "dispatcher allows rtk runner build command" "$(make_input Bash command "rtk npm run build")" 0
run_hook_test "$DISPATCHER pre-tool-use" "dispatcher blocks rtk package install command" "$(make_input Bash command "rtk npm install")" 2
run_hook_test "$DISPATCHER pre-tool-use" "dispatcher blocks rtk runtime command" "$(make_input Bash command "rtk python3 script.py")" 2
run_hook_test "$DISPATCHER pre-tool-use" "dispatcher blocks rtk proxy runtime command" "$(make_input Bash command "rtk proxy python3 script.py")" 2
run_hook_stdout_empty_test "$DISPATCHER user-prompt-submit" "dispatcher suppresses prompt reminder output" "$(make_prompt_input "修正して")" 0

SECRET_HOOK="/workspace/hooks/secret-leak-check.sh"
run_hook_test "$SECRET_HOOK" "blocks Authorization bearer literal" "$(make_input Bash command "curl -H 'Authorization: Bearer abcdefghijklmnop' https://example.com")" 2
run_hook_test "$SECRET_HOOK" "allows token via environment variable" "$(make_input Bash command 'curl --token "$TOKEN" https://example.com')" 0

echo ""
printf "Total: %d, Pass: %d, Fail: %d\n" "$TOTAL" "$PASS" "$FAIL"

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
