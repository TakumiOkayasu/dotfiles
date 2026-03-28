# テスト規約 (Python)

## 目的

Pythonプロジェクトにおけるテストの記述・実行規約を定義する。

## 適用対象

- `tests/**/*`
- `**/test_*.py`

## 基本規約

- pytest を標準使用
- Arrange-Act-Assert パターンで記述
- テスト名は「何を」「どの条件で」「どうなるか」を含める
- モックは最小限に留める
- pytest-cov でカバレッジ計測

## 処理手順

### 1. テストファイルの配置

```
tests/
├── test_<モジュール名>.py
└── conftest.py  # 共通フィクスチャ
```

### 2. テスト関数の命名

```python
def test_<対象>_<条件>_<期待結果>():
    ...
```

**例:**

```python
def test_add_negative_numbers_returns_correct_sum():
    ...
```

### 3. Arrange-Act-Assert パターン

```python
def test_calculate_tax_given_valid_price_returns_tax():
    # Arrange
    price = 1000
    tax_rate = 0.1

    # Act
    result = calculate_tax(price, tax_rate)

    # Assert
    assert result == 100
```

### 4. テスト実行

```bash
# 全テスト実行
docker compose run --rm test

# 単一テスト実行
docker compose run --rm test pytest tests/test_<対象>.py::<クラス>::<テスト名> -v

# カバレッジ付き実行
docker compose run --rm test pytest --cov=src --cov-report=term-missing
```

## 入力

- テスト対象のソースコード (`src/`)
- テストファイル (`tests/`)

## 出力

- テスト結果 (PASS / FAIL / ERROR)
- カバレッジレポート (term-missing 形式)

## モック使用基準

| 状況 | 判定 |
|------|------|
| 外部API・DBアクセス | ✅ モック使用 |
| ファイルI/O（副作用あり） | ✅ モック使用 |
| 同一プロジェクト内の関数 | ❌ 実装を直接使用 |
| 単純な計算・変換 | ❌ モック不要 |
