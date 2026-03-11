#!/bin/bash
# bin/ スクリプトのテストスイート
# Usage: ./test_bin.sh

set -uo pipefail

PASS=0
FAIL=0
TOTAL=0
REPO_DIR=""
REMOTE_DIR=""

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    TOTAL=$((TOTAL + 1))
    if [ "$expected" = "$actual" ]; then
        printf "  PASS: %s\n" "$desc"
        PASS=$((PASS + 1))
    else
        printf "  FAIL: %s (expected=[%s], actual=[%s])\n" "$desc" "$expected" "$actual"
        FAIL=$((FAIL + 1))
    fi
}

# テスト用 Git リポジトリを作成して cd する
setup_repo() {
    REPO_DIR=$(mktemp -d)
    REMOTE_DIR=$(mktemp -d)
    cd "$REPO_DIR" || exit 1
    git init > /dev/null 2>&1
    git commit --allow-empty -m "initial commit" > /dev/null 2>&1
    git clone --bare "$REPO_DIR" "$REMOTE_DIR/origin.git" > /dev/null 2>&1
    git remote add origin "$REMOTE_DIR/origin.git"
    git push -u origin main > /dev/null 2>&1
}

cleanup_repo() {
    cd /workspace || exit 1
    rm -rf "$REPO_DIR" "$REMOTE_DIR"
}

echo "=== git-new-feature ==="
echo ""
echo "--- 引数解析 ---"

/workspace/bin/git-new-feature -h > /dev/null 2>&1
assert_eq "ヘルプ (-h)" "0" "$?"

/workspace/bin/git-new-feature --help > /dev/null 2>&1
assert_eq "ヘルプ (--help)" "0" "$?"

/workspace/bin/git-new-feature > /dev/null 2>&1
assert_eq "ブランチ名なしでエラー" "1" "$?"

/workspace/bin/git-new-feature --unknown test > /dev/null 2>&1
assert_eq "不明なオプションでエラー" "1" "$?"

(cd /tmp && /workspace/bin/git-new-feature test > /dev/null 2>&1)
assert_eq "Git リポジトリ外でエラー" "1" "$?"

echo ""
echo "--- ブランチ作成 ---"

setup_repo

for case in "feat:test-feature:" "fix:test-fix:-f" "docs:test-docs:-d" "refactor:test-refactor:-r" "chore:test-chore:-c"; do
    prefix="${case%%:*}"
    rest="${case#*:}"
    name="${rest%%:*}"
    flag="${rest#*:}"

    if [ -n "$flag" ]; then
        /workspace/bin/git-new-feature $flag "$name" > /dev/null 2>&1
    else
        /workspace/bin/git-new-feature "$name" > /dev/null 2>&1
    fi
    branch=$(git branch --show-current)
    assert_eq "${prefix}/ プレフィックス" "${prefix}/${name}" "$branch"
    git checkout main > /dev/null 2>&1
done

cleanup_repo

echo ""
echo "=== git-cleanup-branch ==="
echo ""
echo "--- 通常マージ ---"

setup_repo

git checkout -b feat/normal-merge > /dev/null 2>&1
git commit --allow-empty -m "feat: normal merge test" > /dev/null 2>&1
git push -u origin feat/normal-merge > /dev/null 2>&1
git checkout main > /dev/null 2>&1
git merge feat/normal-merge --no-edit > /dev/null 2>&1
git push origin main > /dev/null 2>&1

echo "y" | /workspace/bin/git-cleanup-branch feat/normal-merge > /dev/null 2>&1
exit_code=$?
branch_exists=$(git branch --list feat/normal-merge)
assert_eq "通常マージ後の削除: exit 0" "0" "$exit_code"
assert_eq "通常マージ後の削除: ブランチなし" "" "$branch_exists"

cleanup_repo

echo ""
echo "--- スカッシュマージ ---"

setup_repo

git checkout -b feat/squash-merge > /dev/null 2>&1
git commit --allow-empty -m "feat: squash commit 1" > /dev/null 2>&1
git commit --allow-empty -m "feat: squash commit 2" > /dev/null 2>&1
git push -u origin feat/squash-merge > /dev/null 2>&1
git checkout main > /dev/null 2>&1
git merge --squash feat/squash-merge > /dev/null 2>&1
git commit -m "feat: squash merge test" > /dev/null 2>&1
git push origin main > /dev/null 2>&1

echo "y" | /workspace/bin/git-cleanup-branch feat/squash-merge > /dev/null 2>&1
exit_code=$?
branch_exists=$(git branch --list feat/squash-merge)
assert_eq "スカッシュマージ後の削除: exit 0" "0" "$exit_code"
assert_eq "スカッシュマージ後の削除: ブランチなし" "" "$branch_exists"

cleanup_repo

echo ""
echo "--- メインブランチ保護 ---"

setup_repo

echo "y" | /workspace/bin/git-cleanup-branch main > /dev/null 2>&1
assert_eq "main ブランチ削除はエラー" "1" "$?"

cleanup_repo

echo ""
echo "--- キャンセル ---"

setup_repo
git checkout -b feat/cancel-test > /dev/null 2>&1

echo "n" | /workspace/bin/git-cleanup-branch > /dev/null 2>&1
assert_eq "キャンセル: exit 0" "0" "$?"
branch_exists=$(git branch --list feat/cancel-test)
branch_exists=$(echo "$branch_exists" | sed 's/^[* ]*//')
assert_eq "キャンセル: ブランチ残存" "feat/cancel-test" "$branch_exists"

cleanup_repo

echo ""
echo "=== 結果: ${PASS}/${TOTAL} passed, ${FAIL} failed ==="

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
