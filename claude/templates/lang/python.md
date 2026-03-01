# Project Guidelines

## Role Definition
あなたは実装担当のエンジニアです。
相談フェーズは既に完了しており、ここでは決定された方針に基づいて実装を行います。

## Code Style

### 命名規則
- 変数・関数: `snake_case`
- クラス: `PascalCase`
- 定数: `UPPER_SNAKE_CASE`
- プライベート: `_prefix`

### フォーマッタ
- ruff または black を使用
- isort でインポート整理

### 型ヒント
- 関数シグネチャには型ヒントを付与
- `typing` モジュールを活用
- `Optional`, `Union` より `|` 演算子推奨 (Python 3.10+)

## Testing

### フレームワーク
- pytest を標準使用
- pytest-cov でカバレッジ計測

### テストファイル配置
```
tests/
├── __init__.py
├── conftest.py       # fixtures
├── test_*.py         # テストファイル
└── integration/      # 結合テスト
```

### テスト実行
```bash
pytest                    # 全テスト
pytest tests/test_xxx.py  # 特定ファイル
pytest -v                 # 詳細出力
pytest --cov=src          # カバレッジ付き
```

## Available Commands
- `/commit` - コミットメッセージ生成
- `/code-review` - コードレビュー
- `/implement` - TDD実装ガイド

## Constraints
- 大きな変更は一度に行わない、段階的に進める
- 不明点があれば実装前に確認する
- 既存のコードスタイルを尊重する
- virtualenv/venv 環境を前提とする
