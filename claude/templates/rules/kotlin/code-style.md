# コードスタイル (Kotlin)

## 命名規則

- 変数・関数: `camelCase`
- クラス・インターフェース: `PascalCase`
- 定数: `UPPER_SNAKE_CASE`
- パッケージ: `lowercase` (ドット区切り)

## フォーマッタ

- ktlint または detekt を使用

## Kotlin固有の慣習

- `data class` を値オブジェクトに活用
- `null` 安全: `!!` は原則禁止 (`?.`, `?:`, `let` を使用)
- スコープ関数 (`let`, `run`, `apply`, `also`, `with`) を適切に使い分ける
- 拡張関数を活用 (ただし乱用しない)
