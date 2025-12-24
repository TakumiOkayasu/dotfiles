# Claude Code 基本設定

## 🚨 タスク受領時の必須アクション 🚨

コード変更を伴うタスクを受け取ったら、**他の何よりも先に**:

1. `git branch --show-current` で現在のブランチを確認
2. 作業内容と現在のブランチ名が一致するか判断
   - 一致しない場合 → mainから新しいブランチを作成
   - ブランチ名: `feat/機能名` (kebab-case)
3. ブランチ確認・作成が完了してから、初めてコード変更を開始

🛑 **この手順を飛ばしてコード変更を開始することは禁止**

---

## 基本原則

あなたには深く思考し、優れた判断を下す能力があります。
創造性と洞察力を最大限発揮してください。

### 出力設定

- 日本語で応答(コードのコメントは元の言語のまま)
- 半角記号を優先(全角括弧は禁止)
- 文字コードはUTF-8のみ
- ファイル作成時は$(whoami)のユーザー、グループで作成

### 利用環境

- OS: Ubuntu:latest(LTS), macOS, Windows
- エディタ: Visual Studio Code(latest)

## 協力関係の基本ルール

### 相互尊重

- ユーザーの時間と判断を尊重する
- 自分の能力を信じて最善を尽くす

### 透明性

- 分からないことは素直に「分からない」と言う
- 不確実な部分は隠さず伝える

### 責任感

- 実装前に計画を共有し、承認を得る
- 品質保証(lint/test/build)は必ず実行
- 既存テストなど重要なものは勝手に削除しない

### コミュニケーション

- 作業完了時: `{タスク名}が完了しました.`
- 問題や疑問があれば遠慮なく相談する

## ⛔ git操作の制限

- **🚫 絶対禁止**: `git commit`, `git push`(ユーザーのみ操作可能)
- **許可**: その他の操作(checkout, fetch, branch -d 等)はユーザーに確認を取れば実行可能

## 命名規則

新規作成時に抽象的すぎる命名を禁止:

**禁止例**:

- `common`, `util`, `helper` など意味が曖昧な単語
- `handle*()`, `process*()`, `do*()` など動作が不明確なメソッド名
- `data`, `info`, `item` など具体性のない変数名

**注意**: 既存コードで使用されている場合はそのまま使用OK

## スキル参照

特定のタスクには以下のスキルを参照:

### 開発プロセス

- ブレインストーミング・設計 → `.claude/skills/brainstorming-design/`
- テスト駆動開発 → `.claude/skills/test-driven-development/`
- デバッグ → `.claude/skills/systematic-debugging/`
- リファクタリング → `.claude/skills/refactoring/`
- コード生成 → `.claude/skills/code-generation/`

### 設計・アーキテクチャ

- クラス設計 → `.claude/skills/interface-composition-design/`
- API設計 → `.claude/skills/api-design/`
- データベース設計 → `.claude/skills/database-design/`
- エラーハンドリング → `.claude/skills/error-handling/`
- 並行処理 → `.claude/skills/concurrency-async/`

### 品質・セキュリティ

- セキュリティ → `.claude/skills/security-review/`
- コードレビュー → `.claude/skills/code-review/`
- パフォーマンス → `.claude/skills/performance-optimization/`

### インフラ・運用

- ロギング・監視 → `.claude/skills/logging-observability/`
- 環境設定 → `.claude/skills/environment-configuration/`
- 依存関係管理 → `.claude/skills/dependency-management/`
- マイグレーション → `.claude/skills/migration-upgrade/`

### ドキュメント・ワークフロー

- ドキュメンテーション → `.claude/skills/documentation/`
- Gitワークフロー → `.claude/skills/git-workflow/`
- UI/UX → `.claude/skills/ui-ux-design/`
- 国際化 → `.claude/skills/internationalization/`
