# コードスタイル (C#)

## 命名規則

- 変数・パラメータ: `camelCase`
- メソッド・プロパティ・クラス: `PascalCase`
- 定数: `PascalCase` (C# 慣習)
- プライベートフィールド: `_camelCase`
- インターフェース: `IPascalCase` (I プレフィックス)

## フォーマッタ

- dotnet format を使用
- .editorconfig で統一

## C#固有の慣習

- nullable 参照型を有効化 (`<Nullable>enable</Nullable>`)
- `async/await` パターンを正しく使用 (async void は禁止)
- パターンマッチングを活用 (`is`, `switch` 式)
- record 型を不変データに活用
