# oop-composition-over-inheritance シナリオカタログ

## 隣接 rule / skill との境界

| 隣接 | 境界 |
|---|---|
| `hierarchical-architecture` (L69-90 合成・拡張節) | HA は**レイヤー依存方向**の強制 (上位→下位のみ) を主眼。OOP はレイヤー内/レイヤー跨ぎに関わらず「パラメータ増・継承ツリーでの拡張を避けて合成で組み立てる」判断軸。両方適用 |
| `coding-conventions` L215-221 (SOLID 5 原則) | CC は 1 行サマリの SOLID、OOP は「合成 > 継承」に絞った実装指針。OOP は CC の「依存性逆転」「単一責任」「開放閉鎖」を具体化したもの。設計判断の具体的ガイダンスは OOP を優先参照 |
| `interface-first-design` skill (疑似コード → interface → クラス → TDD) | IFD は**実装順序**のスキル (発動時)、OOP は**どんな設計が良いか**の常時適用ルール。OOP で「合成する」と決めた後、IFD で具体的な interface 定義順序に従う |
| `refactoring` skill | refactoring は振る舞いを変えない構造改善手順、OOP は設計原則。refactoring 実行中に OOP を判断軸として使う |

## baseline シナリオ (3 本、中央値 1 + edge 2)

### A (中央値): レガシー通知クラスの継承階層リファクタ

**状況**: Python の既存コード。`BaseNotifier` を継承した `EmailNotifier`, `SlackNotifier`, `SMSNotifier` があり、さらに「ログを残す版」「暗号化する版」「再試行付き版」が派生クラスとして増殖している (現状 12 クラス、組み合わせ爆発)。新規要件で「Slack + ログ + 再試行」「Email + 暗号化」などの任意組み合わせが必要になった。どう再設計するか相談する。

```python
# 現状
class BaseNotifier: ...
class EmailNotifier(BaseNotifier): ...
class LoggingEmailNotifier(EmailNotifier): ...
class RetryingLoggingEmailNotifier(LoggingEmailNotifier): ...  # ←増殖
class EncryptingEmailNotifier(EmailNotifier): ...
# ... 12 クラス、組み合わせのたびにクラス追加が必要
```

**要件チェックリスト**:
1. [critical] 「継承深度が組み合わせに応じて無限増殖」を**悪い設計の兆候** (既存コードの変更が必要 / パラメータを増やすだけの設計) として指摘する
2. [critical] **合成 (Decorator パターン / コンストラクタ注入)** を提案し、同一 interface を持つクラスをネスト (`Retrying(Logging(EmailSender(config)))` 形式) で組み立てる案を示す
3. 単一責任の interface (`Notifier` など 1 メソッド) を明示、各機能 (Email/Slack/SMS/Logging/Retrying/Encrypting) を単独クラスに分離
4. DI (コンストラクタ注入) で外部から合成する構造を示す
5. 新機能 (別チャネル / 別ミドルウェア) 追加時に既存クラスを変更不要であることを成功指標として挙げる
6. 例コードで Python `Protocol` または抽象基底クラスによる interface 定義を含める (optional)

### B (edge, パラメータ化で済むケース): 税率計算クラスの階層増殖懸念

**状況**: EC サイトで消費税計算クラスを作る。現状 `TaxCalculator` は 10% を即値で持つ。今後、軽減税率 (8%)、海外配送 (0%)、業務 (将来的に 15%) に対応する必要が出てきた。新人が「`ReducedTaxCalculator`, `ZeroTaxCalculator`, `BusinessTaxCalculator` とサブクラスを 3 つ追加する」案を出してきた。合成 > 継承の観点でレビューする。

```python
# 新人提案
class TaxCalculator: 
    def calculate(self, amount): return amount * 0.10
class ReducedTaxCalculator(TaxCalculator):
    def calculate(self, amount): return amount * 0.08
class ZeroTaxCalculator(TaxCalculator):
    def calculate(self, amount): return 0
class BusinessTaxCalculator(TaxCalculator):
    def calculate(self, amount): return amount * 0.15
```

