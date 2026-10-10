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
echo "--- default ブランチ以外にだけマージされたブランチ ---"

setup_repo

git checkout -b feat/only-other > /dev/null 2>&1
git commit --allow-empty -m "feat: only merged into other branch" > /dev/null 2>&1
git push -u origin feat/only-other > /dev/null 2>&1
git checkout -b feat/other-head > /dev/null 2>&1

printf 'y\nn\n' | /workspace/bin/git-cleanup-branch feat/only-other > /dev/null 2>&1
branch_exists=$(git branch --list feat/only-other)
branch_exists=$(echo "$branch_exists" | sed 's/^[* ]*//')
remote_exists=$(git --git-dir="$REMOTE_DIR/origin.git" show-ref --verify --quiet refs/heads/feat/only-other; echo "$?")
assert_eq "default ブランチに未マージ: ローカルブランチを残す" "feat/only-other" "$branch_exists"
assert_eq "default ブランチに未マージ: リモートブランチを残す" "0" "$remote_exists"

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
echo "=== gh-setup-repo ==="
echo ""

FAKE_GH_DIR=$(mktemp -d)
FAKE_GH_CALLS=$(mktemp)
FAKE_GH_PAYLOAD=$(mktemp)
cat > "$FAKE_GH_DIR/gh" <<'EOF'
#!/bin/bash
set -u

printf '%s\n' "$*" >> "$FAKE_GH_CALLS"

if [[ "$1" == "auth" && "$2" == "status" ]]; then
    exit 0
fi

if [[ "$1" != "api" ]]; then
    exit 1
fi

case " $* " in
    *" --jq .default_branch "*)
        printf '%s\n' "${FAKE_GH_DEFAULT_BRANCH:-main}"
        exit 0
        ;;
esac

case " $* " in
    *" -X PATCH "*)
        exit 0
        ;;
    *" -X PUT "*)
        cat > "$FAKE_GH_PAYLOAD"
        exit 0
        ;;
esac

if [[ "${FAKE_GH_PROTECTION_MODE:-ok}" == "error" ]]; then
    echo "gh: Forbidden (HTTP 403)" >&2
    exit 1
fi

if [[ "${FAKE_GH_PROTECTION_MODE:-ok}" == "unprotected" ]]; then
    echo "gh: Branch not protected (HTTP 404)" >&2
    exit 1
fi

printf '%s\n' "$FAKE_GH_PROTECTION_JSON"
EOF
chmod +x "$FAKE_GH_DIR/gh"

export FAKE_GH_CALLS FAKE_GH_PAYLOAD
export FAKE_GH_DEFAULT_BRANCH='release/東京'
export FAKE_GH_PROTECTION_JSON='{
  "url":"https://api.github.test/protection",
  "required_status_checks":{"url":"x","contexts_url":"x","strict":true,"contexts":["unit"],"checks":[{"context":"unit","app_id":42}]},
  "enforce_admins":{"url":"x","enabled":true},
  "required_pull_request_reviews":{"url":"x","dismiss_stale_reviews":true,"require_code_owner_reviews":true,"required_approving_review_count":2,"require_last_push_approval":true,"dismissal_restrictions":{"url":"x","users":[{"login":"octocat"}],"teams":[{"slug":"maintainers"}],"apps":[{"slug":"review-bot"}]},"bypass_pull_request_allowances":{"users":[{"login":"octocat"}],"teams":[{"slug":"maintainers"}],"apps":[{"slug":"merge-bot"}]}},
  "restrictions":{"url":"x","users":[{"login":"octocat"}],"teams":[{"slug":"maintainers"}],"apps":[{"slug":"deploy-bot"}]},
  "required_signatures":{"url":"x","enabled":false},
  "required_linear_history":{"enabled":true},
  "allow_force_pushes":{"enabled":false},
  "allow_deletions":{"enabled":false},
  "block_creations":{"enabled":true},
  "required_conversation_resolution":{"enabled":true},
  "lock_branch":{"enabled":false},
  "allow_fork_syncing":{"enabled":false}
}'

PATH="$FAKE_GH_DIR:$PATH" /workspace/bin/gh-setup-repo octo/example > /dev/null 2>&1
exit_code=$?
encoded_path_count=$(grep -c 'branches/release%2F%E6%9D%B1%E4%BA%AC/protection' "$FAKE_GH_CALLS" || true)
preserved_policy=$(jq -c '[
    .required_status_checks.strict,
    .required_status_checks.contexts,
    .required_status_checks.checks,
    .enforce_admins,
    .required_pull_request_reviews.required_approving_review_count,
    .required_pull_request_reviews.require_code_owner_reviews,
    .required_pull_request_reviews.dismissal_restrictions.users,
    .required_pull_request_reviews.bypass_pull_request_allowances.apps,
    .restrictions.teams,
    .required_linear_history,
    .block_creations,
    .required_conversation_resolution
]' "$FAKE_GH_PAYLOAD")
assert_eq "既存保護を保持して更新: exit 0" "0" "$exit_code"
assert_eq "保護 API のブランチ名を URL エンコード" "2" "$encoded_path_count"
assert_eq "既存保護を保持して更新: policy" '[true,["unit"],[{"context":"unit","app_id":42}],true,2,true,["octocat"],["merge-bot"],["maintainers"],true,true,true]' "$preserved_policy"

: > "$FAKE_GH_CALLS"
: > "$FAKE_GH_PAYLOAD"
FAKE_GH_PROTECTION_MODE=error PATH="$FAKE_GH_DIR:$PATH" /workspace/bin/gh-setup-repo --check octo/example > /tmp/gh-setup-check.out 2>&1
exit_code=$?
reported_active=$(grep -c 'ブランチ保護: 有効' /tmp/gh-setup-check.out || true)
reported_error=$(grep -c '取得に失敗' /tmp/gh-setup-check.out || true)
assert_eq "保護設定取得失敗の --check: exit 1" "1" "$exit_code"
assert_eq "保護設定取得失敗の --check: 有効と誤表示しない" "0" "$reported_active"
assert_eq "保護設定取得失敗の --check: 取得失敗を表示" "1" "$reported_error"

: > "$FAKE_GH_CALLS"
FAKE_GH_PROTECTION_JSON='{"required_signatures":{"enabled":true}}'
PATH="$FAKE_GH_DIR:$PATH" /workspace/bin/gh-setup-repo octo/example > /dev/null 2>&1
exit_code=$?
write_count=$(grep -Ec -- '-X (PATCH|PUT)' "$FAKE_GH_CALLS" || true)
assert_eq "署名必須の既存保護: 更新を中止" "1" "$exit_code"
assert_eq "署名必須の既存保護: 書き込みなし" "0" "$write_count"

: > "$FAKE_GH_CALLS"
FAKE_GH_PROTECTION_JSON='{"unknown_policy":{"enabled":true}}'
PATH="$FAKE_GH_DIR:$PATH" /workspace/bin/gh-setup-repo octo/example > /dev/null 2>&1
exit_code=$?
write_count=$(grep -Ec -- '-X (PATCH|PUT)' "$FAKE_GH_CALLS" || true)
assert_eq "未知の既存保護: 更新を中止" "1" "$exit_code"
assert_eq "未知の既存保護: 書き込みなし" "0" "$write_count"

rm -rf "$FAKE_GH_DIR" "$FAKE_GH_CALLS" "$FAKE_GH_PAYLOAD" /tmp/gh-setup-check.out

echo ""
echo "=== 結果: ${PASS}/${TOTAL} passed, ${FAIL} failed ==="

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
