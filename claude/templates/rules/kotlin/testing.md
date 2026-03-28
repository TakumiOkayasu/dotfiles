# テスト規約 (Kotlin)

## 対象ファイル

- `src/test/**/*`
- `**/*Test.kt`
- `**/*Tests.kt`

## 使用ライブラリ

| ライブラリ | 用途 |
|-----------|------|
| JUnit 5 | テストフレームワーク |
| MockK | モック生成 |

## テスト作成手順

1. **テストクラスを作成する**
   - ファイル名は `対象クラス名Test.kt` とする
2. **テスト名を命名する**
   - 形式: 「何を」「どの条件で」「どうなるか」
   - バッククォートで日本語名を使用可
3. **Arrange-Act-Assert パターンで実装する**
   - `// Arrange` — 前提条件のセットアップ
   - `// Act` — テスト対象の実行
   - `// Assert` — 結果の検証
4. **関連テストを `@Nested` でグルーピングする**

## 入力

- テスト対象のクラス・関数

## 出力

- JUnit 5 形式のテストクラス (`.kt`)

## 使用例

```kotlin
class UserRepositoryTest {

    @Nested
    inner class `findById` {

        @Test
        fun `ユーザーが存在する場合にユーザーを返す`() {
            // Arrange
            val repo = mockk<UserRepository>()
            every { repo.findById(1L) } returns User(id = 1L, name = "Alice")

            // Act
            val result = repo.findById(1L)

            // Assert
            assertNotNull(result)
            assertEquals("Alice", result.name)
        }

        @Test
        fun `ユーザーが存在しない場合にnullを返す`() {
            // Arrange
            val repo = mockk<UserRepository>()
            every { repo.findById(99L) } returns null

            // Act
            val result = repo.findById(99L)

            // Assert
            assertNull(result)
        }
    }
}
```
