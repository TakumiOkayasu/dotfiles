# Coding Conventions

**言語非依存のコード規約。プロジェクト固有の規約はそれに従う。**

## 比較演算

| ルール | 内容 | 例外時の対応 |
| ------ | ------ | ------ |
| 厳密等価を原則 | `===`, `!==` (型強制なし) を使用する | 緩い比較 (`==`, `!=`) を使う場合は**理由を明示し承認を得る** |
| boolean は truthy/falsy で評価 | `if (flag)` / `if (!flag)` を使用する | `=== true` / `=== false` は**常に禁止** |

```javascript
// ✅ 正しい
if (user.isActive) { ... }
if (!items.length) { ... }
if (value === null) { ... }

// ❌ 禁止
if (user.isActive === true) { ... }   // 冗長 + truthy値を弾く
if (items.length == 0) { ... }        // 型強制あり (理由なし)
```

**理由**: 型強制 (`==`) は予期せぬバグの温床。`=== true` は truthy 値 (非boolean) を弾いてしまう一方、冗長で意図も不明瞭。

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

## 命名 (言語共通の原則)

- 名前は意図を表現する (何をするかではなく、なぜ存在するか)
- 略語は避ける。検索可能な名前を使う
- ブール値は `is_`, `has_`, `can_` で始める
- 対になる概念は対になる名前 (open/close, start/stop)

> レイヤー役割のサフィックス命名 (`*Manager`, `*Provider` 等) は `hierarchical-architecture.md` を参照。

## エラーハンドリング

### 基本原則

- エラーを握り潰さない。catch したら処理するかログに記録して再throw
- fail-fast: 不正な状態は早期に検出して即座に報告
- バリデーションはシステム境界 (入力受付点) で実施

### エラーの種類と対応

| 種類 | 例 | 対応 |
|------|-----|------|
| 業務エラー | 入力不正, 残高不足 | ユーザーに明確なメッセージ |
| システムエラー | DB接続失敗, タイムアウト | ログ + リトライ or フォールバック |
| プログラムエラー | null参照, 型不一致 | 修正すべきバグ。例外を投げる |

### 禁止事項

- 空の catch ブロック
- 汎用的すぎる例外 (`catch (Exception e)`) で全てを捕捉
- エラーコードの代わりに例外を制御フローに使用
- 正常系と異常系の混在 (エラーを戻り値で返すか例外で返すか統一)

### ログ

- エラーログにはコンテキスト情報を含める (何が, どこで, なぜ)
- ログレベルを適切に使い分ける (ERROR/WARN/INFO/DEBUG)
- 機密情報をログに含めない

## 使用例

### 単一責任

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
```

### エラーハンドリング

```python
# ❌ 禁止: 空のcatch
try:
    process()
except Exception:
    pass

# ✅ 正しい: 種別に応じた処理
try:
    result = db.query(user_id)
except DBConnectionError as e:
    logger.error("DB接続失敗 user_id=%s: %s", user_id, e)
    raise SystemError("サービスが一時的に利用できません") from e
except ValueError as e:
    logger.warning("入力不正 user_id=%s: %s", user_id, e)
    return ErrorResponse(message="入力値を確認してください")
```
