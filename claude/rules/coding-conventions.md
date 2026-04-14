# Coding Conventions

**言語非依存のコード規約。プロジェクト固有の規約はそれに従う。**

> サンプルコードは複数言語 (Python / JavaScript / TypeScript) を用いる。言語固有機能 (`===`, `?.`, `async/await` 等) が効果的な箇所はその言語で、汎用ロジックは Python で示す。**ルールの精神**を読み取り、使用言語に置き換えて適用すること。

## 比較演算

| ルール | 内容 | 例外時の対応 |
| ------ | ------ | ------ |
| 厳密等価を原則 | `===`, `!==` (型強制なし) を使用する | 緩い比較 (`==`, `!=`) を使う場合は**理由を明示し承認を得る** |
| boolean は truthy/falsy で評価 | `if (flag)` / `if (!flag)` を使用する | `=== true` / `=== false` は**常に禁止** |

```javascript
// ✅ 正しい
if (user.isActive) { ... }
if (value === null) { ... }

// ❌ 禁止
if (user.isActive === true) { ... }   // 冗長 + truthy値を弾く
if (items.length == 0) { ... }        // 型強制あり (理由なし)
```

**理由**: 型強制 (`==`) は予期せぬバグの温床。`=== true` は truthy 値 (非boolean) を弾いてしまう一方、冗長で意図も不明瞭。

## 制御フロー

| ルール | 内容 |
|--------|------|
| 早期リターン優先 | ガード節でネストを減らす。深いif-elseを避ける |
| ネスト上限 | **制御構造 (if/for/while) は3階層まで**。超える場合は関数抽出 |
| else省略 | 早期return後の `else` は不要。インデント削減 |
| 否定条件の優先 | ガード節は否定形で早く抜ける |

```python
# ❌ 深いネスト
def process(user):
    if user is not None:
        if user.is_active:
            if user.has_permission:
                return do_work(user)
    return None

# ✅ 早期リターン
def process(user):
    if user is None: return None
    if not user.is_active: return None
    if not user.has_permission: return None
    return do_work(user)
```

## 関数・メソッド

| ルール | 内容 |
|--------|------|
| 引数上限 | **3-4個まで**。超える場合はオブジェクト/構造体にまとめる |
| 行数上限 | **30行目安**。超える場合は分割検討 |
| 単一責任 | 1関数 = 1つのことを行う |
| 純粋関数優先 | 副作用 (I/O, グローバル変更) は端に集める |
| 副作用の明示 | 副作用ある関数は名前で示す (`saveUser`, `fetchData`) |

```python
# ❌ 引数過多
def create_user(name, email, age, role, dept, manager, phone): ...

# ✅ オブジェクト化
@dataclass
class UserInput:
    name: str
    email: str
    age: int
    role: str
    dept: str

def create_user(input: UserInput, manager: User | None = None) -> User: ...
```

## 変数・定数

| ルール | 内容 |
|--------|------|
| immutable優先 | 再代入不可を第一選択 (JS/TS: `const`, Kotlin/Scala: `val`, Rust: `let` (デフォルト不変) 等)。再代入が必要な場合のみ可変宣言 |
| スコープ最小化 | 変数は使用箇所の直前で宣言 |
| マジックナンバー禁止 | 意味のある定数名を付ける |
| マジック文字列禁止 | 繰り返し使う文字列は定数化 |
| 定数命名 | `UPPER_SNAKE_CASE` (言語慣習に従う) |

```javascript
// ❌ マジックナンバー
if (user.age >= 18 && retryCount < 3) { ... }

// ✅ 定数化
const LEGAL_AGE = 18;
const MAX_RETRY = 3;
if (user.age >= LEGAL_AGE && retryCount < MAX_RETRY) { ... }
```

## null / undefined / Optional

| ルール | 内容 |
|--------|------|
| nullable 明示 | 型で null 可能性を示す (`User \| null`, `Optional[User]`) |
| 早期null検出 | 関数冒頭でガード節 |
| null合体演算子活用 | `??` (null合体) や `\|\|` (truthy合体) でデフォルト値を簡潔に指定 |
| オプショナルチェーン | `a?.b?.c` で深いnullチェックを簡潔に |
| 空コレクション返却 | 原則 null ではなく空配列/空オブジェクトを返す (呼出側のnull処理不要)。ただし「未取得」と「空結果」を区別する必要がある場合は null 許容 |

```typescript
// ❌ null返却
function getItems(): Item[] | null {
    if (!data) return null;
    return data.items;
}
// 呼出側: if (items) { items.forEach(...) } ← 毎回チェック

// ✅ 空配列返却
function getItems(): Item[] {
    return data?.items ?? [];
}
// 呼出側: items.forEach(...) ← そのまま使える
```

## 型注釈

| ルール | 内容 |
|--------|------|
| 公開API型注釈必須 | 関数/メソッドの引数・戻り値に型を付ける |
| `any` / `Object` 禁止 | 型が不明な場合は `unknown` / `object` / ジェネリクスを使う |
| 型ガード活用 | 実行時型判定は型ガード関数でまとめる |
| 型推論優先 | ローカル変数で自明な場合は推論に任せる (過剰注釈禁止) |

```typescript
// ❌ any濫用
function parse(data: any): any { return JSON.parse(data); }

// ✅ unknown + 型ガード
function parse(data: string): unknown { return JSON.parse(data); }
function isUser(v: unknown): v is User {
    return typeof v === 'object' && v !== null && 'id' in v;
}
```

## 非同期処理

