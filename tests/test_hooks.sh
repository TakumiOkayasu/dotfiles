#!/bin/sh
# hooks テストスイート
# Usage: ./test_hooks.sh

HOOK="/workspace/hooks/git-commit-push-block.sh"
PASS=0
FAIL=0
TOTAL=0

# テストヘルパー
run_test() {
    desc="$1"
    input="$2"
    expect_exit="$3"  # 0=許可, 2=ブロック

    TOTAL=$((TOTAL + 1))
    actual_exit=0
    printf '%s\n' "$input" | "$HOOK" > /dev/null 2>&1 || actual_exit=$?

    if [ "$actual_exit" -eq "$expect_exit" ]; then
        printf "  PASS: %s\n" "$desc"
        PASS=$((PASS + 1))
    else
        printf "  FAIL: %s (expected=%d, actual=%d)\n" "$desc" "$expect_exit" "$actual_exit"
        FAIL=$((FAIL + 1))
    fi
}

make_input() {
    printf '{"tool_input":{"command":"%s"}}' "$1"
}

echo "=== git-commit-push-block.sh ==="
echo ""
echo "--- ブロックすべきコマンド (exit 2) ---"

# git commit
run_test "git commit -m test" "$(make_input 'git commit -m test')" 2
run_test "git commit --amend" "$(make_input 'git commit --amend')" 2
run_test "git commit (引数なし)" "$(make_input 'git commit')" 2

# git push
run_test "git push" "$(make_input 'git push')" 2
run_test "git push origin main" "$(make_input 'git push origin main')" 2
run_test "git push -u origin feat/x" "$(make_input 'git push -u origin feat/x')" 2

# チェーン内の git commit/push
run_test "チェーン: && git commit" "$(make_input 'git add . && git commit -m msg')" 2
run_test "チェーン: ; git push" "$(make_input 'echo done; git push')" 2

# git reset --hard
run_test "git reset --hard" "$(make_input 'git reset --hard')" 2
run_test "git reset --hard HEAD~1" "$(make_input 'git reset --hard HEAD~1')" 2
run_test "git reset HEAD --hard" "$(make_input 'git reset HEAD --hard')" 2

# git clean -f
run_test "git clean -f" "$(make_input 'git clean -f')" 2
run_test "git clean -fd" "$(make_input 'git clean -fd')" 2
run_test "git clean -xfd" "$(make_input 'git clean -xfd')" 2

# git checkout -- .
run_test "git checkout -- ." "$(make_input 'git checkout -- .')" 2

# git restore
run_test "git restore ." "$(make_input 'git restore .')" 2
run_test "git restore --staged ." "$(make_input 'git restore --staged .')" 2
run_test "git restore somefile.txt" "$(make_input 'git restore somefile.txt')" 2

echo ""
echo "--- 許可すべきコマンド (exit 0) ---"

# 安全な git コマンド
run_test "git status" "$(make_input 'git status')" 0
run_test "git diff" "$(make_input 'git diff')" 0
run_test "git log" "$(make_input 'git log --oneline -5')" 0
run_test "git branch" "$(make_input 'git branch -a')" 0
run_test "git add" "$(make_input 'git add .')" 0
run_test "git stash" "$(make_input 'git stash')" 0
run_test "git fetch" "$(make_input 'git fetch origin')" 0
run_test "git pull" "$(make_input 'git pull')" 0
run_test "git checkout branch" "$(make_input 'git checkout feat/something')" 0
run_test "git switch" "$(make_input 'git switch main')" 0
run_test "git merge" "$(make_input 'git merge feat/x')" 0
run_test "git rebase" "$(make_input 'git rebase main')" 0
run_test "git reset (soft)" "$(make_input 'git reset --soft HEAD~1')" 0
run_test "git clean (dry-run)" "$(make_input 'git clean -n')" 0
run_test "git clean -d (no -f)" "$(make_input 'git clean -d')" 0

# 非 git コマンド
run_test "ls" "$(make_input 'ls -la')" 0
run_test "echo" "$(make_input 'echo hello')" 0
run_test "空コマンド" '{"tool_input":{"command":""}}' 0

echo ""
echo "=== 結果: ${PASS}/${TOTAL} passed, ${FAIL} failed ==="

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
