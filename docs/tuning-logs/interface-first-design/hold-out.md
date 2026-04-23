# interface-first-design hold-out: シナリオD 誤発動回避

**実施日**: 2026-04-23
**対象**: `claude/skills/interface-first-design/SKILL.md` (284 行、iter 4 時点の最新)
**フェーズ**: 収束判定のための hold-out 単発 dispatch

---

## シナリオ

ユーザーから「`utils/format_currency.ts` の桁区切り処理でカンマが入らないバグがある。直して」と依頼。対象は純粋関数で既存の単体テストあり、1 ファイル・20 行程度。interface 設計の必要性は低い。

---

## 評価結果

| 項目 | 値 |
|---|---|
| **精度** | **4/4 ○** (全 [critical] 達成) |
| tool_uses | 1 |
| duration | 31.7s（iter 4 平均 56.5s 比 **-44%**、早期離脱で短縮） |
| retries | 0 |
| 本スキル発動判定 | **非発動** |
| トリガー条件照合 | L12-18 の 5 条件**すべて非該当** |

---

## [critical] 要件達成

| # | 要件 | 結果 |
|:-:|---|:-:|
| 1 [crit] | トリガー条件非該当 → 本スキル非発動 | ○ |
| 2 [crit] | 隣接スキル（systematic-debugging → tdd）に誘導 | ○ |
| 3 | 過剰理由をトリガー条件に照らして説明 | ○（5 条件×判定結果の表を提示）|
| 4 | 疑似コード/interface 表を強制生成しない | ○（非発動判定後に出力せず） |

---

## 隣接スキル誘導の詳細

subagent は **3 段の誘導**を自発的に構成:

1. `systematic-debugging` — 桁区切りが入らない原因を 4 フェーズで特定
2. `TDD` — 失敗する再現テスト → 修正 → REFACTOR
3. `test-coverage-guard` — 既存テストの偽陽性チェック（裁量補完）

`test-coverage-guard` の追加提示は iter 2-4 で構築された「隣接スキル境界の自発認識」の応用（refactoring / TDD 境界を明文化した波及効果）。

---

## 過適合判定

| 指標 | baseline 平均 (iter 1-4) | hold-out | 差 |
|:-:|:-:|:-:|:-:|
| 精度 | 100% | 100% | **±0pt** |
| tool_uses | 1.0 | 1 | ±0 |
| duration | 54.7s | 31.7s | -44%（早期離脱） |

**-15pt 閾値に対し差 ±0pt** → **過適合なし**

baseline 設計に戻る必要なし。中核 4 本柱（疑似コード / ISP / 上位層粒度 / 戻り値書き分け）は hold-out でも安定。

---

## iter 2-4 修正が誤発動抑止に寄与した点

| 修正 (iter) | hold-out での寄与 |
|---|---|
| 上位層の粒度の目安 (iter 2) | 非発動判定で無視（発動対象外のため非適用）|
| `[要確認]` 記法 (iter 3) | 非発動判定で「不明瞭点なし」と明示可能 |
| 戻り値書き分け (iter 4) | 非発動判定で interface 定義そのものが不要 |
| トリガー条件 L12-18 | **5 条件×判定結果表**として subagent が誤発動抑止の根拠として直接引用 |

トリガー条件節は iter 0 時点から不変だが、description の 3 要素（機能追加 / クラス設計 / 責務分割）が hold-out で「該当せず」と subagent が正しく切り分けた = description と body の整合が成立している証左。

---

## 収束判定

| 条件 | 判定 |
|---|:---:|
| 連続 3 イテレーション（新規不明瞭点 0 件 + 精度 +3pt 以内 + steps ±10% + duration ±15%）| ✅ iter 2 → 3 → 4 |
| hold-out 精度が直近平均から -15pt 以内 | ✅ ±0pt |
| 中核 4 本柱が baseline + hold-out で安定 | ✅ |

**interface-first-design スキル収束完了** ✅

重要スキル目標（連続 3 + hold-out パス）達成。

---

## 残存曖昧点（周辺運用詳細、収束後）

収束条件を満たしたものの、以下は中核 4 本柱の**外側**の周辺運用詳細として残存:

| ID | 内容 |
|:-:|---|
| IFD-4-A-1 ~ A-2 | 通知失敗 / 在庫予約兼用（[要確認]化済） |
| IFD-4-B-1 ~ B-3 | ウェルカムメール / 削除方式 / エクスポート形態（[要確認]化済） |
| IFD-4-C-1 ~ C-2 | paginate 意味 / ソート所在（[要確認]化済） |

**全て `[要確認]` 記法で構造化**されており、将来のイテレーションで個別対応可能。現時点では**スキル本体の再設計は不要**。

---

## 次スキル: consultation（典型スキル、連続2、scenarios.md 未作成）

計画書順序通り、iface-first 直後に consultation を配置。境界対比は trigger-overlap.md L15 (「設計」: consultation vs iface-first) と L13 (「実装」: consultation vs iface-first vs tdd) で整理済み。
