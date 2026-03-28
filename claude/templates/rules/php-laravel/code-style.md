# コードスタイル (PHP/Laravel)

## 概要

PHP/Laravelプロジェクトにおけるコードスタイル規約。AIがコード生成・レビュー時に参照する基準。

## 入力

- レビュー対象のPHP/Laravelコード、またはコード生成の依頼

## 処理手順

1. 命名規則を確認し、違反箇所を特定する
2. PSR準拠状況を確認する
3. Laravel固有規約への適合を確認する
4. 違反がある場合は修正案を提示する

## 命名規則

| 対象 | スタイル | 例 |
|------|----------|-----|
| メソッド・変数 | `camelCase` | `getUserName()`, `$userEmail` |
| クラス | `PascalCase` | `UserController`, `OrderService` |
| 定数 | `UPPER_SNAKE_CASE` | `MAX_RETRY_COUNT` |
| テーブル名 | `snake_case` (複数形) | `user_profiles`, `order_items` |
| モデル名 | `PascalCase` (単数形) | `UserProfile`, `OrderItem` |
| リレーション | `camelCase` | `hasMany`, `belongsTo` |

## PSR準拠

- PSR-4: オートローディング（名前空間とディレクトリ構造を一致させる）
- PSR-12: コーディングスタイル（インデント・括弧・空行の規則）
- Laravel Pint でフォーマット自動適用（`./vendor/bin/pint`）

## Laravel 規約

- Eloquent 規約に沿った命名（主キー`id`、タイムスタンプ`created_at`/`updated_at`）
- ボイラープレートは Artisan コマンドで生成（`php artisan make:model`, `make:controller` 等）

## 出力

- 違反箇所の一覧（ファイル名・行番号・違反内容）
- 修正後のコードスニペット
- 問題がない場合は「規約準拠済み」と明示

## 使用例

```
入力: UsercontrollerクラスにgetUser_nameメソッドがある
出力:
  違反1: クラス名 `Usercontroller` → `UserController` (PascalCase)
  違反2: メソッド名 `getUser_name` → `getUserName` (camelCase)
```
