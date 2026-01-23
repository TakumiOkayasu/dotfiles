# ブランチ作成

新しい作業用ブランチを作成する。

## トリガー

- `/branch-start`
- 「pushの準備」
- 「ブランチ作成」

## 手順

1. ブランチ名をユーザーに確認
2. 以下を実行:

```bash
git-new-feature <ブランチ名>
```

## オプション

| フラグ | 用途 | 例 |
|--------|------|-----|
| (なし) | feat/ | `git-new-feature add-auth` |
| -f | fix/ | `git-new-feature -f login-bug` |
| -d | docs/ | `git-new-feature -d readme` |
| -r | refactor/ | `git-new-feature -r utils` |
| -c | chore/ | `git-new-feature -c deps` |

## 出力

```
✅ ブランチ作成: feat/<名前>
```
