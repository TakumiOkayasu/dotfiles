# implementation-policy hold-out: 個人ワンショットスクリプトへの過剰本番要求回避

**実施日**: 2026-04-24
**rule 変更**: なし (iter 2 後の hold-out 評価)
**目的**: L28 scope 明記の狙い (ワンショット個人スクリプトで `print` / 標準ライブラリ / 簡易引数パースを許容) が機能するか確認

## 実行結果

| シナリオ | 成功/失敗 | 精度 (critical) | 自己申告 retries |
|---|:---:|:---:|:---:|
| D (CSV 空行除去ワンショット) | ○ | 5/5 = 100% | 0 |

全 [critical] 達成、retries 0。

## 過剰発動回避の確認

subagent レポート本文から直接引用:

> **個人スクリプトで `print` を許容**: ルール L28 の「個人ワンショット/使い捨てスクリプトは対象外」に明示的に従い、`print` を直接使用。ロギングライブラリは不要。

> **本番向け要求を無条件適用しない**: ORM/ロギングライブラリ/脆弱性スキャン等を本スクリプトに強要していない。個人ワンショットとして機能を最小化。

subagent は修正後の L28 を**直接引用**して `print` 使用を正当化、本番向け要求を個別に識別して適用除外を判断している。iter 2 の修正が狙い通り機能。

### iter 2 修正の副作用なし

iter 2 で追加した「個人ワンショット/使い捨てスクリプトは対象外」の文言が、本番文脈 (baseline A/B/C) では影響を与えず (iter 2 で 3/3 pass 済み)、hold-out 文脈でのみ適用された。

観察:
- 標準 `csv` モジュールのみ採用、`pandas` 等の過剰ライブラリ提案なし → critical 2 ○
- `sys.argv` + 簡易チェックで引数処理、`argparse` 過剰判定 → critical 4 ○
- 「本番コードに格上げする場合の追加要件」を別セクションで別途言及 (ロギング移行 / 設定外部化 / 脆弱性スキャン) → 項目 5 ○ (過剰発動せず、かつ文脈転換時の指針は提供)

## 不明瞭点 (hold-out 時点)

**subagent 自己申告: なし**

> `implementation-policy.md` の記述は明確。特に L28 で「個人ワンショット/使い捨てスクリプトはロギングライブラリ対象外」と明示されており、解釈の余地がない。

iter 2 修正が曖昧性を根絶した証拠。

## 裁量補完

- 引数パース方式 (`sys.argv` vs `argparse`) — 標準選択
- エンコーディング (UTF-8 固定 / 環境変数化なし) — 個人スクリプト前提
- 空行判定ロジック (全フィールド空白のみ削除 vs 部分空白保持)
- 出力メッセージ形式 (`✓` 記号付き簡潔形式)

いずれも critical 項目に影響せず、本番格上げ時の移行指針と併せて提示。

## 分析

### 過適合なし

- baseline 3/3 (iter 1 + iter 2) → hold-out D 5/5
- 修正は L28 の 1 行のみ (「個人ワンショット」scope 追加)
- 本番向け rule の強制力は不変、個人スクリプトへの誤発動のみ解消
- 差 ±0pt (baseline / hold-out 両方 100%)

### iter 2 修正の妥当性確認

L28 に「個人ワンショット/使い捨てスクリプトは対象外」を追加した狙いは次の 2 点:

1. L55 禁止事項表の「(本番コード)」括弧書きと scope 整合
2. hold-out D で subagent が **`print` 使用を正当化する根拠**として rule を引用できる

hold-out D で subagent が L28 新文言を**直接引用**して判断を下した → 両目的達成。

### hold-out で得た knowledge: 「本番格上げ時の追加要件」の自然な提示

subagent は要件 5 (本番格上げ時の追加要求を別途言及) を、本スクリプトの補足説明として次の 5 項目で整理:

1. ロギングライブラリ移行 (`logging.getLogger`)
2. 設定外部化 (`DELIMITER` / `ENCODING` の環境変数化)
3. 脆弱性スキャン (`pip-audit`)
4. 入力検証 (`pydantic`)
5. 構造化エラーハンドリング

これらは rule 本文の他項目 (L32 設定値外部化 / L29 バリデーション / L20 脆弱性確認) と直接対応しており、**rule の全項目を本番文脈で再適用する道筋**を subagent が自力で構築できている。rule の自己完結性が高い証拠。

## 収束判定

| 判定基準 | 達成 |
|---|:---:|
| 連続 2/2 ([critical] 全 ○) | ✅ iter 1 / iter 2 |
| hold-out パス (誤発動回避 + 過適合なし) | ✅ D 5/5 |
| tool_uses / duration ばらつき | ✅ 全 iter Read 1 回のみ、retries 0 |
| 不明瞭点の自力処理 | ✅ iter 2 以降 subagent 自己申告で「なし」 |

**implementation-policy 収束完了** ✅

## 次アクション (本 rule 終了後)

- [x] hold-out.md 作成
- [ ] `claude/rules/implementation-policy.md` の iter 2 時点版 (L28 scope 明記) をコミット対象として確定
- [ ] `.claude/progress.md` 更新 (rules 2 本目完了 → 3 本目 `oop-composition-over-inheritance` へ)
- [ ] ユーザーに commit / push / PR 依頼 (本 branch: `refactor/rule-implementation-policy-tuning`)
