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

### CakePHP 規約
- 規約に沿った命名で自動関連付けを活用
- Bake コマンドでスキャフォールド生成

### PSR準拠
- PSR-4 オートローディング
- PSR-12 コーディングスタイル

## Testing

### フレームワーク
- PHPUnit + CakePHP TestCase

### テストファイル配置
```
tests/
├── bootstrap.php
├── Fixture/           # テストデータ
├── TestCase/
│   ├── Controller/
│   ├── Model/
│   │   └── Table/
│   └── Service/
└── phpunit.xml
```

### テスト実行
```bash
# 全テスト
bin/cake test

# 特定テスト
bin/cake test --filter UserControllerTest

# カバレッジ
bin/cake test --coverage-html coverage/
```

## Available Commands
- `/commit` - コミットメッセージ生成
- `/code-review` - コードレビュー
- `/implement` - TDD実装ガイド

## Constraints
- 大きな変更は一度に行わない、段階的に進める
- 不明点があれば実装前に確認する
- 既存のコードスタイルを尊重する
- CakePHP の規約を最大限活用する
