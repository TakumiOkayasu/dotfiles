# コードスタイル (Go)

## 目的

Goコードを書く際のスタイル規則を適用し、一貫性・可読性・安全性を確保する。

## 入力

- レビュー対象のGoソースコード（ファイルパスまたはコードスニペット）

## 出力

- スタイル規則に準拠した修正済みコード
- 修正箇所の一覧（修正前→修正後）

## 処理手順

1. **命名規則を確認・修正する**
   - 非公開シンボル → `camelCase`（例: `myVar`, `parseInput`）
   - 公開シンボル → `PascalCase`（例: `MyStruct`, `ParseInput`）
   - パッケージ名 → `lowercase` 単一単語（例: `parser`, `http`）
   - インターフェース名 → 動詞/動作を表す名前（例: `Reader`, `Writer`, `Stringer`）

2. **フォーマットを適用する**
   - `gofmt` を適用してインデント・空白・括弧を統一する
   - `goimports` を適用してimport文を整理する（未使用削除・グループ分け）

3. **エラーハンドリングを確認する**
   - `_ = someFunc()` でエラーを無視している箇所を検出し、適切に処理する
   - エラーをラップする場合は `fmt.Errorf("操作名: %w", err)` 形式を使用する
   - `errors.Is` / `errors.As` で判定できるようにラップを維持する

4. **パニック使用を確認する**
   - ライブラリコード内の `panic()` を検出し、`error` 返却に変更する
   - アプリケーションコードでも極力 `panic` を避け、エラー伝播に統一する

5. **`context.Context` の引数位置を確認する**
   - `context.Context` を受け取る関数は、必ず第1引数に配置する
   - 例: `func DoSomething(ctx context.Context, id string) error`

6. **ゴルーチンの終了条件を確認する**
   - `go func()` を起動している箇所で終了条件（`ctx.Done()`, `chan`, `WaitGroup` 等）が存在するか確認する
   - 終了条件がない場合はリーク警告としてコメントを追加し、修正案を提示する

## 使用例

```
以下のGoコードにコードスタイルを適用してください：

func process_data(CTX context.Context, Input string) error {
    result, _ := doWork(Input)
    return nil
}
```

→ 修正後:
```go
func processData(ctx context.Context, input string) error {
    result, err := doWork(input)
    if err != nil {
        return fmt.Errorf("processData: %w", err)
    }
    _ = result // [要確認] resultを使用していない
    return nil
}
```

## 注意事項

- 既存のロジックは変更しない（スタイルのみ修正）
- 意図が不明な箇所は修正せず `[要確認]` コメントを付与する
- `gofmt`/`goimports` はツール実行を推奨（手動修正は最終手段）
