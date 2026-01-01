---
name: ci-cd
description: CI/CDパイプラインやGitHub Actionsを設定する際に使用。
---

# CI/CD

## トリガー

- GitHub Actions設定時
- CI/CDパイプライン構築時
- 自動テスト・デプロイ設定時
- ブランチ保護ルール設定時

## 鉄則

**自動化できるものは自動化。手動デプロイは事故の元。**

## GitHub Actions基本

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      
      - run: npm ci          # ⚠️ installではなくci
      - run: npm run lint
      - run: npm run test
      - run: npm run build
```

## ⚠️ 必須ステップ

```yaml
# PRマージ前に必ず実行
- run: npm run lint      # 静的解析
- run: npm run typecheck # 型チェック
- run: npm run test      # テスト
- run: npm run build     # ビルド確認
```

## キャッシュ

```yaml
- uses: actions/cache@v4
  with:
    path: ~/.npm
    key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
```

## シークレット

```yaml
# 🚫 直接書かない
env:
  API_KEY: ${{ secrets.API_KEY }}
```

## ブランチ保護

```
⚠️ main ブランチ設定:
□ Require PR before merging
□ Require status checks to pass
□ Require up-to-date branches
```

## デプロイ

```yaml
deploy:
  needs: test  # テスト成功後のみ
  if: github.ref == 'refs/heads/main'
  runs-on: ubuntu-latest
  steps:
    - run: echo "Deploy to production"
```
