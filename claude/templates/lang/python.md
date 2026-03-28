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

**入力**: テスト対象のパス（省略時は全テスト）
**出力**: テスト結果レポート（pass/fail件数、カバレッジ率）

```bash
pytest                    # 全テスト実行
pytest tests/test_xxx.py  # 特定ファイルのみ実行
pytest -v                 # 詳細出力付きで実行
pytest --cov=src          # src/ のカバレッジ計測付きで実行
pytest --cov=src --cov-report=term-missing  # 未カバー行を表示
```

### テスト実装手順

1. `tests/test_<対象モジュール名>.py` にテストファイルを作成する
2. 共通フィクスチャは `tests/conftest.py` に定義する
3. 結合テストは `tests/integration/` 配下に配置する
4. RED: 失敗するテストを先に書く
5. GREEN: テストが通る最小実装を書く
6. REFACTOR: コードを整理する（テストは引き続きパスさせること）

## Available Commands
- `/commit` - コミットメッセージ生成
- `/code-review` - コードレビュー
- `/implement` - TDD実装ガイド

## Constraints
- 大きな変更は一度に行わない、段階的に進める
- 不明点があれば実装前に確認する
- 既存のコードスタイルを尊重する
- virtualenv/venv 環境を前提とする
- テストなしで実装完了とみなさない
