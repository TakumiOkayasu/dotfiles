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

## 処理手順

1. **要件確認**: 実装対象の仕様・制約を確認する
2. **テスト作成**: `#[test]` で失敗するテストを先に書く (RED)
3. **実装**: テストが通る最小限のコードを書く (GREEN)
4. **リファクタリング**: コードスタイルを整え、不要な重複を除去する (REFACTOR)
5. **検証**: `cargo test` で全テストがパスすることを確認する
6. **静的解析**: `cargo clippy` で警告がないことを確認する

## 入出力

| 項目 | 内容 |
|------|------|
| 入力 | 実装要件・仕様（テキスト）、既存コード（ファイル） |
| 出力 | Rustソースコード、テストコード |
| 前提 | 相談・設計フェーズ完了済み、方針が確定していること |

## 使用例

```
# 新機能の実装を依頼する場合
「`src/parser.rs` に JSON パーサーを実装してください。
仕様: ...（確定済みの仕様）」

# バグ修正を依頼する場合
「`src/lib.rs` の `parse_input()` 関数でパニックが発生します。
再現手順: cargo test test_parse_edge_case -- --nocapture」
```
