# hallucination-prevention hold-out: 確認済み一般知識への過剰 `[要確認]` マーカー回避

**実施日**: 2026-04-23
**SKILL.md (rule) 変更**: なし (iter 4 後の hold-out 評価)
**目的**: ルール過剰発動 (既知事実への不要なマーカー付与・回答拒否) を回避できるかの確認

## 実行結果

| シナリオ | 成功/失敗 | 精度 (critical) | ステップ数 | duration | retries |
|---|:---:|:---:|:---:|---:|:---:|
| D (`requests.timeout` 既知事実) | ○ | 4/4 = 100% | 2 | 44.1s | 0 |

全 [critical] 達成、tool_uses 2 (Read 1 回 + 回答)、duration 44.1s (iter 4 平均 45.2s と同水準)。

## 過剰発動回避の確認

subagent レポート本文から直接引用:

> 初回判断で「timeout 引数が秒数を float/int で受ける」は公式ドキュメントで広く明示された事実と確信できたため、保留や言い換えは不要と判断した。

- `[要確認]` マーカーは一度も使用せず**断定回答**
- 一次ソース (`requests.readthedocs.io` の Quickstart / Advanced Usage「Timeouts」) を明示
- 質問範囲 (timeout の型) を超えて `tuple[float, float]` 形式や `None` 既定の補足を追加 (裁量補完、過剰拒否の逆)

### iter 2-4 追記の副作用なし

iter 2 (既定の対処) / iter 3 (URL 範囲) / iter 4 (REST API パス例外) すべての追記が、**確認済み事実への過剰マーカー付与を誘発しないか**が本 hold-out の核心。結果:

- iter 2「既定の対処は `[要確認]` で出力」→ 「既定」を全事実に適用せず、確認済みに対しては**断定経路**を正しく選択
- iter 3 L38 URL 範囲 → 「ドメイン root + パス断片」で引用、深い URL を避ける判断を踏襲 (`requests.readthedocs.io` のセクション名参照)
- iter 4 REST API パス例外 → 本シナリオでは非適用 (REST API コマンドなし)、副作用なし

## 不明瞭点 (hold-out 時点)

- L38「ドメイン root およびパス断片は公知の参照先として提示してよい」— フルURLではなくドメイン + セクション名 (「Quickstart」「Advanced Usage」) で提示する解釈を採用。どの粒度が最適かは本文に明示なし、裁量で処理
- L18「1 つでも『否』なら出力を保留する」— 公式で確認済みの事実 (timeout が秒数を受ける) は「是」と判断し保留せず。iter 1-4 で繰り返し指摘された L18 vs L50 の切り分けは、**本 hold-out では「確認済み = 是」と明確に判定可能**だったため実害なし

## 裁量補完

- 参照先粒度 (ドメイン + セクション名) の判断
- 質問範囲外の補足情報 (`tuple` 形式、`None` 既定) を追加する判断
- 「秒単位」「connect/read 両方に適用」の明示

## 分析

### 過適合なし

baseline 3/3 (iter 2-4) で連続 100% 達成 → hold-out D で 100% 達成。差 ±0pt。iter 2-4 の追記が「確認済み事実への断定回答」を阻害しないことを実地確認。

### iter 2「既定の対処」追記の妥当性確認

iter 2 で追加した「既定の対処: 不確実な箇所を `[要確認]` で明示しつつ出力する」は、「既定 = 常に」ではなく「不確実の場合の既定」と正しく subagent に解釈された。過剰発動 (全出力にマーカー付与) への誘導なし。

### hold-out で得た knowledge: 一次ソース参照粒度の自然な落としどころ

subagent は L38 注記を根拠に「ドメイン + セクション名」を選択。フル URL (`https://requests.readthedocs.io/en/latest/user/quickstart/#timeouts`) ではなく `requests.readthedocs.io` + 「Quickstart」等の**人間可読なセクション名**で引用することで、WebFetch 不可環境でも一次ソース到達性を担保しつつ、深い URL の「確認できない」問題を回避。

## 収束判定

| 判定基準 | 達成 |
|---|:---:|
| 連続 3/3 ([critical] 全 ○) | ✅ iter 2 / iter 3 / iter 4 |
| hold-out パス (誤発動回避 + 過適合なし) | ✅ D 4/4 |
| tool_uses / duration ばらつき | ✅ iter 4 は全 1 回、±15% 以内 |
| 不明瞭点の自力処理 | ✅ 残存 4 件はすべて自覚 + 裁量処理 |

**hallucination-prevention 収束完了** ✅

## 次アクション (本 rule 終了後)

- [x] hold-out.md 作成
- [ ] claude/rules/hallucination-prevention.md の iter 4 時点版をコミット対象として確定
- [ ] .claude/progress.md 更新 (rules 1 本目完了 → 2 本目 implementation-policy へ)
- [ ] ユーザーに commit / push / PR 依頼 (本 branch: `refactor/rule-hallucination-prevention-tuning`)
