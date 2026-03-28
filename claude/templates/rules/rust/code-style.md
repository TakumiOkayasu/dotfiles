# コードスタイル (Rust)

## 命名規則

- 変数・関数: `snake_case`
- 型・トレイト: `PascalCase`
- 定数・静的変数: `UPPER_SNAKE_CASE`
- モジュール: `snake_case`

## フォーマッタ

- `rustfmt` を必ず適用
- `clippy` で静的解析

## Rust固有の慣習

- `unwrap()` は本番コードで使わない (`?` 演算子を使用)
- `clone()` を安易に使わない (所有権・借用を活用)
- `derive` マクロを活用 (`Debug`, `Clone`, `PartialEq` 等)

## 処理手順

1. 新規コード記述時は上記命名規則に従う
2. `rustfmt` を実行してフォーマットを統一する
3. `cargo clippy` を実行して警告を解消する
4. `unwrap()` が残っていないか確認し、`?` 演算子または適切なエラーハンドリングに置き換える
5. 不必要な `clone()` がないか確認し、所有権・借用で解決できる場合は修正する

## 入出力

- **入力**: レビュー対象のRustソースファイル
- **出力**: 命名規則・フォーマット・Rust慣習に準拠したRustソースファイル

## 使用例

```bash
# フォーマット適用
cargo fmt

# 静的解析
cargo clippy -- -D warnings
```
