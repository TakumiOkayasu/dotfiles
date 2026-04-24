# coding-conventions hold-out D: 既準拠コードへの過剰修正回避

**実施日**: 2026-04-24
**rule 変更**: なし (iter 3 時点の rule を適用)

## シナリオ

既に rule 準拠の TypeScript 関数 (`fetchUserProfile`) に対して「レビューして気になる点を挙げて」と依頼。subagent が過剰修正を提案しないか、既準拠を認識できるかを評価。

## 実行結果

| 項目 | 値 |
|---|---|
| 成功/失敗 | ○ |
| 精度 | 5/5 (critical 2/2) |
| tool_uses | 1 |
| duration | 43.9s |
| retries | 0 |
| **過剰修正提案数** | **0** |

## 観察ポイント

### 既準拠として明示的に認識 (critical 1 達成)

subagent は以下 9 項目を**列挙して「rule 準拠と判断した項目」**と明示:

- 早期リターン (ガード節)
- 定数化 (`MAX_RETRY_COUNT` UPPER_SNAKE_CASE)
- 型注釈 (引数 / 戻り値 明示)
- 構造化ログ (キー・バリュー形式)
- async/await
- catch で処理実施 (空 catch ではない)
- 命名 (`fetchUserProfile` は動詞 + 具体名)
- 関数サイズ (30 行以内、ネスト 2 階層、引数 1 個)
- `const` 使用 / immutable 指向

**判定**: 「修正必要なし」と明言。rule を lint として誤用せず、準拠点を正確に列挙。

### 設計選択を保留 (critical 2 達成)

subagent は境界論点のみ提示:
1. 最終リトライ失敗時の null vs throw → 「呼出側要件次第」で保留
2. log レベル粒度 (warn vs error) → 運用判断として提示
3. backoff の是非 → 「rule 範囲外」と明示して軽く触れるのみ

いずれも rule 違反指摘ではなく**設計選択の提示**。L106 「未取得 vs 空結果」の判定を明確に呼出側要件に委ねる判断を見せた。

## 裁量補完

- backoff 論点を「rule 外」として軽く触れたのみ (スコープ認識が正確)

## 不明瞭点

- 呼出側の「取得失敗」扱い設計が未提示のため null/throw 選択は保留

## 分析

### hold-out 合格

- 過剰修正提案 **0 件** ← 最重要
- 既準拠 9 項目を具体的に列挙 (rule の各トピックと照合)
- 境界論点 3 件はすべて「設計選択」扱いで修正指示せず
- CC-3-A-1 (L106 null 許容) の未解消部分を subagent 側が「呼出側次第」と**自律的に判断**して保留 — rule 改修せずとも運用で吸収できる裁量が残っている状態

### 副次的観察

iter 3 で追加した L149 の try/catch 判定基準は、本 hold-out 関数 (`fetchUserProfile`) にも潜在的に関係 (catch でログ記録+ループ継続 = 「文脈付与・ログ出力」に該当)。subagent はこの挙動を rule 違反指摘せず「catch で処理実施」と準拠扱い。新文言の適用範囲が適切。

## 収束まとめ

| phase | iter | 連続達成 |
|---|:---:|---|
| baseline | iter 1 | 1/3 |
| L149 try/catch 判定基準追記 | iter 2 | 2/3 (CC-1-C-1 解消確認) |
| L209 React 例外境界追記 | iter 3 | **3/3** (CC-1-B-1 解消確認) |
| hold-out D | — | **パス** (過剰修正 0) |

**重要 rule 目標 (連続 3 + hold-out) 達成** ✅

## 次アクション

- [x] hold-out.md 作成
- [ ] PROGRESS.md 更新 (coding-conventions 完了マーク)
- [ ] ユーザー commit/push/PR 作成依頼
