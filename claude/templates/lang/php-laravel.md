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
```bash
php artisan test                              # 全テスト
php artisan test --filter UserControllerTest  # 特定テスト
php artisan test --parallel                   # 並列実行
php artisan test --coverage                   # カバレッジ
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
