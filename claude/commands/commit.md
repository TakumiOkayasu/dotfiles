# Commit Preparation

コミットメッセージを生成し、コミット準備を行う

## 実行手順

1. **変更内容の確認**
   ```bash
   git status
   git diff --staged
   ```

2. **コミットメッセージ生成**
   Conventional Commits形式で日本語メッセージを提案:
   ```
   <type>: <description>

   <body>(任意)
   ```

   type:
   - feat: 新機能
   - fix: バグ修正
   - docs: ドキュメント
   - style: フォーマット(動作に影響なし)
   - refactor: リファクタリング
   - test: テスト追加・修正
   - chore: ビルド・補助ツール

3. **確認事項**
   - [ ] テストは通っているか
   - [ ] 不要なファイルは含まれていないか
   - [ ] コミット粒度は適切か

4. **コミットコマンド提示**
   ```bash
   git commit -m "type: メッセージ"
   ```
