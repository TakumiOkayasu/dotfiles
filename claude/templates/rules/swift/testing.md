# テスト規約 (Swift)

## 適用条件

このコマンドは以下のファイルが対象のとき自動適用される:

- `Tests/**/*`
- `**/*Tests.swift`

## 処理手順

1. テストフレームワークを確認する（XCTest または Swift Testing）
2. テストクラス・関数の命名を確認する
3. テスト構造が Arrange-Act-Assert パターンに従っているか確認する
4. モック実装がプロトコル準拠になっているか確認する
5. 非同期処理のテストが `async/await` を使用しているか確認する
6. 問題があれば修正案を提示する

## 規約

### フレームワーク

- XCTest または Swift Testing を使用する
- プロジェクト内で統一する

### 命名規則

テスト名は以下の3要素を含める:

| 要素 | 説明 | 例 |
|------|------|----|
| 何を | テスト対象 | `login` |
| どの条件で | 前提条件 | `WithInvalidPassword` |
| どうなるか | 期待結果 | `ThrowsAuthError` |

例: `testLogin_WithInvalidPassword_ThrowsAuthError()`

### テスト構造

```swift
func testCalculateTotal_WithTaxRate_ReturnsCorrectAmount() {
    // Arrange
    let cart = ShoppingCart()
    cart.add(item: Item(price: 1000))
    
    // Act
    let total = cart.calculateTotal(taxRate: 0.1)
    
    // Assert
    XCTAssertEqual(total, 1100)
}
```

### モック

- プロトコル準拠で作成する（クラス継承は禁止）

```swift
protocol UserRepository {
    func fetchUser(id: String) async throws -> User
}

final class MockUserRepository: UserRepository {
    var fetchUserResult: Result<User, Error> = .success(.mock)
    
    func fetchUser(id: String) async throws -> User {
        try fetchUserResult.get()
    }
}
```

### 非同期テスト

- `async/await` を使用する（`expectation` は禁止）

```swift
func testFetchUser_WithValidId_ReturnsUser() async throws {
    // Arrange
    let repository = MockUserRepository()
    let sut = UserService(repository: repository)
    
    // Act
    let user = try await sut.fetchUser(id: "123")
    
    // Assert
    XCTAssertEqual(user.id, "123")
}
```

## 入力

- 対象の Swift テストファイル

## 出力

- 規約に準拠したテストコード
- 修正が必要な箇所は差分形式で提示する
