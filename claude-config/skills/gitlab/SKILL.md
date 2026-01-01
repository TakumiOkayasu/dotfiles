---
name: gitlab-mr-review-operation
description: GitLab Merge Requestのレビュー操作を行うスキル。MR情報取得、差分確認、コメント取得・投稿、インラインコメント、コメント返信をglabコマンドで実行する。MRレビュー、コードレビュー、MR操作が必要な時に使用。
---

# GitLab MR Review Operation

## トリガー

- GitLab MRレビュー時
- MRへのコメント投稿時
- インラインコメント時
- MR情報取得時

GitLab CLI (`glab`) を使ったMRレビュー操作。

## 前提条件

- `glab` インストール済み
- `glab auth login` で認証済み

## MR URLのパース

MR URL `https://gitlab.com/OWNER/REPO/-/merge_requests/NUMBER` から以下を抽出して使用:
- `OWNER`: リポジトリオーナー(グループ)
- `REPO`: リポジトリ名
- `NUMBER`: MR番号

## 操作一覧

### 1. MR情報取得

```bash
glab mr view NUMBER --repo OWNER/REPO
```

JSON形式で詳細取得:
```bash
glab api projects/OWNER%2FREPO/merge_requests/NUMBER
```

### 2. 差分取得（行番号付き）

```bash
glab mr diff NUMBER --repo OWNER/REPO | awk '
/^@@/ {
  match($0, /-([0-9]+)/, old)
  match($0, /\+([0-9]+)/, new)
  old_line = old[1]
  new_line = new[1]
  print $0
  next
}
/^-/ { printf "L%-4d     | %s\n", old_line++, $0; next }
/^\+/ { printf "     R%-4d| %s\n", new_line++, $0; next }
/^ / { printf "L%-4d R%-4d| %s\n", old_line++, new_line++, $0; next }
{ print }
'
```

出力例:
```
@@ -46,15 +46,25 @@ jobs:
L46   R46  |            prompt: |
L49       | -            (削除行)
     R49  | +            (追加行)
L50   R50  |              # レビューガイドライン
```

- `L数字`: OLD(base)側の行番号 → インラインコメントで`old_line`に使用
- `R数字`: NEW(head)側の行番号 → インラインコメントで`new_line`に使用

### 3. コメント取得

MR全体のノート(コメント):
```bash
glab api projects/OWNER%2FREPO/merge_requests/NUMBER/notes --jq '.[] | {id, author: .author.username, created_at, body}'
```

### 4. MRにコメント

```bash
glab mr comment NUMBER --repo OWNER/REPO --message "コメント内容"
```

または API経由:
```bash
glab api projects/OWNER%2FREPO/merge_requests/NUMBER/notes \
  --method POST \
  -f body="コメント内容"
```

### 5. インラインコメント（コード行指定）

まずMRの差分情報を取得してdiff refを確認:
```bash
glab api projects/OWNER%2FREPO/merge_requests/NUMBER/versions
```

最新のdiff refs:
```bash
glab api projects/OWNER%2FREPO/merge_requests/NUMBER/versions --jq '.[0] | {head_commit_sha, base_commit_sha, start_commit_sha}'
```

単一行コメント:
```bash
glab api projects/OWNER%2FREPO/merge_requests/NUMBER/discussions \
  --method POST \
  -f body="コメント内容" \
  -f "position[position_type]=text" \
  -f "position[base_sha]=BASE_COMMIT_SHA" \
  -f "position[head_sha]=HEAD_COMMIT_SHA" \
  -f "position[start_sha]=START_COMMIT_SHA" \
  -f "position[new_path]=src/example.py" \
  -f "position[old_path]=src/example.py" \
  -f "position[new_line]=15"
```

削除行へのコメント(`old_line`を使用):
```bash
glab api projects/OWNER%2FREPO/merge_requests/NUMBER/discussions \
  --method POST \
  -f body="コメント内容" \
  -f "position[position_type]=text" \
  -f "position[base_sha]=BASE_COMMIT_SHA" \
  -f "position[head_sha]=HEAD_COMMIT_SHA" \
  -f "position[start_sha]=START_COMMIT_SHA" \
  -f "position[new_path]=src/example.py" \
  -f "position[old_path]=src/example.py" \
  -f "position[old_line]=15"
```

**注意点:**
- `new_line`: 追加行(diff の `+` 行)に使用
- `old_line`: 削除行(diff の `-` 行)に使用
- 変更なし行には`new_line`と`old_line`両方指定可能
- `OWNER%2FREPO`: URLエンコードされたプロジェクトパス(`/`を`%2F`に置換)

### 6. ディスカッションへ返信

```bash
glab api projects/OWNER%2FREPO/merge_requests/NUMBER/discussions/DISCUSSION_ID/notes \
  --method POST \
  -f body="返信内容"
```

`DISCUSSION_ID`はディスカッション取得で得た`id`を使用。

ディスカッション一覧取得:
```bash
glab api projects/OWNER%2FREPO/merge_requests/NUMBER/discussions --jq '.[] | {id, notes: [.notes[] | {id, author: .author.username, body}]}'
```
