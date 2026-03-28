# Hierarchical Architecture

**依存は常にピラミッド型。横の参照禁止。上位は指示のみ、実行は下位。**

## レイヤー構造 (上位→下位の依存のみ許可)

| # | 役割 | 責務 | 命名例 |
|---|------|------|--------|
| 1 | Interface | 契約の定義 (単一責任) | `Readable`, `Writable` |
| 2 | 管理層 | 下位の生成・破棄・ライフサイクル | `*Manager`, `*Context` |
| 3 | 提供層 | 同種能力のグルーピング | `*Provider`, `*Registry` |
| 4 | 操作層 | 特定リソースへのアクセス | `*Accessor`, `*Client` |
| 5 | サブコンポーネント (任意) | ドメイン固有オブジェクト | — |
| 6 | Platform | プラットフォーム固有実装 | — |

## 設計手順

新しいコンポーネントを追加・修正する際は以下の順で判断する:

1. **レイヤーを特定する**: そのクラス/モジュールはどの責務か (管理/提供/操作/Platform)
2. **依存方向を確認する**: 依存先は必ず自分より下位のレイヤーか
3. **インターフェースを定義する**: 単一責任の契約を先に書く (`interface-first-design` スキル参照)
4. **合成で組み立てる**: コンストラクタ注入でインターフェースに依存する
5. **命名を確認する**: サフィックスでレイヤー役割が読み取れるか

## ピラミッド依存

- A→B必要時: A→Manager問い合わせ→抽象情報で応答
- 横参照 (A←→B) 禁止
- 段階飛ばしアクセス禁止
- 上位は指示のみ。下位の内部操作代行は禁止
- 同レベルには同じ抽象化情報のみ伝達 (公平性)

```
# ✅ 正しい依存方向
CLI (管理層)
  └─ MdImprover (提供層)
       ├─ QualityChecker (操作層)
       ├─ PromptGenerator (操作層)
       └─ FileManager (操作層)

# ❌ 禁止パターン
QualityChecker → PromptGenerator  # 同一レイヤー間直接参照
FileManager → MdImprover          # 下位→上位依存
CLI → QualityChecker              # 段階飛ばし
```

## インターフェース設計

- 単一責任: `Readable { read() }` + `Writable { write() }` (混在NG)
- 操作は抽象化可能 / データは具象型を直接使用
- 入出力は分離: 物理的に同一でも論理的責務で分ける

```python
# ✅ 単一責任インターフェース
class Readable(Protocol):
    def read(self, path: Path) -> str: ...

class Writable(Protocol):
    def write(self, path: Path, content: str) -> None: ...

# ❌ 責務混在
class FileHandler(Protocol):
    def read(self) -> str: ...
    def write(self, content: str) -> None: ...
    def validate(self) -> bool: ...   # 責務過多
```

## 合成・拡張

- 同一IF合成: `Encrypter(Logger(EmailSender(config)))` — 組み合わせ自由
- パラメータ化: 差異がパラメータだけならサブクラス不要
- 合成 > 継承: 深い継承禁止。コンストラクタ注入で合成
- DI: インターフェースに依存。具象クラス直接依存禁止

```python
# ✅ コンストラクタ注入 (DIパターン)
class MdImprover:
    def __init__(
        self,
        checker: QualityCheckerProtocol,
        generator: PromptGeneratorProtocol,
        manager: FileManagerProtocol,
    ) -> None: ...

# ❌ 具象依存
class MdImprover:
    def __init__(self) -> None:
        self.checker = QualityChecker()  # 具象クラス直接生成
```

## 入力の抽象化

```
Raw Input → Calibrated Input → Intent
```

- `Raw Input`: コマンドライン引数、ファイルパス文字列など生データ
- `Calibrated Input`: バリデーション・正規化済みデータ
- `Intent`: アプリケーションが扱う意図レベルのデータ (例: `TargetFile`)

アプリケーションコードは `Intent` のみに依存する。`Raw Input` を直接扱わない。

## ライフサイクル・イベント

- 生成と利用の分離 / 確保と解放はワンセット
- リソース管理の独立性: マネージャが自律的に確保・解放
- Pull型イベント基本

## 命名規則

| 役割 | サフィックス例 | 判断基準 |
|------|---------------|----------|
| 管理 | `*Context`, `*Manager` | 下位コンポーネントのライフサイクルを持つか |
| 提供 | `*Provider`, `*Registry` | 同種能力を束ねてグルーピングするか |
| 操作 | `*Accessor`, `*Client` | 特定リソース (DB/FS/API) に直接アクセスするか |

## 禁止事項

| 違反パターン | 理由 |
|-------------|------|
| 同一レイヤー間直接参照 | 横参照はピラミッド構造を壊す |
| 下位→上位依存 | 循環依存・密結合の原因 |
| 段階飛ばしアクセス | 中間レイヤーの責務が機能しなくなる |
| 複数責任IF / 入出力混在 | 単一責任原則違反 |
| 深い継承 / 具象依存 | 合成で代替する |
| 利用者によるリソース生成 | マネージャが生成責任を持つ |
| レイヤー役割が読み取れない命名 | 命名規則でレイヤーを明示する |
