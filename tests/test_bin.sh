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

echo "=== Codex plugin-only workflow ==="
echo ""

legacy_wrapper_count=0
for legacy_wrapper in codex-cmd codex-feat codex-fix codex-code-review codex-deep-review codex-commit; do
    if [ -e "/workspace/bin/${legacy_wrapper}" ]; then
        legacy_wrapper_count=$((legacy_wrapper_count + 1))
    fi
done
assert_eq "plugin-only: 旧 Codex prompt wrapper を配布しない" "0" "$legacy_wrapper_count"

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

/workspace/bin/git-new-feature "日本語ブランチ" > /dev/null 2>&1
assert_eq "非ASCII文字でエラー" "1" "$?"

/workspace/bin/git-new-feature "test with spaces" > /dev/null 2>&1
assert_eq "スペース含みでエラー" "1" "$?"

echo ""
echo "=== claude-init-project ==="
echo ""

TEMPLATE_HOME=$(mktemp -d)
INIT_REPO=$(mktemp -d)
mkdir -p "$TEMPLATE_HOME/.claude/notes" "$TEMPLATE_HOME/.claude/scratch"
cp /workspace/claude/notes/_template.md /workspace/claude/notes/README.md \
    "$TEMPLATE_HOME/.claude/notes/"
cp /workspace/claude/scratch/_template.md /workspace/claude/scratch/README.md \
    "$TEMPLATE_HOME/.claude/scratch/"
git -C "$INIT_REPO" init > /dev/null 2>&1
(cd "$INIT_REPO" && HOME="$TEMPLATE_HOME" /workspace/bin/claude-init-project --dry-run > /dev/null 2>&1)
assert_eq "installerが配置する既定テンプレートを利用" "0" "$?"
rm -rf "$TEMPLATE_HOME" "$INIT_REPO"

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
echo "--- リモートなしブランチ作成 ---"

REPO_DIR=$(mktemp -d)
cd "$REPO_DIR" || exit 1
git init > /dev/null 2>&1
git commit --allow-empty -m "initial commit" > /dev/null 2>&1

output=$(/workspace/bin/git-new-feature test-no-remote 2>&1)
exit_code=$?
branch=$(git branch --show-current)
has_warning=$(echo "$output" | grep -c "リモート.*未設定" || true)
assert_eq "リモートなしでブランチ作成: exit 0" "0" "$exit_code"
assert_eq "リモートなしでブランチ作成: 正しいブランチ名" "feat/test-no-remote" "$branch"
assert_eq "リモートなしでブランチ作成: 警告メッセージ表示" "1" "$has_warning"

cd /workspace || exit 1
rm -rf "$REPO_DIR"

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
echo "change1" > squash1.txt && git add squash1.txt > /dev/null 2>&1
git commit -m "feat: squash commit 1" > /dev/null 2>&1
echo "change2" > squash2.txt && git add squash2.txt > /dev/null 2>&1
git commit -m "feat: squash commit 2" > /dev/null 2>&1
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
echo "--- ローカルのみマージ (push なし) ---"

setup_repo

git checkout -b feat/local-only > /dev/null 2>&1
git commit --allow-empty -m "feat: local only" > /dev/null 2>&1
# リモートに push しない
git checkout main > /dev/null 2>&1
git merge feat/local-only --no-edit > /dev/null 2>&1

echo "y" | /workspace/bin/git-cleanup-branch feat/local-only > /dev/null 2>&1
exit_code=$?
branch_exists=$(git branch --list feat/local-only)
assert_eq "ローカルマージ後の削除: exit 0" "0" "$exit_code"
assert_eq "ローカルマージ後の削除: ブランチなし" "" "$branch_exists"

cleanup_repo

echo ""
echo "--- ローカルスカッシュマージ (push なし) ---"

setup_repo

git checkout -b feat/local-squash > /dev/null 2>&1
echo "local1" > local1.txt && git add local1.txt > /dev/null 2>&1
git commit -m "feat: local squash 1" > /dev/null 2>&1
echo "local2" > local2.txt && git add local2.txt > /dev/null 2>&1
git commit -m "feat: local squash 2" > /dev/null 2>&1
# リモートに push しない
git checkout main > /dev/null 2>&1
git merge --squash feat/local-squash > /dev/null 2>&1
git commit -m "feat: local squash merge" > /dev/null 2>&1

echo "y" | /workspace/bin/git-cleanup-branch feat/local-squash > /dev/null 2>&1
exit_code=$?
branch_exists=$(git branch --list feat/local-squash)
assert_eq "ローカルスカッシュマージ後の削除: exit 0" "0" "$exit_code"
assert_eq "ローカルスカッシュマージ後の削除: ブランチなし" "" "$branch_exists"

cleanup_repo

echo ""
echo "--- 未マージブランチ (キャンセル) ---"

setup_repo

git checkout -b feat/unmerged > /dev/null 2>&1
echo "unmerged" > unmerged.txt && git add unmerged.txt > /dev/null 2>&1
git commit -m "feat: unmerged work" > /dev/null 2>&1
git checkout main > /dev/null 2>&1

echo "n" | /workspace/bin/git-cleanup-branch feat/unmerged > /dev/null 2>&1
branch_exists=$(git branch --list feat/unmerged)
branch_exists=$(echo "$branch_exists" | sed 's/^[* ]*//')
assert_eq "未マージ拒否: ブランチ残存" "feat/unmerged" "$branch_exists"

cleanup_repo

echo ""
echo "--- リモートなしマージ ---"

REPO_DIR=$(mktemp -d)
cd "$REPO_DIR" || exit 1
git init > /dev/null 2>&1
git commit --allow-empty -m "initial commit" > /dev/null 2>&1
# リモート未設定
git checkout -b feat/no-remote > /dev/null 2>&1
git commit --allow-empty -m "feat: no remote" > /dev/null 2>&1
git checkout main > /dev/null 2>&1
git merge feat/no-remote --no-edit > /dev/null 2>&1
git checkout feat/no-remote > /dev/null 2>&1

output=$(echo "y" | /workspace/bin/git-cleanup-branch 2>&1)
exit_code=$?
branch_exists=$(git branch --list feat/no-remote)
has_pull_warning=$(echo "$output" | grep -c "リモート.*未設定.*pull" || true)
has_push_warning=$(echo "$output" | grep -c "リモート.*未設定.*リモートブランチ" || true)
has_push_error=$(echo "$output" | grep -c "fatal.*remote" || true)
assert_eq "リモートなしマージ後の削除: exit 0" "0" "$exit_code"
assert_eq "リモートなしマージ後の削除: ブランチなし" "" "$branch_exists"
assert_eq "リモートなしマージ後の削除: pull スキップ警告" "1" "$has_pull_warning"
assert_eq "リモートなしマージ後の削除: push スキップ警告" "1" "$has_push_warning"
assert_eq "リモートなしマージ後の削除: push エラーなし" "0" "$has_push_error"

cd /workspace || exit 1
rm -rf "$REPO_DIR"

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
