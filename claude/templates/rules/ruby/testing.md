# テスト規約 (Ruby)

## 入力

- テスト対象: `spec/**/*` または `test/**/*` 配下のファイル

## 出力

- RSpec または Minitest 形式のテストコード

## 処理手順

1. テストフレームワークを確認する (RSpec を標準使用、Minitest も可)
2. `describe` / `context` / `it` でテスト構造を定義する
3. Arrange-Act-Assert パターンでテストを記述する
4. テスト名を「何を」「どの条件で」「どうなるか」の形式で命名する
5. モックが必要な場合は `instance_double` を使用し、最小限に留める

## 規約

- RSpec を標準使用 (Minitest も可)
- Arrange-Act-Assert パターン
- `describe` / `context` / `it` で構造化
- テスト名は「何を」「どの条件で」「どうなるか」
- モックは最小限に (`instance_double` を使用)

## 使用例

```ruby
# RSpec の例
RSpec.describe User do
  describe '#full_name' do
    context '姓と名が両方ある場合' do
      it '姓と名をスペースで結合して返す' do
        # Arrange
        user = instance_double(User, first_name: '太郎', last_name: '山田')
        # Act
        result = user.full_name
        # Assert
        expect(result).to eq('山田 太郎')
      end
    end
  end
end
```
