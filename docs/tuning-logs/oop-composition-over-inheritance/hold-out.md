# hold-out: 単純 DTO / 値オブジェクト (Price) の新規作成

## 目的

iter 2 で連続 2/2 達成後、overfit (chargé なシナリオに合わせすぎて単純ケースで過剰設計を出す) を回避できているかを確認する。シナリオ D は **interface 化・合成を要求しない** 単純ケース。

## 実施条件

- 対象 rule: `claude/rules/oop-composition-over-inheritance.md` (iter 2 修正反映後、L54-62「継承を採用してよい場面」節追加済み)
- subagent_type: `general-purpose` x 1
- シナリオ: D (単純な値オブジェクト `Price` の新規作成。金額 `Decimal` + 通貨コード 3 文字、等価比較・文字列表現)

## 評価軸

| 項目 | 値 |
|---|---|
| [critical] 全 ○ | ○ (1, 2) |
| 精度 | 100.0% (5/5) |
| tool_uses | 1 |
| duration_ms | 34,466 |
| 再試行 | 0 |
| 判定 | ○ |

## 成果物サマリ

- `@dataclass(frozen=True)` + `Decimal amount` + `currency: str` (ISO 4217 正規表現検証)
- `__post_init__` で型・形式チェック
- `__str__` のみ上書き (等価比較・hash・repr は自動生成)
- **過剰な interface 化や `PriceCalculator` / `PriceFormatter` 分離は提案せず**
- 継承 (`Price(Decimal)`) は L62「機能差分は合成で注入」に基づき非推奨と明示
- 将来「通貨変換」「税込/税抜」等の**具体的要求発生時**に interface 化・合成へ移行する方針を明記 (YAGNI 適用)
- 値オブジェクトは L10-13 / L72 の「合成による拡張性」議論の対象外 (単純データ構造) と判断

## 要件達成詳細

| # | 判定 | 根拠 |
|---|---|---|
| 1 [critical] 過剰要求を出さない | ○ | `dataclass(frozen=True)` で直接定義、interface 化は提案せず |
| 2 [critical] 不要な分離 interface を提案しない | ○ | `PriceCalculator` / `PriceFormatter` 等の架空分離を明示的に排除 |
| 3 将来拡張トリガーへの言及 | ○ | 通貨変換・税込税抜・複数フォーマット発生時の interface 化移行を後置 |
| 4 継承 (`Price(Decimal)`) の判断 | ○ | L62 根拠で「避ける」判断を明示 |
| 5 値オブジェクトは合成議論対象外 | ○ | L10-13 / L72 の「合成による拡張性」議論は振る舞いを持つ処理系向けで、純データは対象外と解釈 |

## 不明瞭点 (minor)

- **D-u1**: L59「値オブジェクト階層」が is-a の許容例。今回は階層を作らないので適用外だが、仮に `TaxIncludedPrice(Price)` のような派生が登場する場合の扱いは L62 の「2 段まで」制限と整合することを要確認
- **D-u2**: L72「特定の処理 (ストリーム・フィルタ・変換など) に限らず…拡張性の高い設計全般」— 値オブジェクト (DTO) が「拡張性の高い設計」の議論対象に含まれるかは明示なし。L10-13「機能単位の組み合わせ」の語感から純データは対象外と解釈

いずれも [critical] 判定に影響なし、過剰要求なし、rule の意図通り「適用対象外」として穏当処理できている。

## 裁量補完

- ISO 4217 検証は正規表現形式チェックのみ (実コード全集との照合は YAGNI)
- `__post_init__` による fail-fast 型チェック
- `__str__` フォーマット "金額 通貨" (通貨記号や桁区切りなし)
- 負の金額・ゼロ許容判断は指示になく制約せず

## overfit 判定

- iter 2 で 「合成・DI 推奨」 の強化があったが、D シナリオで過剰に適用することなく**単純な値オブジェクトとして割り切った設計**を返した
- iter 2 追加節「継承を採用してよい場面」の L62「機能差分は合成で注入」を**引用して継承を退ける判断材料**に使っており、追加節が副作用なく効果を発揮
- **overfit なし** ✅

## 収束判定

- 連続 2/2 (iter 1: ○○○ with C partial / iter 2: ○○○ full) + hold-out ○ → 典型 rule 目標達成
- rule 1 (oop-composition-over-inheritance) **収束完了** ✅

## 次アクション

1. PROGRESS.md 更新 (rule 1 完了マーク + rule 2 開始メモ)
2. ユーザーへ rule 1 の commit 依頼 (現ブランチ: `refactor/rule-oop-composition-over-inheritance-tuning`)
3. rule 2 (hierarchical-architecture) 開始: main へ戻って新ブランチ作成
