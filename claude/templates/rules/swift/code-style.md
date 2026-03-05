# コードスタイル (Swift)

## 命名規則

- 変数・関数: `camelCase`
- 型・プロトコル: `PascalCase`
- 定数: `camelCase` (Swift 慣習)
- 列挙値: `camelCase`

## フォーマッタ

- SwiftFormat または swift-format を使用
- SwiftLint でリンティング

## Swift固有の慣習

- `guard` で早期リターン
- `!` (force unwrap) は原則禁止 (`if let`, `guard let` を使用)
- `struct` をデフォルトとし、`class` は参照セマンティクスが必要な場合のみ
- Protocol-Oriented Programming を活用
