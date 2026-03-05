# コードスタイル (Java)

## 命名規則

- 変数・メソッド: `camelCase`
- クラス・インターフェース: `PascalCase`
- 定数: `UPPER_SNAKE_CASE`
- パッケージ: `lowercase` (ドット区切り)

## フォーマッタ

- Google Java Format または Spotless を使用
- Checkstyle でスタイルチェック

## Java固有の慣習

- `Optional` を戻り値に使用 (フィールドや引数には使わない)
- Stream API を活用 (ただし可読性を損なわない範囲で)
- record クラスを不変データに活用 (Java 16+)
