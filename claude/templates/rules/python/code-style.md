# コードスタイル (Python)

## 命名規則

- 変数・関数: `snake_case`
- クラス: `PascalCase`
- 定数: `UPPER_SNAKE_CASE`
- プライベート: `_prefix`

## フォーマッタ

- ruff または black を使用
- isort でインポート整理

## 型ヒント

- 関数シグネチャには型ヒントを付与
- `typing` モジュールを活用
- `Optional`, `Union` より `|` 演算子推奨 (Python 3.10+)
