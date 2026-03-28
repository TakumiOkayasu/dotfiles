# テスト規約 (Python)

## 適用対象

- `tests/**/*`
- `**/test_*.py`

## テストフレームワーク

- **pytest** を標準使用

## 命名規則

テスト名は以下の形式で記述する:

```
test_<対象>_<条件>_<期待結果>
# 例: test_parse_empty_input_raises_value_error
```

## 構造パターン: Arrange-Act-Assert

```python
def test_add_positive_numbers_returns_sum():
    # Arrange
    a, b = 1, 2

    # Act
    result = add(a, b)

    # Assert
    assert result == 3
```

## モック方針

- モックは**最小限**に留める
- 外部I/O・時刻・ランダム値のみモック対象とする

## カバレッジ計測

```bash
pytest --cov=. --cov-report=term-missing
```

## 入出力

| 入力 | 出力 |
|------|------|
| テスト対象コード | テスト結果 (pass/fail) |
| `pytest` コマンド引数 | カバレッジレポート (--cov 指定時) |

## 使用例

```bash
# 全テスト実行
pytest

# 特定ファイルのみ
pytest tests/test_parser.py

# 詳細出力
pytest -v

# カバレッジ付き
pytest --cov=src --cov-report=term-missing
```
