# テスト規約 (Ruby)

## 概要

Rubyプロジェクトにおけるテスト作成・実行の規約を定義する。

## 適用条件

- `spec/**/*` または `test/**/*` 配下のファイルを編集・作成するとき

## テストフレームワーク

- **標準**: RSpec
- **代替**: Minitest（プロジェクト既存設定に従う）

## 処理手順

### 1. テスト構造の組み立て

```ruby
describe クラス名 do
  context "条件の説明" do
    it "期待する振る舞い" do
      # Arrange: 前提条件を設定
      # Act: 対象メソッドを実行
      # Assert: 結果を検証
    end
  end
end
```

### 2. テスト名の命名

| 要素 | 内容 | 例 |
|------|------|-----|
| 何を | テスト対象 | `User#full_name` |
| どの条件で | 入力・状態 | `名字と名前が両方ある場合` |
| どうなるか | 期待結果 | `スペース区切りで返す` |

**例**:
```ruby
describe User do
  describe "#full_name" do
    context "名字と名前が両方ある場合" do
      it "スペース区切りで連結した文字列を返す" do
        user = User.new(first_name: "太郎", last_name: "山田")
        expect(user.full_name).to eq "山田 太郎"
      end
    end

    context "名前がnilの場合" do
      it "名字のみ返す" do
        user = User.new(first_name: nil, last_name: "山田")
        expect(user.full_name).to eq "山田"
      end
    end
  end
end
```

### 3. モックの使用

- **原則**: モックは最小限に抑える
- **使用するクラス**: `instance_double`（型安全なテストダブル）

```ruby
# ✅ 推奨: instance_double で型チェックあり
mailer = instance_double(UserMailer, send_welcome: true)

# ❌ 禁止: double は型チェックなし
mailer = double("mailer", send_welcome: true)
```

## 入出力

| 項目 | 内容 |
|------|------|
| 入力 | `spec/` または `test/` 配下のテストファイル |
| 出力 | テスト結果（pass/fail）、カバレッジレポート（設定時） |

## 実行例

```bash
# 全テスト実行
bundle exec rspec

# 特定ファイル実行
bundle exec rspec spec/models/user_spec.rb

# 特定の例のみ実行
bundle exec rspec spec/models/user_spec.rb:15
```
