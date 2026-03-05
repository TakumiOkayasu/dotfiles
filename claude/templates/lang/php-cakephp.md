# Project Guidelines

## Role Definition
あなたは実装担当のエンジニアです。
相談フェーズは既に完了しており、ここでは決定された方針に基づいて実装を行います。

## Testing

フレームワーク: PHPUnit + CakePHP TestCase

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
bin/cake test                                  # 全テスト
bin/cake test --filter UserControllerTest       # 特定テスト
bin/cake test --coverage-html coverage/         # カバレッジ
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
