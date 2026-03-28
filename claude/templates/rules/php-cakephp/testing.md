# テスト規約 (PHP/CakePHP)

## 適用条件

`tests/**/*.php` に該当するファイルを編集・レビューする際に適用する。

## 処理手順

1. テストフレームワークを確認する
   - PHPUnit + CakePHP TestCase (`Cake\TestSuite\TestCase`) を使用する
   - `use Cake\TestSuite\TestCase;` が宣言されていることを確認する

2. テスト構造を Arrange-Act-Assert パターンで記述する
   - **Arrange**: テスト対象のオブジェクト・データを準備する
   - **Act**: テスト対象のメソッドを実行する
   - **Assert**: 期待する結果を検証する

3. テストメソッド名を命名規則に従い記述する
   - 形式: `test{何を}_{どの条件で}_{どうなるか}`
   - 例: `testSave_withValidData_returnsTrueAndPersistsRecord`

4. モックを最小限に抑える
   - モックは外部依存（DB・メール・HTTP）のみに使用する
   - ビジネスロジック自体はモックしない

## 入出力

| 項目 | 内容 |
|------|------|
| 入力 | `tests/**/*.php` 内のテストクラス・メソッド |
| 出力 | 上記規約に準拠したテストコード |

## 使用例

```php
class UserServiceTest extends TestCase
{
    // Arrange
    public function testSave_withValidData_returnsTrueAndPersistsRecord(): void
    {
        $data = ['username' => 'taro', 'email' => 'taro@example.com'];

        // Act
        $result = $this->UserService->save($data);

        // Assert
        $this->assertTrue($result);
        $this->assertCount(1, $this->Users->find()->where(['username' => 'taro']));
    }
}
```
