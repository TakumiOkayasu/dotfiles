# テスト規約 (PHP/CakePHP)

## 対象
- パス: `tests/**/*.php`
- フレームワーク: PHPUnit + CakePHP TestCase

## 手順

1. **テストクラス作成**
   - `App\Test\TestCase\` 配下に配置
   - クラス名: `{対象クラス名}Test` (例: `UserServiceTest`)
   - 継承: `Cake\TestSuite\TestCase`

2. **テストメソッド命名**
   - 形式: `test{何を}_{条件}_{期待結果}`
   - 例: `testCalculateTotal_WithDiscount_ReturnsDiscountedPrice`

3. **Arrange-Act-Assert パターンで実装**
   ```php
   public function testCreateUser_WithValidData_ReturnsUser(): void
   {
       // Arrange
       $data = ['name' => 'Alice', 'email' => 'alice@example.com'];

       // Act
       $result = $this->UserService->create($data);

       // Assert
       $this->assertNotEmpty($result->id);
       $this->assertEquals('Alice', $result->name);
   }
   ```

4. **モック使用基準**
   - 外部API・メール送信など副作用のある処理のみ
   - DB操作は原則フィクスチャを使用

5. **フィクスチャ定義**
   - `$fixtures` プロパティに列挙
   - 例: `protected array $fixtures = ['app.Users'];`

## 入力
- テスト対象: `src/**/*.php` 内のクラス・メソッド
- フィクスチャ: `tests/Fixture/` 配下

## 出力
- テストファイル: `tests/TestCase/{対象パス}/{クラス名}Test.php`
- 実行結果: PHPUnit レポート (pass/fail/coverage)

## 禁止事項
- テスト間の依存 (順序依存の禁止)
- `setUp()` での過剰なモック登録
- アサートなしのテストメソッド
