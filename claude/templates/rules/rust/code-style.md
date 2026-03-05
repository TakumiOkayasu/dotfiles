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
