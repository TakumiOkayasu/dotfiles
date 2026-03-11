#!/bin/sh
# hooks テストスイート
# Usage: ./test_hooks.sh

HOOK="/workspace/hooks/destructive-command-block.sh"
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

echo "=== destructive-command-block.sh ==="
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
run_test "git clean --force" "$(make_input 'git clean --force')" 2

# git checkout -- .
run_test "git checkout -- ." "$(make_input 'git checkout -- .')" 2

# git restore
run_test "git restore ." "$(make_input 'git restore .')" 2
run_test "git restore --staged ." "$(make_input 'git restore --staged .')" 2
run_test "git restore somefile.txt" "$(make_input 'git restore somefile.txt')" 2

# git rebase (履歴改変)
run_test "git rebase main" "$(make_input 'git rebase main')" 2
run_test "git rebase -i HEAD~3" "$(make_input 'git rebase -i HEAD~3')" 2

# git branch -D (強制削除)
run_test "git branch -D feat/old" "$(make_input 'git branch -D feat/old')" 2
run_test "git branch --delete --force feat/old" "$(make_input 'git branch --delete --force feat/old')" 2
run_test "git branch --force --delete feat/old" "$(make_input 'git branch --force --delete feat/old')" 2

# git stash drop/clear
run_test "git stash drop" "$(make_input 'git stash drop')" 2
run_test "git stash clear" "$(make_input 'git stash clear')" 2

# rm -rf
run_test "rm -rf dist/" "$(make_input 'rm -rf dist/')" 2
run_test "rm -fr node_modules/" "$(make_input 'rm -fr node_modules/')" 2
run_test "rm -r -f dir/" "$(make_input 'rm -r -f dir/')" 2
run_test "rm -v -r -f dir/" "$(make_input 'rm -v -r -f dir/')" 2
run_test "rm -Rf dist/" "$(make_input 'rm -Rf dist/')" 2
run_test "rm -fR node_modules/" "$(make_input 'rm -fR node_modules/')" 2
run_test "rm -iRf dir/" "$(make_input 'rm -iRf dir/')" 2
run_test "rm -R -f dir/" "$(make_input 'rm -R -f dir/')" 2
run_test "rm --recursive --force dir/" "$(make_input 'rm --recursive --force dir/')" 2
run_test "rm --force --recursive dir/" "$(make_input 'rm --force --recursive dir/')" 2

# docker volume rm / system prune
run_test "docker volume rm mydata" "$(make_input 'docker volume rm mydata')" 2
run_test "docker system prune -a" "$(make_input 'docker system prune -a')" 2

# gh repo delete
run_test "gh repo delete owner/repo" "$(make_input 'gh repo delete owner/repo')" 2

# git filter-branch / reflog expire
run_test "git filter-branch" "$(make_input 'git filter-branch --tree-filter')" 2
run_test "git reflog expire" "$(make_input 'git reflog expire --all')" 2

# truncate / shred / dd
run_test "truncate -s 0 file" "$(make_input 'truncate -s 0 file')" 2
run_test "shred file" "$(make_input 'shred secret.txt')" 2
run_test "dd if=/dev/zero" "$(make_input 'dd if=/dev/zero of=disk.img')" 2

# チェーン内の破壊的操作
run_test "チェーン: && rm -rf" "$(make_input 'cd /tmp && rm -rf dist/')" 2
run_test "チェーン: ; docker system prune" "$(make_input 'echo done; docker system prune')" 2

echo ""
echo "--- 許可すべきコマンド (exit 0) ---"

# 安全な git コマンド
run_test "git status" "$(make_input 'git status')" 0
run_test "git diff" "$(make_input 'git diff')" 0
run_test "git log" "$(make_input 'git log --oneline -5')" 0
run_test "git branch -a" "$(make_input 'git branch -a')" 0
run_test "git branch -d feat/merged" "$(make_input 'git branch -d feat/merged')" 0
run_test "git add" "$(make_input 'git add .')" 0
run_test "git stash" "$(make_input 'git stash')" 0
run_test "git fetch" "$(make_input 'git fetch origin')" 0
run_test "git pull" "$(make_input 'git pull')" 0
run_test "git checkout branch" "$(make_input 'git checkout feat/something')" 0
run_test "git switch" "$(make_input 'git switch main')" 0
run_test "git merge" "$(make_input 'git merge feat/x')" 0
run_test "git reset (soft)" "$(make_input 'git reset --soft HEAD~1')" 0
run_test "git clean (dry-run)" "$(make_input 'git clean -n')" 0
run_test "git clean -d (no -f)" "$(make_input 'git clean -d')" 0

# 安全なファイル・Docker コマンド
run_test "rm file.txt" "$(make_input 'rm file.txt')" 0
run_test "docker run --rm" "$(make_input 'docker run --rm alpine echo hi')" 0
run_test "rm --force file.txt" "$(make_input 'rm --force file.txt')" 0
run_test "rm --recursive dir/" "$(make_input 'rm --recursive dir/')" 0
run_test "rm -R dir/" "$(make_input 'rm -R dir/')" 0
run_test "truncate in filename" "$(make_input 'cat truncate.log')" 0
run_test "shred in path" "$(make_input 'ls /var/shred/')" 0
run_test "dd in word" "$(make_input 'echo added')" 0

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
