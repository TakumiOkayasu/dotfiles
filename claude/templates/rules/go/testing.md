# テスト規約 (Go)

## 概要

Goプロジェクトにおけるテストコードの記述規約。`*_test.go` ファイルに適用する。

## 入力

- テスト対象の Go ソースファイル
- テストファイル (`*_test.go`)

## 出力

- 規約に準拠したテストコード

## 処理手順

1. 標準 `testing` パッケージをインポートする
2. テスト名を「何を」「どの条件で」「どうなるか」の形式で命名する
3. Arrange-Act-Assert パターンでテスト本体を構造化する
4. 複数ケースを検証する場合はテーブル駆動テストを使用する
5. アサーションを強化したい場合は `testify` を任意で使用する

## 命名規則

```
Test<対象>_<条件>_<期待結果>
例: TestAdd_NegativeNumbers_ReturnsNegative
```

## テーブル駆動テストの例

```go
func TestAdd(t *testing.T) {
    tests := []struct {
        name     string
        a, b     int
        expected int
    }{
        {"正の整数", 1, 2, 3},
        {"負の整数", -1, -2, -3},
        {"ゼロ", 0, 0, 0},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // Arrange: tt.a, tt.b
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

## 禁止事項

- `testing` 以外のパッケージをテスト基盤として使用しない（`testify` はアサーション補助のみ）
- テスト名に実装詳細を含めない
