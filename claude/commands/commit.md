# コミット準備

コミットメッセージを生成し、コミット準備を行う

## 入力

- ステージング済みの変更（`git add` 済み）

## 出力

- Conventional Commits形式のコミットメッセージ案
- 実行可能な `git commit` コマンド

## 実行手順

### 1. 変更内容の確認

```bash
git status && git diff --staged
```

### 2. コミットメッセージ生成

Conventional Commits形式で日本語メッセージを提案:

```text
<type>: <description>

<body>(任意)
```

| type | 用途 |
|------|------|
| feat | 新機能 |
| fix | バグ修正 |
| docs | ドキュメント |
| style | フォーマット（動作に影響なし） |
| refactor | リファクタリング |
| test | テスト追加・修正 |
| chore | ビルド・補助ツール |

### 3. 確認事項

- [ ] テストは通っているか
- [ ] 不要なファイルは含まれていないか
- [ ] コミット粒度は適切か（1コミット = 1つの論理的変更）

### 4. コミットコマンド提示

```bash
git commit -m "type: メッセージ"
```

## 使用例

```bash
# 新機能追加の場合
git commit -m "feat: ユーザー認証機能を追加"

# バグ修正の場合
git commit -m "fix: ログイン時のNullPointerExceptionを修正"

# 本文あり
git commit -m "refactor: 認証ロジックをAuthServiceに抽出

責務の分離のため、UserControllerから認証処理を移動"
```

## 注意事項

- `git commit` の実行はユーザーが行う（AIは実行しない）
- mainブランチへの直接コミットは禁止
