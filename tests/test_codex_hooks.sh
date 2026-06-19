#!/bin/sh
# Codex hooks regression tests

PASS=0
FAIL=0
TOTAL=0
HOOK_DIR="${HOOK_DIR:-/workspace/hooks}"

run_hook_test() {
    hook="$1"
    desc="$2"
    input="$3"
    expect_exit="$4"
    cwd="${5:-/workspace}"

    TOTAL=$((TOTAL + 1))
    actual_exit=0
    run_hook_command "$hook" "$input" "$cwd" || actual_exit=$?

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
    run_hook_command "$hook" "$input" "$cwd" || actual_exit=$?

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

run_hook_command() {
    hook="$1"
    input="$2"
    cwd="$3"
    hook_command=${hook%% *}
    hook_arg=${hook#"$hook_command"}
    hook_arg=${hook_arg# }

    if [ -n "$hook_arg" ]; then
        (cd "$cwd" && printf '%s\n' "$input" | "$hook_command" "$hook_arg" > /tmp/codex_hook_stdout 2> /tmp/codex_hook_stderr)
    else
        (cd "$cwd" && printf '%s\n' "$input" | "$hook_command" > /tmp/codex_hook_stdout 2> /tmp/codex_hook_stderr)
    fi
}

write_test_rules() {
    rules_dir="$1"
    mkdir -p "$rules_dir"
    cat > "$rules_dir/RULES_CORE.md" <<'EOF_RULE'
# RULES_CORE
core rule
EOF_RULE
    cat > "$rules_dir/coding-conventions.md" <<'EOF_RULE'
# Coding Conventions
strict equality
EOF_RULE
}

run_rules_checksum_stability_test() {
    TOTAL=$((TOTAL + 1))
    wd=$(mktemp -d)
    write_test_rules "$wd/home/.codex/rules"
    write_test_rules "$wd/repo/codex/rules"
    write_test_rules "$wd/plugin/rules"

    prompt_input=$(jq -n --arg cwd "$wd/repo" '{hook_event_name: "UserPromptSubmit", cwd: $cwd, prompt: "修正して"}')
    tool_input=$(jq -n --arg cwd "$wd/repo" '{tool_name: "apply_patch", cwd: $cwd, tool_input: {patch: "*** Begin Patch\n*** Add File: x\n+ok\n*** End Patch"}}')

    actual_exit=0
    printf '%s\n' "$prompt_input" | env HOME="$wd/home" PLUGIN_ROOT="$wd/plugin" "$HOOK_DIR/rules-inject.sh" >/dev/null || actual_exit=$?
    with_plugin=$(grep '^checksum=' "$wd/repo/codex_tmp/.codex_rules_loaded" | head -n 1)
    printf '%s\n' "$tool_input" | env -u PLUGIN_ROOT HOME="$wd/home" "$HOOK_DIR/rules-guard.sh" >/dev/null || actual_exit=$?

    printf '%s\n' "$prompt_input" | env -u PLUGIN_ROOT HOME="$wd/home" "$HOOK_DIR/rules-inject.sh" >/dev/null || actual_exit=$?
    without_plugin=$(grep '^checksum=' "$wd/repo/codex_tmp/.codex_rules_loaded" | head -n 1)
    printf '%s\n' "$tool_input" | env HOME="$wd/home" PLUGIN_ROOT="$wd/plugin" "$HOOK_DIR/rules-guard.sh" >/dev/null || actual_exit=$?

    if [ "$actual_exit" -eq 0 ] && [ "$with_plugin" = "$without_plugin" ]; then
        printf "  PASS: rules checksum stable across plugin/home/repo mirrors\n"
        PASS=$((PASS + 1))
    else
        printf "  FAIL: rules checksum stable across plugin/home/repo mirrors\n"
        printf "    with_plugin: %s\n" "$with_plugin"
        printf "    without_plugin: %s\n" "$without_plugin"
        printf "    exit: %s\n" "$actual_exit"
        FAIL=$((FAIL + 1))
    fi
    rm -rf "$wd"
}

run_codex_rules_refresh_test() {
    TOTAL=$((TOTAL + 1))
    wd=$(mktemp -d)
    write_test_rules "$wd/repo/codex/rules"
    mkdir -p "$wd/home"

    actual_exit=0
    (
        cd "$wd/repo" || exit 1
        env HOME="$wd/home" CODEX_RULES_CONTEXT_MODE=none /workspace/bin/codex-rules refresh >/dev/null
    ) || actual_exit=$?
    mode=$(grep '^mode=' "$wd/repo/codex_tmp/.codex_rules_loaded" 2>/dev/null | head -n 1)

    if [ "$actual_exit" -eq 0 ] && [ "$mode" = "mode=enforced" ]; then
        printf "  PASS: codex-rules refresh writes enforced marker\n"
        PASS=$((PASS + 1))
    else
        printf "  FAIL: codex-rules refresh writes enforced marker (mode=%s exit=%s)\n" "$mode" "$actual_exit"
        FAIL=$((FAIL + 1))
    fi
    rm -rf "$wd"
}

run_model_context_test() {
    desc="$1"
    expected="$2"
    shift 2

    TOTAL=$((TOTAL + 1))
    actual_exit=0
    actual=$(/workspace/bin/model-context.sh "$@" 2> /tmp/model_context_stderr) || actual_exit=$?

    if [ "$actual_exit" -eq 0 ] && [ "$actual" = "$expected" ]; then
        printf "  PASS: %s\n" "$desc"
        PASS=$((PASS + 1))
    else
        printf "  FAIL: %s (expected=[%s], actual=[%s], exit=%s)\n" "$desc" "$expected" "$actual" "$actual_exit"
        printf "    stderr: %s\n" "$(cat /tmp/model_context_stderr 2>/dev/null)"
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

ENV_HOOK="${HOOK_DIR}/env-file-protect.sh"
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

MAIN_HOOK="${HOOK_DIR}/main-branch-code-warning.sh"
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

LANG_HOOK="${HOOK_DIR}/language-version-check.sh"
run_hook_test "$LANG_HOOK" "blocks floating language image tag" "$(make_input Bash command "docker run --rm python:slim python -V")" 2
run_hook_test "$LANG_HOOK" "allows pinned language image tag" "$(make_input Bash command "docker run --rm python:3.12-slim python -V")" 0

DISPATCHER="${HOOK_DIR}/hook-dispatcher.sh"
export CODEX_HOOK_TEST_MODE=1
run_hook_test "$DISPATCHER pre-tool-use" "dispatcher allows runner build command" "$(make_input Bash command "npm run build")" 0
run_hook_test "$DISPATCHER pre-tool-use" "dispatcher blocks package install command" "$(make_input Bash command "npm install")" 2
run_hook_test "$DISPATCHER pre-tool-use" "dispatcher blocks rtk git commit command" "$(make_input Bash command "rtk git commit -m test")" 2
run_hook_test "$DISPATCHER pre-tool-use" "dispatcher allows rtk runner build command" "$(make_input Bash command "rtk npm run build")" 0
run_hook_test "$DISPATCHER pre-tool-use" "dispatcher blocks rtk package install command" "$(make_input Bash command "rtk npm install")" 2
run_hook_test "$DISPATCHER pre-tool-use" "dispatcher blocks rtk runtime command" "$(make_input Bash command "rtk python3 script.py")" 2
run_hook_test "$DISPATCHER pre-tool-use" "dispatcher blocks rtk proxy runtime command" "$(make_input Bash command "rtk proxy python3 script.py")" 2
run_hook_stdout_empty_test "$DISPATCHER user-prompt-submit" "dispatcher suppresses prompt reminder output" "$(make_prompt_input "修正して")" 0
run_rules_checksum_stability_test
run_codex_rules_refresh_test

echo ""
echo "=== Codex bin ==="

run_model_context_test "model-context uses explicit context window" '{"maxTokens":128000,"usableTokens":102400}' --context-window-size 128000 "unknown"
run_model_context_test "model-context parses delimited m context" '{"maxTokens":1500000,"usableTokens":1200000}' "gpt-test (1.5m)"
run_model_context_test "model-context parses token context suffix" '{"maxTokens":64000,"usableTokens":51200}' "model 64k token context"
run_model_context_test "model-context joins id and display name" '{"maxTokens":300000,"usableTokens":240000}' --id model-id --display-name "Model [300k]"
run_model_context_test "model-context falls back to default" '{"maxTokens":200000,"usableTokens":160000}' "legacy-model"

SECRET_HOOK="${HOOK_DIR}/secret-leak-check.sh"
run_hook_test "$SECRET_HOOK" "blocks Authorization bearer literal" "$(make_input Bash command "curl -H 'Authorization: Bearer abcdefghijklmnop' https://example.com")" 2
run_hook_test "$SECRET_HOOK" "allows token via environment variable" "$(make_input Bash command "curl --token \"\$TOKEN\" https://example.com")" 0

echo ""
printf "Total: %d, Pass: %d, Fail: %d\n" "$TOTAL" "$PASS" "$FAIL"

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
