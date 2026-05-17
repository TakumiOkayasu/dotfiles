# qa-nightmare iter-regression (構造変更後の再評価)

## 背景

prior tuning (iter 1-4 + hold-out) は `claude/skills/qa-nightmare/SKILL.md` (skill 形式) で実施。その後、構造変更で `claude/agents/qa-nightmare.md` (agent 形式) に移行。本回はこの構造変更後の regression 確認。

- 旧: skill 形式、本文 280+ 行 (Phase 1-6 + e2e-browser 連携)
- 新: agent 形式、本文 80 行 (Phase 1-3 + 出力 + 責務境界)
- 主な変更: Phase 4-6 (e2e-browser 連携・実行) を削除し、ランク付き一覧生成までを agent の責務に絞った

## シナリオ (確定版)

- A (median): 商品在庫減算 API (`POST /api/orders`)、optimistic locking
- B (edge): 商品マスタ CSV インポート (バックグラウンドジョブ + メール通知)
- C (sparse): 「ユーザー登録機能」のみ、URL/path/スキーマすべて未提供

## 実行結果

| シナリオ | 成功/失敗 | 精度 | tool_uses | duration | retries |
| --- | :---: | ---: | ---: | ---: | ---: |
| A | ○ | 100% (7/7) | 13 | 136.7s | 0 |
| B | ○ | 94% (7.5/8) | 13 | 152.2s | 0 |
| C | ○ | 100% (6/6) | 1 | 44.1s | 0 |
| **平均** | | **98%** | 9.0 | 111.0s | 0 |

全シナリオで `[critical]` 全 ○ → 成功判定。

## prior iter 4 (skill 版) との比較

| 指標 | prior iter 4 (skill) | iter-regression (agent) | 差分 |
| --- | :---: | :---: | :---: |
| 平均精度 | 100% | 98% | -2pt (B の部分減点) |
| 平均 tool_uses | 5.33 | 9.0 | +69% (A/B が agent 形式で 11 ファイル全部 Read を厳格に実施) |
| 平均 duration | 83.3s | 111.0s | +33% (Read 数増に比例) |
| 新規不明瞭点 | 0 件 | 0 件 (構造起因) | ±0 |

agent 化に伴う Read 数増は agent 形式の仕様 (subagent としての厳格な checklist 適用)。**精度・[critical] 達成は維持**。

## 不明瞭点 (新出 — 構造起因)

**0 件**。

### subagent 裁量範囲内 (構造問題ではない)

- **B (94%)**: 各行の「スコア」列に `3×3=9 → S` の `→ S` を明示せず、表ヘッダの「S ランク」セクション分けで暗示した。agent.md L48 は「`発見困難度×被害度=積 → ランク` を 1 行で示す」と明示しているが、subagent は表構造で代用。
  - 評価: [critical] ではなく通常項目 #2 の部分減点。指示は明確で、subagent の表現裁量。再現性低い (シナリオ A・C では同 subagent が 1 行記法で書いていた)。

## 裁量補完 (新出)

- A: `[推測]` マーカーを Phase 1 内に書く規定だが、最終出力テーブルにその欄がないため省略
- B: マルチテナント設計か単一テナントかが不明 → AB-08 は推測前提で採用
- C: 確認事項末尾に「対象が画面か API か」「ソース参照可能なパス」を追記

## 収束判定

- prior iter 3-4 + hold-out (skill 版) で **連続 2/2 + 過適合なし** 達成済 ✅
- 構造変更後 (agent 版) でも全シナリオ [critical] 全 ○、平均 98%、新規不明瞭点 0 件 → **収束維持** ✅
- B シナリオの部分減点は subagent 表現裁量範囲、agent 指示そのものは明確 → 修正不要

## 次アクション

- qa-nightmare 完了。Target 2 (deep-review) に移行。
- 修正なし、agent ファイルは現状のまま PR 化対象。
