# コードスタイル (PHP/CakePHP)

## 目的

PHP/CakePHPプロジェクトにおけるコードスタイル規約を定義し、一貫性のある実装を支援する。

## 入力

- レビュー対象のPHP/CakePHPコード（クラス・メソッド・変数名など）

## 出力

- 規約に準拠したコード
- 規約違反箇所の指摘と修正案

## 命名規則

| 対象 | 規則 | 例 |
|------|------|----|
| メソッド・変数 | `camelCase` | `getUserName()`, `$firstName` |
| クラス | `PascalCase` | `UserController`, `ArticleTable` |
| 定数 | `UPPER_SNAKE_CASE` | `MAX_RETRY_COUNT` |
| テーブル名 | `snake_case`（複数形） | `user_profiles`, `blog_posts` |
| モデル名 | `PascalCase`（単数形） | `User`, `Article` |

## PSR準拠

- PSR-4 オートローディング
- PSR-12 コーディングスタイル

## CakePHP 規約

- 規約に沿った命名で自動関連付けを活用
- Bake コマンドでスキャフォールド生成

## 処理手順

1. 命名規則テーブルで対象コードの種類を特定する
2. 対応する規則を適用する
3. PSR-12違反（インデント・括弧・空行等）を修正する
4. CakePHP規約（テーブル名↔モデル名の対応）を確認する
5. 修正後のコードを出力する

## 使用例

```php
// ❌ 規約違反
class user_controller {
    public function Get_User_Name($User_ID) { ... }
    const maxRetry = 3;
}

// ✅ 規約準拠
class UserController {
    public function getUserName(int $userId): string { ... }
    const MAX_RETRY = 3;
}
```

## 注意事項

- CakePHPの自動関連付けはテーブル名とモデル名の対応が前提。命名を崩すと関連付けが機能しない
- Bakeで生成したコードは規約準拠済みのため、手動変更時のみ本規約を参照する
