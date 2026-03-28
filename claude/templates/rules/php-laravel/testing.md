# テスト規約 (PHP/Laravel)

## 対象

- `tests/**/*.php`

## 使用フレームワーク

- PHPUnit + Laravel TestCase

## テスト種別

| 種別 | 配置場所 | 用途 |
|------|----------|------|
| Feature Tests | `tests/Feature/` | HTTPリクエスト・DB操作を含む結合テスト |
| Unit Tests | `tests/Unit/` | 単一クラス・メソッドの単体テスト |

## 手順

1. **テスト種別を判断**: HTTPリクエスト・DB操作が含まれる → Feature、単一ロジック → Unit
2. **テストクラスを作成**: Feature は `extends TestCase`（`Illuminate\Foundation\Testing\TestCase`）、Unit は `extends TestCase`（`PHPUnit\Framework\TestCase`）
3. **テスト名を命名**: `test_対象_条件_期待結果` 形式（例: `test_user_when_not_authenticated_redirects_to_login`）
4. **Arrange-Act-Assert パターンで実装**:
   ```php
   // Arrange: 前提条件を準備
   $user = User::factory()->create();
   // Act: テスト対象を実行
   $response = $this->actingAs($user)->get('/dashboard');
   // Assert: 結果を検証
   $response->assertStatus(200);
   ```
5. **モックは最小限に**: 外部API・メール送信など副作用がある箇所のみ使用

## 入力

- テスト対象のクラス・メソッド・エンドポイント

## 出力

- `tests/Feature/` または `tests/Unit/` 配下の `*Test.php` ファイル

## 使用例

```php
// Feature Test の例
class UserProfileTest extends TestCase
{
    use RefreshDatabase;

    public function test_profile_page_when_authenticated_returns_200(): void
    {
        // Arrange
        $user = User::factory()->create();

        // Act
        $response = $this->actingAs($user)->get('/profile');

        // Assert
        $response->assertStatus(200);
        $response->assertSee($user->name);
    }
}
```