**要件チェックリスト**:
1. [critical] 差異が**税率 (数値パラメータ) のみ**であることを指摘し、サブクラス化不要 (パラメータ化で十分) と判定する
2. [critical] `TaxCalculator(rate=0.10)` のようにコンストラクタで税率を受ける単一クラス案を提示する
3. 将来「軽減税率の対象商品判定ロジック」等、**単なるパラメータ差ではない挙動差**が入ってきたら interface 化 + 合成を検討すべきと言及する (YAGNI 原則の適用)
4. `ReducedTaxCalculator` 等のサブクラス追加は「パラメータを増やすだけの設計」「条件分岐が増え続ける」悪い設計の兆候に該当しないか判断する
5. 過剰な抽象化 (不要な `TaxStrategy` interface を今すぐ切る等) を提案しない (YAGNI 尊重)

### C (edge, フレームワーク制約・is-a 継承の許容): React クラスコンポーネントの継承判定

**状況**: 既存 React プロジェクト (クラスコンポーネント主体) で、`class UserForm extends Component` を書く必要がある。レビュアから「合成 > 継承の原則があるので `extends Component` も避けるべきでは?」と指摘された。実際どう判断するか。類似パターンで Django の `class OrderView(LoginRequiredMixin, View):` や、ゲームでの `class Enemy(GameObject):` も扱う。

**要件チェックリスト**:
1. [critical] **フレームワーク要求の継承 (React `Component`, Django `View`, Android `Activity` 等) は許容**と判定する (保守的すぎて「全継承禁止」と判定しない)
2. [critical] **is-a 関係が明確な継承 (`Enemy is a GameObject`) も許容**と判定する (値オブジェクト・ドメインモデルの階層)
3. 「合成 > 継承」の原則は**派生クラスで機能を増築するケース** (A シナリオの LoggingEmailNotifier 等) に主眼があると説明する
4. 継承深度の目安として「1-2 段まで、それ以上は合成検討」を示す (OOP rule に定量基準があればそれを引用)
5. React の **関数コンポーネント + hooks** 移行は「合成」の別形態として言及 (optional、文脈次第)
6. Mixin (Django の `LoginRequiredMixin`) は継承形式だが実質合成であることを指摘できる (optional)

## hold-out シナリオ (D、誤発動回避)

### D: 単純な値オブジェクト / DTO クラスの新規作成

**状況**: 「商品の `Price` 値オブジェクトを Python で作ってほしい。金額 (decimal) と通貨コード (3 文字) を保持するだけ。等価比較と文字列表現もついでに」

**要件チェックリスト**:
1. [critical] **「interface 化して合成しろ」等の過剰要求を出さない**。単純な値オブジェクトは `dataclass(frozen=True)` や `NamedTuple` で直接定義してよい
2. [critical] `Price` に不要な `PriceCalculator` や `PriceFormatter` 等の interface 分離を**提案しない** (YAGNI、過剰抽象化回避)
3. 将来「通貨変換が必要」「税込/税抜の使い分けが必要」等の具体的要求が出た時点で interface 化・合成を検討すればよいと言及 (optional)
4. 継承 (`Price(Decimal)` 等の数値型継承) は避けるべきか、採用してよいかの判断を示す (Python の場合は合成推奨、Java `BigDecimal` extends 等は別判断)
5. DTO / 値オブジェクトは OOP rule の「合成による拡張性」議論の対象外であり、単純な構造体として割り切る判断を支持する

## 共通の dispatch プロンプト要件

- 対象 rule 本文 (`claude/rules/oop-composition-over-inheritance.md`) を Read で読ませる
- 他 rule / skill の auto-load は避ける (対象 rule 優先参照)
- empirical-prompt-tuning「subagent 起動契約」節のレポート構造で返答
- `[critical]` 項目が全 ○ のときのみ成功
