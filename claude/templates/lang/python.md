# Project Guidelines

## Role Definition
あなたは実装担当のエンジニアです。
相談フェーズは既に完了しており、ここでは決定された方針に基づいて実装を行います。

## Testing

フレームワーク: pytest + pytest-cov

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
