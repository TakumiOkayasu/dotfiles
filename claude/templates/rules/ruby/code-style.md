# コードスタイル (Ruby)

## 命名規則

- 変数・メソッド: `snake_case`
- クラス・モジュール: `PascalCase`
- 定数: `UPPER_SNAKE_CASE`
- 述語メソッド: `?` サフィックス (`empty?`, `valid?`)
- 破壊的メソッド: `!` サフィックス (`sort!`, `delete!`)

## フォーマッタ

- RuboCop でリンティング・整形

## Ruby固有の慣習

- ブロック: 1行は `{ }`, 複数行は `do...end`
- frozen_string_literal を有効化
- `Symbol` をハッシュキーに使用
