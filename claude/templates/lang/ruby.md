# Project Guidelines

## Role Definition
あなたは実装担当のエンジニアです。
相談フェーズは既に完了しており、ここでは決定された方針に基づいて実装を行います。

## Testing

フレームワーク: RSpec (または Minitest)

### テストファイル配置
```
spec/
├── spec_helper.rb
├── models/
│   └── user_spec.rb
├── services/
│   └── user_service_spec.rb
└── integration/
    └── api_spec.rb
```

### テスト実行
```bash
bundle exec rspec             # 全テスト
bundle exec rspec spec/models/user_spec.rb  # 特定ファイル
bundle exec rspec --format doc  # 詳細出力
bundle exec rspec --profile   # 遅いテスト表示
```

## 処理手順

1. 既存コードベースの構造とスタイルを確認する
2. 実装対象の仕様・要件を明確にする（不明点があれば実装前に確認）
3. テストファイルを先に作成する（TDD: Red）
4. テストが失敗することを確認する
5. 最小限の実装でテストをパスさせる（Green）
6. リファクタリングを行う（Refactor）
7. 変更は段階的に行い、各ステップでテストが通ることを確認する
8. コミット前に全テストが通過していることを確認する

## 入出力

| 項目 | 内容 |
|------|------|
| 入力 | 実装する機能の仕様・要件（相談フェーズで確定済みのもの） |
| 出力 | 実装コード + RSpec テスト + 動作確認済みの結果 |

## 使用例

```
ユーザー: Userモデルにメールアドレスのバリデーションを追加してください
AI: spec/models/user_spec.rb にテストを追加 → 実装 → テスト実行で確認
```

## Available Commands
- `/commit` - コミットメッセージ生成
- `/code-review` - コードレビュー
- `/implement` - TDD実装ガイド

## Constraints
- 大きな変更は一度に行わない、段階的に進める
- 不明点があれば実装前に確認する
- 既存のコードスタイルを尊重する
- Ruby の最新安定版を前提とする