| ルール | 内容 |
|--------|------|
| async/await優先 | Promise chain (`.then`) は避ける |
| 並列実行明示 | 独立処理は `Promise.all` で並列化 |
| エラー伝播 | `try/catch` で捕捉するか、呼出側に任せる (握り潰し禁止) |
| 非同期関数命名 | 動詞で意図を示す (`fetchUser`, `loadConfig`) |

```javascript
// ❌ 直列・chain
async function loadAll() {
    return getUsers().then(users =>
        getPosts().then(posts => ({ users, posts }))
    );
}

// ✅ 並列・await
async function loadAll() {
    const [users, posts] = await Promise.all([getUsers(), getPosts()]);
    return { users, posts };
}
```

## コメント

| ルール | 内容 |
|--------|------|
| WHY を書く | 「なぜこうしたか」。WHAT (何をしているか) は読めば分かるので書かない |
| コードで語る | コメントが必要なら変数名/関数名で表現できないか検討 |
| TODO形式 | `TODO(@user): 内容` / `FIXME(@user): 内容` で担当者明示。**プロジェクト既存形式がある場合はそれに従う** |
| コメントアウト禁止 | 不要コードは削除。履歴はgitで追う |
| docstring | 公開API (ライブラリ/モジュールexport) には書く。内部関数は不要 |

```python
# ❌ WHAT (自明)
# ユーザーをDBに保存
db.save(user)

# ✅ WHY (非自明)
# 同期的にflushしないと後続のqueryで参照できないため明示flush
db.save(user)
db.flush()
```

## 命名 (言語共通の原則)

- 名前は意図を表現する (何をするかではなく、なぜ存在するか)
- 略語は避ける。検索可能な名前を使う
- ブール値は `is_`, `has_`, `can_` で始める
- 対になる概念は対になる名前 (open/close, start/stop)

### 曖昧な接頭辞・名前の禁止

意味を持たない汎用的な接頭辞・名前は**何をする関数/変数か読み取れない**ため禁止。具体的な動詞・名詞に置き換える。

| ❌ 曖昧 | 理由 | ✅ 具体化 |
|--------|------|----------|
| `handle*` | 何を「処理」するのか不明 | `validateOrder`, `submitForm`, `retryRequest` |
| `process*` | 同上 | `parsePayload`, `normalizeInput` |
| `do*` / 単独の `execute` | 目的語がなく動作が不明 | `sendEmail`, `rebuildIndex` |
| `manage*` | 責務不明 (`*Manager`サフィックスとは別) | `allocateConnection`, `scheduleJob` |
| `*Helper` / `*Util` | 責務なしの雑多置き場になる | 役割別に分割 (`DateFormatter`, `PathResolver`) |
| `data`, `info`, `item`, `obj`, `temp` | 型・内容が不明 | `userRecord`, `invoiceRow`, `parsedConfig` |

**例外**:
- フレームワーク規約 (例: React の `handleClick` イベントハンドラ慣例) は従う。ビジネスロジック側では具体名を用いる。
- ループ変数や極小スコープ (2-3行) の一時変数での `item` / `temp` は許容。スコープが広がる場合は具体名に。
- 目的語が付く `execute*` (`executeQuery`, `executeTransaction` 等) は意味が明確なため許容。

> レイヤー役割のサフィックス命名 (`*Manager`, `*Provider` 等) は `hierarchical-architecture.md` を参照。

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

## ログ

| ルール | 内容 |
|--------|------|
| レベル使い分け | ERROR (要対応) / WARN (注意) / INFO (正常) / DEBUG (調査用) |
| 構造化ログ | キー・バリュー形式。検索/集計可能な形に |
| コンテキスト付与 | 何が・どこで・なぜ発生したか |
| 機密情報除外 | パスワード・トークン・個人情報をログに含めない |
| print直接禁止 | `print` / `console.log` / `echo` はロガー経由に置換 (詳細は `implementation-policy.md`) |

```python
# ❌ 情報不足 + 機密混入
logger.error("failed")
logger.info(f"user {user.email} password {user.password}")  # 機密

# ✅ 構造化 + コンテキスト + 機密除外
logger.error("db connection failed", extra={
    "user_id": user.id, "retry": retry_count, "error": str(e)
})
```

## テスト規約

| ルール | 内容 |
|--------|------|
| AAA構造 | **A**rrange (準備) → **A**ct (実行) → **A**ssert (検証) |
| 1テスト1概念 | 1テストで1つの振る舞いのみ検証 |
| 命名 | `should_<expected>_when_<condition>` または `<対象>_<条件>_<期待>` |
| 独立性 | テスト間で状態共有禁止。順序依存禁止 |
| テスト可読性 | テストコードは本番コード以上に**読みやすさ優先** |
| 詳細は | `~/.claude/skills/TDD/SKILL.md` 参照 |

```python
# ✅ AAA + 命名
def test_should_raise_when_balance_insufficient():
    # Arrange
    account = Account(balance=100)
    # Act & Assert
    with pytest.raises(InsufficientBalance):
        account.withdraw(200)
```

## 使用例 (総合)

```python
# ❌ 複数違反 (深ネスト / マジックナンバー / any / WHATコメント / print)
def process(data: any):
    # データを処理する
    if data is not None:
        if len(data) > 10:
            for item in data:
                if item.type == "A":
                    print(item)

# ✅ 修正版
MAX_ITEMS = 10
TARGET_TYPE = "A"

def process(items: list[Item]) -> None:
    if not items: return
    if len(items) > MAX_ITEMS: return  # 上限超過は無視 (仕様)

    for item in items:
        if item.type != TARGET_TYPE: continue
        logger.info("processing item", extra={"id": item.id})
```
