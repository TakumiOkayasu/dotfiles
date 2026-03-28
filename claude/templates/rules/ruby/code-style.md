# コードスタイル (Ruby)

## 概要

Rubyコードのスタイル規約とフォーマットルール。コードレビューや新規実装時に参照する。

## 入力

- レビュー対象のRubyコード、または新規実装の要件

## 処理手順

1. 命名規則に従い識別子を命名する
2. ブロック記法をルールに従い選択する
3. ファイル先頭に `# frozen_string_literal: true` を追加する
4. RuboCop を実行してリンティング・整形を行う
5. 指摘箇所を修正し、再度RuboCopがパスすることを確認する

## 命名規則

| 種別 | 規則 | 例 |
|------|------|----|
| 変数・メソッド | `snake_case` | `user_name`, `find_user` |
| クラス・モジュール | `PascalCase` | `UserAccount`, `HttpClient` |
| 定数 | `UPPER_SNAKE_CASE` | `MAX_RETRY_COUNT` |
| 述語メソッド | `?` サフィックス | `empty?`, `valid?` |
| 破壊的メソッド | `!` サフィックス | `sort!`, `delete!` |

## フォーマッタ

- RuboCop でリンティング・整形

```bash
# リンティング実行
rubocop path/to/file.rb

# 自動修正
rubocop -a path/to/file.rb
```

## Ruby固有の慣習

| ルール | 内容 |
|--------|------|
| ブロック記法 | 1行: `{ }` / 複数行: `do...end` |
| frozen_string_literal | ファイル先頭で有効化 |
| ハッシュキー | `Symbol` を使用 |

```ruby
# frozen_string_literal: true

# ブロック記法の例
[1, 2, 3].map { |n| n * 2 }

[1, 2, 3].each do |n|
  puts n
end

# ハッシュキー
options = { name: "Alice", age: 30 }
```

## 出力

- RuboCopの警告・エラーがゼロのRubyコード
- 規約に準拠した命名・フォーマットのソースファイル
