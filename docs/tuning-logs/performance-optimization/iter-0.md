# iter 0 — performance-optimization（静的整合チェック）

**対象**: `claude/skills/performance-optimization/SKILL.md`（183 行）
**dispatch**: なし（静的チェックのみ）

## description / body 整合表

| 観点 | description 記述 | body 対応 | 整合 |
|---|---|---|---|
| パフォーマンス最適化 | 「パフォーマンス最適化」 | 鉄則「Profile → Measure → Optimize → Verify」 + Step 1-4 | ○ |
| プロファイリング | 「プロファイリング時に使用」 | Step 2 プロファイリング実行 | ○ |
| 計測手法 | 「計測手法」 | Step 1 ベースライン計測（p50/p95/p99/req/s/メモリ/スロークエリ） | ○ |
| ボトルネック特定 | 「ボトルネック特定」 | Step 2-3 + 「よくあるボトルネック」節（N+1/O(n²)/再計算/リーク） | ○ |
| 負荷テスト | 「負荷テスト」 | 「負荷テスト」節（k6/wrk/ab + k6 script example） | ○ |
| レポート出力 | 「レポート出力をカバー」 | 末尾「レポートテンプレート」節 + Step 4 から参照 | ○ |

**結論**: 5観点すべて body に対応節あり。description 側の過不足は表層的には無い。

## 直前スキル（qa-nightmare）との description 重なり語チェック

| 語 | perf-opt | qa-nightmare | 整理 |
|---|---|---|---|
| テスト | `負荷テスト`（language の一部） | `テストケース`（QA 悪夢） | 文脈が明確に異なる（perf-opt=負荷、qa-nightmare=機能 QA） |
| 自動実行 | `-` | `自動実行する` | 重なりなし |
| 最適化 | `パフォーマンス最適化` | `-` | 重なりなし |

trigger-overlap.md で perf-opt に登場する高リスク語は無し。

## 懸念候補（iter 1 で観察対象）

| ID | 懸念 | 実害度（事前予想） | iter 修正候補 |
|---|---|:---:|---|
| PO-0-1 | **隣接スキル境界節が本体に無い**（systematic-debugging / refactoring / tdd / TCG / failure-logging との対比未記載） | 中〜高（refactoring/consultation/iface-first/e2e-browser/qa-nightmare の iter 2 で上振れ波及したパターン） | iter 2 最有力（先例踏襲） |
| PO-0-2 | トリガー「N+1/O(n²)/メモリリーク」と「よくあるボトルネック」節の項目名が重複（冗長） | 低（本体構造が二重防御として機能する方向に作用） | 観察のみ |
| PO-0-3 | 前提条件「計測環境が明確」に**本番のみ** case の扱いが明示なし（シナリオ B の直接論点） | 中 | シナリオ B で具体論点化 → iter 2+ 判断 |
| PO-0-4 | 禁止事項「本番環境でのみ計測する」と「観測目的の APM 仕込み」の境界不明瞭 | 中 | シナリオ B で表面化する場合のみ対処 |
| PO-0-5 | フロントエンド節（Core Web Vitals）はトリガーに明示的語がない（「画像遅い」「LCP」等） | 低（サーバサイド baseline のみで評価可、誤発動懸念ではない） | 観察のみ |
| PO-0-6 | レポートテンプレが末尾配置。Step 4 からの距離が遠く、subagent が参照せず独自テンプレ生成する可能性 | 低〜中 | iter 1 で参照有無を観察 |
| PO-0-7 | Step 4 「ベースラインとの差分を数値で記録する」は自然だが、失敗時（改善なし・悪化）のロールバック基準が鉄則に埋もれている（Step 3 の 3「効果がなければ即座にリバート」） | 低 | 観察のみ |

## 中核 3 本柱（hold-out までの固定観察軸）

1. **鉄則**: 計測なき最適化は推測 / Profile → Measure → Optimize → Verify / 50% を 2 倍 > 1% を 10 倍
2. **手順**: Step 1 ベースライン → Step 2 プロファイル → Step 3 最適化（1 変更 1 計測） → Step 4 効果検証
3. **禁止事項表**: 7 件（計測前最適化 / ROI 低作業 / キャッシュ invalidation 欠如 / 闇雲インデックス / ORM 迂回 / 本番のみ計測 / 同時多発最適化）

シナリオ A/C は上記 3 本柱の発動を直接問う。シナリオ B は前提条件節 + 禁止事項「本番のみ計測」が連動する境界試験。hold-out D は「バグ修正」語を根拠に非発動判定を問う。

## 次アクション

- **iter 1**: scenarios.md の A/B/C を 3 並列 dispatch → baseline 評価表を iter-1.md に記録
- 懸念 PO-0-1 / PO-0-3 を最優先観察対象
- 重要修正は iter 2 以降（iter 1 は修正なし）
