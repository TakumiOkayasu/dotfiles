# テスト規約 (Swift)

## トリガー条件

以下のファイルを編集・レビュー・生成するとき:

- `Tests/**/*`
- `**/*Tests.swift`

## 手順

1. テストフレームワークを確認する（XCTest または Swift Testing）
2. Arrange-Act-Assert パターンで構造化する
   - **Arrange**: テスト対象・依存・入力値を準備する
   - **Act**: テスト対象メソッドを1回だけ呼び出す
   - **Assert**: 期待値と実際値を比較する
3. テスト名を「何を_どの条件で_どうなるか」形式で命名する
4. 外部依存はプロトコル準拠のモックに差し替える
5. 非同期処理は `async/await` で記述する

## 入力

- テスト対象のSwiftソースファイル
- 仕様・要件（あれば）

## 出力

- `*Tests.swift` または `*Test.swift` ファイル
- フレームワーク別インポート (`import XCTest` / `import Testing`)
- `@testable import <ModuleName>` による内部アクセス

## 使用例

### XCTest

```swift
import XCTest
@testable import MyApp

final class UserValidatorTests: XCTestCase {
    // Arrange
    func test_validate_emptyName_throwsInvalidNameError() throws {
        let sut = UserValidator()
        // Act & Assert
        XCTAssertThrowsError(try sut.validate(name: "")) { error in
            XCTAssertEqual(error as? ValidationError, .invalidName)
        }
    }
}
```

### Swift Testing

```swift
import Testing
@testable import MyApp

@Suite("UserValidator")
struct UserValidatorTests {
    @Test("空の名前は invalidName エラーを投げる")
    func validate_emptyName_throwsInvalidNameError() throws {
        let sut = UserValidator()
        #expect(throws: ValidationError.invalidName) {
            try sut.validate(name: "")
        }
    }
}
```

### 非同期テスト

```swift
@Test("APIから正常にデータ取得できる")
func fetchUser_validId_returnsUser() async throws {
    let sut = UserRepository(client: MockAPIClient())
    let user = try await sut.fetchUser(id: "123")
    #expect(user.id == "123")
}
```

## 禁止事項

- `sleep()` / `Thread.sleep()` による待機（`async/await` を使うこと）
- テスト間で状態を共有するグローバル変数
- 具象クラスへの直接依存（プロトコルモックに置き換えること）
