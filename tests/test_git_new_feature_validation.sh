#!/bin/sh
# git-new-feature の入力検証に関する回帰テスト

set -u

PASS=0
FAIL=0
TOTAL=0
WORKSPACE=${WORKSPACE:-/workspace}
SCRIPT="${WORKSPACE}/bin/git-new-feature"

assert_invalid_ref() {
    _name=$1
    TOTAL=$((TOTAL + 1))

    _output=$($SCRIPT "$_name" 2>&1)
    _status=$?

    if [ "$_status" -eq 1 ] && printf '%s\n' "$_output" | grep -q 'Gitで無効なブランチ名'; then
        printf '  PASS: invalid ref rejected: %s\n' "$_name"
        PASS=$((PASS + 1))
    else
        printf '  FAIL: invalid ref not rejected as Git ref: %s (status=%s)\n%s\n' \
            "$_name" "$_status" "$_output"
        FAIL=$((FAIL + 1))
    fi
}

assert_multiple_names_rejected() {
    TOTAL=$((TOTAL + 1))

    _output=$($SCRIPT first second 2>&1)
    _status=$?

    if [ "$_status" -eq 1 ] && printf '%s\n' "$_output" | grep -q 'ブランチ名は1つだけ'; then
        printf '  PASS: multiple branch names rejected\n'
        PASS=$((PASS + 1))
    else
        printf '  FAIL: multiple branch names not rejected (status=%s)\n%s\n' \
            "$_status" "$_output"
        FAIL=$((FAIL + 1))
    fi
}

printf '%s\n' '=== git-new-feature ref validation ==='

# 文字種としては許容されるが、Gitのrefとして無効な形式。
assert_invalid_ref 'bad..name'
assert_invalid_ref 'topic.lock'
assert_invalid_ref 'trailing.'
assert_invalid_ref 'double//slash'
assert_invalid_ref '.leading'
assert_multiple_names_rejected

printf '\n=== result: %s/%s passed, %s failed ===\n' "$PASS" "$TOTAL" "$FAIL"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
