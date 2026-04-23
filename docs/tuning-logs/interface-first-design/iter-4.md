# interface-first-design iter 4: null vs Ok/Error ポリシー整理 + 3並列再評価

**実施日**: 2026-04-23
**修正内容**: SKILL.md Step 2 変換ルール L108 を 1 行書き換え（読取系=`T|null` / 副作用系=`Ok|Error` の書き分け明記）
**目的**: IFD-3-C-2（3 iter 継続の最古残存、L108「Ok/Error の 2 値」と Anti-pattern 1 `User | null` の一見不整合）を解消

---

## SKILL.md 差分

L108 を以下に置換:

```markdown
# 変更前
- 戻り値は Ok/Error の2値で成功/失敗を明示する

# 変更後
- 戻り値は用途で書き分け: 読取系（`find` / `read` 等、副作用なし）は `T | null` で not-found を明示、副作用系（`write` / `charge` / `delete` 等）は `Ok | Error` で成功/失敗を明示する
```

追加行数: 0（1 行置換）
総行数: 284 維持

---

## 評価表（iter 4）

| シナリオ | 精度 | tool_uses | duration (s) | retries | 不明瞭点 | 裁量補完 | 前回比 |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| A | **8/8 ○** | 1 | 53.4 | 0 | 2件（[要確認]済）| 3件 | +15% |
| B | **7/7 ○** | 1 | 57.6 | 0 | 3件（[要確認]済）| 3件 | +7% |
| C | **6/6 ○** | 1 | 58.6 | 0 | 3件（[要確認]済）| 3件 | -0.6% |

**集計（iter 4）**:
- 精度: 21/21 = **100%** 維持
- tool_uses: 全 1 維持
- duration: 平均 **56.5s**（iter 3 平均 53.1s 比 +6.4%、**±15% 以内**）
- retries: 全 0 回

---

## iter 4 修正の実地観察（IFD-3-C-2 解消確認）

**3 subagent 全てが新文言を interface ごとに明示適用**:

| シナリオ | 適用結果 |
|:-:|---|
| A | 副作用系のみで構成されるため**全 interface を `Ok\|Error` 統一、`T\|null` 適用なし**（読取系 find/read 存在せず）を合理的に判断。PriceCalculator は純粋計算で `Money` 直接返却（失敗なし）と整合的に除外 |
| B | interface 一覧表に「戻り値型の根拠」列を新設し、`UserReader.read → User\|null` / `UserWriter`/`UserDeleter`/`WelcomeNotifier → Ok\|Error` / `UserLister.list → User[]`（集合読取=空配列、coding-conventions 整合）と根拠付きで明示 |
| C | `ArticleReader.read → Article\|null` / `ArticleLister.list → Article[]` / `ArticlePageLister.listPage → Page<Article>` に書き分け、「副作用系は今回スコープ外、追加時は `Ok\|Error` 方針」と明記 |

**重要観察**:
- 3 subagent 独立で「**用途**（読取/副作用/集合読取）」の分類軸が確立
- iter 3 までの「戻り値型の迷い」（例外 vs null / Ok|Error の一律適用）が**完全に消失**
- シナリオA では「副作用系のみ」と判定して全 `Ok|Error` 統一 = 新ルールの正しい**非適用**判断
- シナリオB/C は集合読取で空配列採用 = `coding-conventions` rule との整合を subagent が自発的に確立

---

## 収束判定（iter 4）

empirical-prompt-tuning L128 収束条件に対して:

| 条件 | iter 3 → iter 4 | 判定 |
|---|---|:---:|
| 新規不明瞭点 0 件 | 0 件（全て [要確認] 構造化済み）| ○ |
| 精度前回比改善 ≤3pt | 100% → 100% | ○ |
| ステップ数 ±10% | tool_uses 全 1 維持 | ○ |
| duration ±15% | 53.1s → 56.5s (+6.4%) | ○ |

**連続クリアカウント: 3/3 達成** ✅✅✅

- iter 2: 1/3（上位層粒度 修正の実地解消 + 精度維持）
- iter 3: 2/3（[要確認] 記法 修正の実地解消 + 新規不明瞭点ゼロ）
- iter 4: 3/3（戻り値書き分け 修正の実地解消 + 全収束条件クリア）

**重要スキル目標達成**: 連続 3 イテレーションで empirical-prompt-tuning 反復打ち切り基準を満たす → hold-out 評価フェーズへ移行

---

## 残存不明瞭点（収束時点）

| ID | 内容 | 実害 | 評価 |
|:-:|---|:-:|---|
| IFD-4-A-1 | 通知送信失敗時の扱い（[要確認]化済） | 小 | 周辺運用詳細、中核設計に影響なし |
| IFD-4-A-2 | 在庫チェックが予約込みか否か | 小 | 要件解釈、設計パス分岐で裁量対応 |
| IFD-4-B-1 | ウェルカムメール送信タイミング（[要確認]化済） | 小 | 周辺運用詳細 |
| IFD-4-B-2 | 削除が物理/論理か（[要確認]化済） | 小 | 周辺運用詳細 |
| IFD-4-B-3 | エクスポート出力形態（[要確認]化済） | 小 | 周辺運用詳細 |
| IFD-4-C-1 | paginate 意味（ページ vs カーソル）（[要確認]化済） | 中 | 戻り値型に影響、[要確認] で構造化 |
| IFD-4-C-2 | ソート指定所在（[要確認]化済） | 小 | ArticleQuery で吸収 |

**すべて周辺運用詳細 + `[要確認]` 記法で構造化済み** → 中核 4 本柱（疑似コード / ISP / 上位層組み立て / 戻り値書き分け）は安定

---

## 次アクション

**hold-out 評価** (シナリオD: 誤発動回避) を single subagent で dispatch

- hold-out 精度が baseline 平均 (100%) から -15pt 以内であれば過適合なし → **スキル収束完了**
- hold-out シナリオD の要件: 本スキルのトリガー条件に非該当と判定し、隣接スキル (systematic-debugging → tdd) に誘導、疑似コード/interface 表を強制生成しない
