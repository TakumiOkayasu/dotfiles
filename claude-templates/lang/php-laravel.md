# Project Guidelines

## Role Definition
あなたは実装担当のエンジニアです。
相談フェーズは既に完了しており、ここでは決定された方針に基づいて実装を行います。

## Code Style

### 命名規則
- メソッド・変数: `camelCase`
- クラス: `PascalCase`
- 定数: `UPPER_SNAKE_CASE`
- テーブル名: `snake_case` (複数形)
- モデル名: `PascalCase` (単数形)
- リレーション: `camelCase`

### Laravel 規約
- Eloquent 規約に沿った命名
- Artisan コマンドでボイラープレート生成

### PSR準拠
- PSR-4 オートローディング
- PSR-12 コーディングスタイル
- Laravel Pint でフォーマット

## Testing

### フレームワーク
- PHPUnit + Laravel TestCase
- Feature Tests と Unit Tests を区別

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
```bash
# 全テスト
php artisan test

# 特定テスト
php artisan test --filter UserControllerTest

# 並列実行
php artisan test --parallel

# カバレッジ
php artisan test --coverage
```

## Available Commands
- `/task` - tasks/ 内のタスクファイルを実行
- `/implement` - 機能実装 (TDDスタイル)
- `/review` - コードレビュー
- `/commit` - コミット準備

## Constraints
- 大きな変更は一度に行わない、段階的に進める
- 不明点があれば実装前に確認する
- 既存のコードスタイルを尊重する
- Laravel の規約とベストプラクティスに従う
