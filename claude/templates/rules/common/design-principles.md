# 設計原則

## SOLID

- **単一責任**: 1クラス/関数 = 1つの変更理由
- **開放閉鎖**: 拡張に開き、修正に閉じる。新機能は既存コードの変更なしで追加
- **リスコフ置換**: サブタイプは親型の契約を破らない
- **インターフェース分離**: クライアントが使わないメソッドへの依存を強制しない
- **依存性逆転**: 上位モジュールは下位の具象に依存しない。抽象に依存する

## DRY / KISS / YAGNI

- **DRY**: 同一ロジックの重複禁止。ただし早すぎる抽象化は避ける (3回繰り返したら抽出)
- **KISS**: 最も単純な解決策を選ぶ。複雑さは必要になってから追加
- **YAGNI**: 現在必要な機能だけ実装。将来の要件を推測して作らない

## 関心の分離

- ビジネスロジックとI/Oを分離
- 表示ロジックとデータ処理を混在させない
- 設定値はコードから分離 (ハードコード禁止)

## 合成と継承

- 継承より合成を優先
- 継承は2階層まで。深い継承チェーンは合成に置き換える
- 「is-a」関係が明確な場合のみ継承を使用

## 命名 (言語共通の原則)

- 名前は意図を表現する (何をするかではなく、なぜ存在するか)
- 略語は避ける。検索可能な名前を使う
- ブール値は `is_`, `has_`, `can_` で始める
- 対になる概念は対になる名前 (open/close, start/stop)

## 使用例

### 単一責任の適用

```python
# ❌ 複数責任
class UserService:
    def save_user(self, user): ...
    def send_welcome_email(self, user): ...
    def render_profile_html(self, user): ...

# ✅ 責任を分離
class UserRepository:
    def save(self, user): ...

class UserNotifier:
    def send_welcome_email(self, user): ...

class UserPresenter:
    def render_profile_html(self, user): ...
```

### DRY の適用

```python
# ❌ 重複ロジック
def calc_tax_jp(price): return price * 0.10
def calc_tax_us(price): return price * 0.10  # 同一ロジック

# ✅ 3回繰り返したら抽出
def calc_tax(price, rate): return price * rate
```

### 依存性逆転の適用

```python
# ❌ 具象依存
class OrderService:
    def __init__(self): self.db = MySQLDatabase()

# ✅ 抽象依存
class OrderService:
    def __init__(self, db: DatabaseInterface): self.db = db
```
