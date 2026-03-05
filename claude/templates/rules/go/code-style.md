# コードスタイル (Go)

## 命名規則

- 非公開 (unexported): `camelCase`
- 公開 (exported): `PascalCase`
- パッケージ名: `lowercase` (短く、単一単語)
- インターフェース: 動詞/動作を表す名前 (`Reader`, `Writer`)

## フォーマッタ

- `gofmt` / `goimports` を必ず適用

## Go固有の慣習

- エラーは必ずチェック (`_ = ` で無視しない)
- エラーラップは `fmt.Errorf("...: %w", err)` を使用
- パニックは極力避ける (ライブラリコードでは禁止)
- `context.Context` は関数の第1引数に渡す
- ゴルーチンのリーク防止: 必ず終了条件を設ける
