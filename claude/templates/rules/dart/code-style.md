# コードスタイル (Dart)

## 命名規則

- 変数・関数: `camelCase`
- クラス・enum・typedef: `PascalCase`
- 定数: `camelCase` (Dart 慣習、`lowerCamelCase`)
- ファイル名: `snake_case.dart`
- プライベート: `_prefix`

## フォーマッタ

- `dart format` を必ず適用
- `dart analyze` で静的解析

## Dart固有の慣習

- null safety を活用 (`?`, `!`, `late`)
- `final` をデフォルトで使用 (`var` は再代入が必要な場合のみ)
- `const` コンストラクタを可能な限り使用 (Flutter パフォーマンス)
- freezed パッケージで不変データクラスを生成
