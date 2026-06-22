# architecture-design シナリオカタログ

empirical-prompt-tuning でチューニングする評価シナリオ。**iter 開始後は変更しない**。

- 対象 skill: `claude/skills/arch/SKILL.md`
- 概要: コンポーネントのレイヤー配置・責務分割・合成と継承の判定・依存整理の設計手順
- 収束目標: **連続 2** イテレーション (典型スキル)

## 隣接 rule・skill との境界

| 隣接 | 対比 |
| --- | --- |
| `hierarchical-architecture` rule | rule = **不変条件** (依存方向・継承深度・命名)、本 skill = **設計手順** (どう配置するか) |
| `interface-first-design` skill | interface-first = **疑似コード → interface 起こし** (テスト先行に繋ぐ前段)、本 skill = **レイヤー配置 + 合成判定** (interface 起こしを内包) |
| `refactoring` skill | refactoring = 振る舞いを変えず構造改善、本 skill = **新規設計の手順** (既存リファクタも対象だが視点が違う) |

## Baseline シナリオ

### シナリオ A (median): 取込パイプラインの新規クラス設計

**状況**:
新機能: ファイル (CSV / JSON / Excel) を読み取り、共通中間表現 (`ImportRecord[]`) に変換してから DB に流す取込パイプラインを設計したい。

要件:
- 入力形式は 3 つ (CSV, JSON, Excel)。将来 XML / Parquet を追加する可能性
- バリデーション (必須項目 / 型 / 範囲) は形式によらず共通
- DB 書き込みは upsert
- エラー時は形式別にロールバック方針が違う (CSV/JSON は全ロールバック、Excel はシート単位)

「どう設計すべきか、レイヤー構造・クラス分割・合成のしかたを提案して」とユーザーが質問。

**要件チェックリスト**:
1. **[critical]** 依存方向 (上位→下位) を守る設計を提案、下位→上位・横参照を提案していない
2. **[critical]** 合成優先で設計 (継承を提案する場合は本文の許可条件下のみ、深度 2 段以内)
3. **[critical]** サフィックス命名 (`*Manager`, `*Provider`, `*Accessor` 等) でレイヤー役割が読み取れる
4. インターフェース (契約) を先に定義してからクラス設計に入っている (`Readable`, `Validatable` などの interface 列挙)
5. コンストラクタ注入で依存を組み立てている (DI を明示)
6. Raw Input → Calibrated Input → Intent の入力抽象化に言及している
7. 将来の形式追加で既存クラス変更が不要な設計 (Open/Closed)

### シナリオ B (edge): 3 段継承のリファクタリング

**状況**:
既存コード:
```typescript
class BaseProcessor {
  protected log(msg: string) { /* ... */ }
  protected async transaction<T>(fn: () => Promise<T>): Promise<T> { /* ... */ }
}

class BasePaymentHandler extends BaseProcessor {
  protected async charge(amount: number): Promise<void> { /* ... */ }
  protected async refund(amount: number): Promise<void> { /* ... */ }
}

class OrderProcessor extends BasePaymentHandler {
  async placeOrder(orderId: string): Promise<void> { /* charge + log + transaction */ }
}
```

ユーザー: 「3 段継承だけど、これってどうリファクタすればいい?」

**要件チェックリスト**:
1. **[critical]** 3 段継承を **合成に置き換える** 設計を提案している (継承 2 段以内ルール準拠)
2. **[critical]** 各責務 (logging, transaction, payment, order processing) を **独立クラス** に分け、`OrderProcessor` がコンストラクタ注入で組み合わせる構造
3. **[critical]** 依存方向違反 (OrderProcessor が下位のことを知る、TransactionManager が PaymentHandler に依存する等) を提案していない
4. インターフェース分離 (Logger / TransactionRunner / PaymentGateway 等) で具象依存を避けている
5. is-a 関係でない (能力差分の継承) ことを根拠に合成を選択している
6. リファクタの **段階手順** (どの順で抽出するか) を提示している

### シナリオ C (boundary): React Modal — フレームワーク継承の例外

**状況**:
ユーザー: 「React で再利用可能な Modal コンポーネントを作りたい。`Component` を継承するか関数コンポーネントにするか、また Modal の内部状態 (open/close, focus trap) をどう設計すべきか」

**要件チェックリスト**:
1. **[critical]** 「継承を採用してよい場面」のフレームワーク基底継承の例として `React.Component` を引き合いに出し、根拠を提示
2. **[critical]** 機能差分 (focus trap / portal / accessibility) は合成 (hooks や子コンポーネント注入) で組み立てるよう提案
3. **[critical]** 内部状態 (open/close) を Modal 自身で持つか親から制御するかの **DI 観点** に言及
4. 関数コンポーネント vs クラスコンポーネントのトレードオフを 1 行でも示している (React 19 では関数推奨)
5. Single Responsibility (Modal は表示のみ、open/close 制御は呼び出し側) を提案
6. ライフサイクル管理 (ESC キーリスナー / scroll lock 等) を **管理層** として分離

### シナリオ D (hold-out): pure function 3 個 — skill 非該当判定

**状況**:
ユーザー: 「`formatDate(d: Date) → string`, `parseCSV(input: string) → string[][]`, `slugify(s: string) → string` の 3 つの関数をどこに置くべき?」

期待される挙動: skill の手順 (レイヤー配置・合成判定) を強行せず、「これらは pure function でレイヤー分割 / 継承判定の対象ではない」と認識して回答。`hierarchical-architecture` rule のみで判断可能、`*Util` 系の命名を避けた具体的なモジュール分割を提案する程度。

**要件チェックリスト**:
1. **[critical]** skill の手順 (レイヤー特定 → 依存方向確認 → interface 先 → DI → 命名) を pure function に強行していない
2. **[critical]** `coding-conventions` rule の「`*Util` 命名を避け、役割別に分割」を引いて具体名を提案 (`DateFormatter` 不要、`format-date.ts` ファイル直接 export 等)
3. レイヤー命名 (`*Manager` / `*Provider`) を pure function に強要していない
4. 「pure function は本 skill 対象外、必要があれば置き場所のみ提案」を 1 行で明示

## 判定規則

- 成功 ○ = [critical] 全 ○
- 精度 % = (○: 1.0 / 部分的: 0.5 / ×: 0) の合算 / 全項目数
