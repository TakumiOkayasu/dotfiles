# コードスタイル (Python)

## 概要

Pythonコードのスタイル・命名規則・型ヒントの標準を定義する。
新規コード作成・レビュー・リファクタリング時に適用すること。

## 入力

- 対象のPythonコード（関数・クラス・モジュール）

## 出力

- スタイル規約に準拠したPythonコード

## 処理手順

### 1. 命名規則を適用する

| 対象 | 規則 | 例 |
|------|------|----|
| 変数・関数 | `snake_case` | `user_name`, `get_item()` |
| クラス | `PascalCase` | `UserProfile`, `HttpClient` |
| 定数 | `UPPER_SNAKE_CASE` | `MAX_RETRY`, `DEFAULT_TIMEOUT` |
| プライベート | `_prefix` | `_internal_state`, `_validate()` |

### 2. フォーマッタを実行する

```bash
# ruff（推奨）
ruff format <対象ファイル>
ruff check --fix <対象ファイル>

# black（代替）
black <対象ファイル>

# isort（インポート整理）
isort <対象ファイル>
```

### 3. 型ヒントを付与する

- 全関数のシグネチャに引数型・戻り値型を付与する
- `typing` モジュールを必要に応じて使用する
- Python 3.10+ では `Optional[X]` → `X | None`、`Union[X, Y]` → `X | Y` に統一する

```python
# ❌ 非推奨
def get_user(user_id: Optional[int]) -> Union[str, None]:
    ...

# ✅ 推奨 (Python 3.10+)
def get_user(user_id: int | None) -> str | None:
    ...
```

### 4. インポートを整理する

- 標準ライブラリ → サードパーティ → ローカルの順に配置する
- isort または ruff で自動整理する

## 使用例

```python
# ✅ 準拠例
MAX_ITEMS = 100

class ItemProcessor:
    def __init__(self, source: str) -> None:
        self._source = source

    def process(self, item_id: int | None = None) -> list[str]:
        ...
```
