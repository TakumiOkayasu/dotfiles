# テスト規約 (Java)

## 入力

- Javaテストファイル（`src/test/**/*`, `**/*Test.java`, `**/*Tests.java`）

## 出力

- JUnit 5準拠のテストコード

## 処理手順

1. テストフレームワークの確認: JUnit 5を使用する
2. テスト構造の適用: Arrange-Act-Assert（AAA）パターンで記述する
3. テスト名の命名: 「何を」「どの条件で」「どうなるか」の形式で命名する
4. モックの適用: Mockitoを使用し、必要最小限のモックのみ作成する
5. テストのグルーピング: `@Nested`クラスで関連テストをまとめる

## 規約詳細

| 項目 | 規約 |
|------|------|
| フレームワーク | JUnit 5 |
| パターン | Arrange-Act-Assert |
| モックライブラリ | Mockito |
| テスト名形式 | `メソッド名_条件_期待結果` |
| グルーピング | `@Nested` アノテーション使用 |

## 使用例

```java
@Nested
class 注文処理 {
    @Test
    void 注文確定_在庫がある場合_注文が成功する() {
        // Arrange
        var stock = mock(StockService.class);
        when(stock.hasStock("item-1")).thenReturn(true);
        var service = new OrderService(stock);

        // Act
        var result = service.confirm("item-1");

        // Assert
        assertThat(result.isSuccess()).isTrue();
    }
}
```
