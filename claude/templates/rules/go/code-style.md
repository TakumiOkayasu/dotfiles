# テスト規約 (Go)

## 概要

Goプロジェクトのテストコードに対して適用するコーディング規約。

## 入力

- 対象: `**/*_test.go` にマッチするファイル

## 処理手順

1. 標準 `testing` パッケージを使用する（サードパーティテストフレームワーク不可）
2. Arrange-Act-Assert パターンでテストを構造化する
   - **Arrange**: テスト前提条件・入力値のセットアップ
   - **Act**: テスト対象の関数・メソッドを呼び出す
   - **Assert**: 期待値と実際の値を比較する
3. テスト名は `Test<対象><条件><期待結果>` の形式で命名する
   - 例: `TestParseURL_EmptyString_ReturnsError`
4. 複数ケースはテーブル駆動テスト（`[]struct{ ... }` のスライス）で記述する
5. アサーション強化が必要な場合は `testify` を任意で使用する

## 出力

- 上記規約に準拠したテストコード

## 使用例

```go
func TestAdd_PositiveNumbers_ReturnsSum(t *testing.T) {
    tests := []struct {
        name     string
        a, b     int
        expected int
    }{
        {"両方正数", 1, 2, 3},
        {"ゼロを含む", 0, 5, 5},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // Arrange
            // (tt.a, tt.b は上記で定義済み)

            // Act
            got := Add(tt.a, tt.b)

            // Assert
            if got != tt.expected {
                t.Errorf("Add(%d, %d) = %d, want %d", tt.a, tt.b, got, tt.expected)
            }
        })
    }
}
```
