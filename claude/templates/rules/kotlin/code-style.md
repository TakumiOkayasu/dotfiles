# テスト規約 (Kotlin)

---
paths:
  - "src/test/**/*"
  - "**/*Test.kt"
  - "**/*Tests.kt"
---

## 目的

Kotlinプロジェクトにおけるテストコードの品質・一貫性を保つための規約を定める。

## 使用ライブラリ

| ライブラリ | 用途 |
|-----------|------|
| JUnit 5 | テストフレームワーク |
| MockK | モック生成 |

## テスト構造

### パターン: Arrange-Act-Assert (AAA)

```kotlin
@Test
fun `ユーザーが存在しない場合にnullを返す`() {
    // Arrange
    val repository = mockk<UserRepository>()
    every { repository.findById(99) } returns null

    // Act
    val result = UserService(repository).getUser(99)

    // Assert
    assertNull(result)
}
```

### グルーピング: `@Nested`

```kotlin
@Nested
inner class `getUser` {
    @Test
    fun `存在するIDを渡した場合にユーザーを返す`() { ... }

    @Test
    fun `存在しないIDを渡した場合にnullを返す`() { ... }
}
```

## 命名規則

### テストクラス名

- 対象クラス名 + `Test` (例: `UserServiceTest`)

### テスト関数名

- バッククォートで日本語記述
- 形式: 「**何を**」「**どの条件で**」「**どうなるか**」

| ❌ 避ける | ✅ 推奨 |
|----------|--------|
| `` `テスト1` `` | `` `パスワードが8文字未満の場合にバリデーションエラーを返す` `` |
| `` `正常系` `` | `` `有効なメールアドレスを渡した場合にtrueを返す` `` |

## 入力・出力

| 項目 | 内容 |
|------|------|
| 入力 | `src/test/**/*`, `**/*Test.kt`, `**/*Tests.kt` に該当するKotlinテストファイル |
| 出力 | 本規約に準拠したテストコード |

## 手順

1. テスト対象クラス・メソッドを特定する
2. `@Nested` で対象メソッドごとにグループを作成する
3. 各テストケースをAAA形式で実装する
4. テスト関数名を「何を/条件/結果」の形式で日本語命名する
5. MockKで外部依存をモック化する
