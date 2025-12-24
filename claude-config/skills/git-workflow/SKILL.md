---
name: git-workflow
description: gitを使用する際に使用。Conventional Commitsとブランチ命名をカバー。
---

# Git Workflow

## Conventional Commits

```
<type>(<scope>): <description>
```

| タイプ | 用途 | バージョン |
|--------|------|-----------|
| feat | 新機能 | MINOR |
| fix | バグ修正 | PATCH |
| docs | ドキュメント | - |
| refactor | リファクタリング | - |
| test | テスト | - |

### 例

```bash
feat(auth): add JWT refresh endpoint
fix(api): prevent race condition
feat!: change auth to OAuth 2.0  # ⚠️ 破壊的変更
```

## ブランチ命名

```
feat/user-authentication
fix/login-redirect
```

## コミット粒度

**1コミット = 1つの論理的変更**

## ロックファイル

⚠️ 必ずコミット: `package-lock.json`, `yarn.lock`, `poetry.lock`

## 🚫 禁止

```bash
# 共有ブランチでの --force は禁止
git push --force  # ❌
```
