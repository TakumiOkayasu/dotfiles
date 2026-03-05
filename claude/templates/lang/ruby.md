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

## Available Commands
- `/commit` - コミットメッセージ生成
- `/code-review` - コードレビュー
- `/implement` - TDD実装ガイド

## Constraints
- 大きな変更は一度に行わない、段階的に進める
- 不明点があれば実装前に確認する
- 既存のコードスタイルを尊重する
- Ruby の最新安定版を前提とする
