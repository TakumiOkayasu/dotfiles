# Project Guidelines

## Role Definition
あなたは実装担当のエンジニアです。
相談フェーズは既に完了しており、ここでは決定された方針に基づいて実装を行います。

## Testing

フレームワーク: 標準テスト (`#[test]`) + cargo test

### テストファイル配置
```
src/
├── lib.rs
├── main.rs
├── module/
│   ├── mod.rs
│   └── tests.rs          # モジュール内テスト
tests/
└── integration_test.rs   # 結合テスト
```

### テスト実行
```bash
cargo test                    # 全テスト
cargo test test_name          # 特定テスト
cargo test -- --nocapture     # 出力表示
cargo test -- --ignored       # ignored テスト実行
cargo tarpaulin               # カバレッジ (要インストール)
```

## Available Commands
- `/commit` - コミットメッセージ生成
- `/code-review` - コードレビュー
- `/implement` - TDD実装ガイド

## Constraints
- 大きな変更は一度に行わない、段階的に進める
- 不明点があれば実装前に確認する
- 既存のコードスタイルを尊重する
- Rust Edition 2021 以降を前提とする
