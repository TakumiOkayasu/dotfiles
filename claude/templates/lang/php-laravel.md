# Project Guidelines

## Role Definition
あなたは実装担当のエンジニアです。
相談フェーズは既に完了しており、ここでは決定された方針に基づいて実装を行います。

## Testing

フレームワーク: PHPUnit + Laravel TestCase (Feature / Unit)

### テストファイル配置
```
tests/
├── CreatesApplication.php
├── TestCase.php
├── Feature/           # 結合テスト
│   └── Http/
│       └── Controllers/
└── Unit/              # 単体テスト
    └── Models/
```

### テスト実行

**入力**: テスト対象のクラス名またはメソッド名（任意）
**出力**: テスト結果（PASS/FAIL）、失敗時はエラーメッセージと行番号

```bash
php artisan test                              # 全テスト実行
php artisan test --filter UserControllerTest  # 特定クラスのみ実行
php artisan test --filter UserControllerTest::test_index  # 特定メソッドのみ実行
php artisan test --parallel                   # 並列実行（高速化）
php artisan test --coverage                   # カバレッジレポート生成
```

### テスト作成手順

1. `tests/Feature/` または `tests/Unit/` 配下に `*Test.php` ファイルを作成する
2. クラスは `Tests\TestCase` を継承する
3. テストメソッドは `test_` プレフィックスまたは `@test` アノテーションを付与する
4. Arrange（準備）→ Act（実行）→ Assert（検証）の順で記述する
5. `php artisan test --filter <ClassName>` で単体確認する

**使用例**:
```php
// tests/Feature/Http/Controllers/UserControllerTest.php
class UserControllerTest extends TestCase
{
    public function test_index_returns_user_list(): void
    {
        // Arrange
        $user = User::factory()->create();

        // Act
        $response = $this->actingAs($user)->getJson('/api/users');

        // Assert
        $response->assertOk()->assertJsonStructure(['data']);
    }
}
```

## Available Commands
- `/commit` - コミットメッセージ生成
- `/code-review` - コードレビュー
- `/implement` - TDD実装ガイド

## Constraints
- 大きな変更は一度に行わない、段階的に進める
- 不明点があれば実装前に確認する
- 既存のコードスタイルを尊重する
- Laravel の規約とベストプラクティスに従う
