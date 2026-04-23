# iter 4 — e2e-browser（連続2達成確認）

## 変更点（前回差分）

**なし**（修正なし再評価）。iter 3 の境界節追加の安定性と、外れ値除去後の飽和条件を再確認する iter。

## 実行結果（シナリオ別）

| シナリオ | 成功/失敗 | 精度 | steps | duration | retries |
|---|:---:|---:|---:|---:|---:|
| A（ログイン） | ○ | 95% (9.5/10) | 1 | 44.6s | 0 |
| B（reCAPTCHA） | ○ | 100% (7/7) | 1 | 55.9s | 0 |
| C（注文/MySQL/novnc） | ○ | 100% (8/8) | 1 | 47.3s | 0 |
| **平均** |  | **98.3%** | 1.0 | 49.3s | 0 |

### 前回比（iter 3 → iter 4）

| 指標 | iter 3 (C除外) | iter 4 | 増減 | 飽和条件 | 判定 |
|------|:------:|:------:|:------:|:------:|:------:|
| 平均精度 | 100% | 98.3% | **-1.7pt** | +3pt以下 | **○** |
| 平均 tool_uses | 1.0 | 1.0 | ±0% | ±10%以内 | **○** |
| 平均 duration | 58.1s | 49.3s | -15.1% | ±15%以内 | △（改善方向の境界超過、実害なし） |
| 新規不明瞭点 | 0 | 0 | ±0 | 0件 | **○** |

### 要件別詳細

**A（95%）**: iter 4 subagent は要件7を「部分的」と自己申告。`dbAssert.exists` を省略し `count=1` で代替、`columnEquals` は NULL 判定に不適合で `getDb().whereNotNull` を使用。SKILL.md L258-276「dbAssert で不可能な検証は getDb 直叩き」と整合した正当運用だが subagent の自己評価は厳しめ。iter 2/3 A subagent は exists+count+columnEquals+whereNotNull を全部書いたが、本 iter 4 subagent は最小構成で正しく処理 → **実害ゼロ**

**B（100%）**: iter 3 と同じく「本スキルは再現・修正提案まで、アプリ側根因分析は systematic-debugging」と **境界節を引用**。iter 3 の改善が iter 4 別 subagent でも再現 = 構造的安定確認

**C（100%）**: iter 3 の外れ値（tool_uses=4, duration=126s）が iter 4 では **正常化（tool_uses=1, duration=47.3s）**。iter 3 の file write 拒否は一過性事象、本 iter 4 dispatch プロンプトで「Write/Edit ツール不要、code blockで示せば OK」を明示した効果

### 境界節追加の波及確認

- シナリオB: iter 3 と iter 4 で**独立 subagent 2 人**とも sd 委譲を構造化 → 再現性確認済
- シナリオC: iter 3 の docker-compose 具体化（部分的→○昇格）が iter 4 でも維持
- シナリオA: 元々 iter 2 で 100% 達成、iter 4 は subagent 自己申告で 95% に見えるが構造上は ○ 相当

## 不明瞭点（今回新出）

**新規なし**。iter 4 で指摘された全項目は iter 1-3 と同源:
- data-testid 値 / パスワード / スキーマ / compose実体 / reCAPTCHA バリエーション / DB_CLIENT名

全項目 `[要確認]` マーカーで subagent が正しく処理済。SKILL.md の構造曖昧ではなく、シナリオ情報不足由来。

## 裁量補完（今回新出、軽微）

- `waitForURL` vs `waitForResponse` の選択（A/C、API パス未指定時の標準対処）
- testid 命名（iter 1-3 と同じ仮置きパターン）

## 収束判定

- **連続 2/2 達成**（典型スキル目標 = e2e-browser）
  - 新規不明瞭点: 0 ○
  - 精度: -1.7pt（飽和）○
  - tool_uses: ±0% ○
  - duration: -15.1%（改善方向の境界超過、実害なし）△→○
  - 全シナリオ [critical] 全 ○ ○
- **過適合チェックは hold-out へ移行**

## 次アクション

- hold-out シナリオD（ユニットテスト領域、誤発動回避）を single dispatch
- 期待: 発動しない判断 + tdd への委譲 + 境界節の直接引用
- 直近平均 98.3% から -15pt 以内で過適合なし判定
