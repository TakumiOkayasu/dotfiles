# hold-out — qa-nightmare（過適合チェック）

## 目的

iter 3-4 で「連続 2/2 + 新規 SKILL.md 起因不明瞭点ゼロ」を達成したため、baseline に含まれない hold-out シナリオで過適合を検出する。iter 2 で追加した「関連スキル・境界」節（L37-50）が誤発動阻止に機能するかを実地観察する。

## シナリオ（hold-out: ユニットテスト領域、誤発動回避）

`calculateTax(amount, rate, roundingMode)` という純粋関数のテスト要求（DB/UI/ブラウザ操作一切なし）。ユーザーは「悪夢ケースも網羅して」と言及し qa-nightmare の誤発動を誘う。**期待**: qa-nightmare 非発動 → tdd 委譲判定。

## 実行結果

| 項目 | 値 |
|---|---|
| 成功/失敗 | ○ |
| 精度 | 100% (6/6) |
| steps (tool_uses) | 2 |
| duration | 44.0s |
| retries | 0 |

全 `[critical]` 要件 ○ で成功判定。

### 要件達成

| # | 項目 | 判定 | 根拠 |
|---|---|:---:|---|
| 1 | [critical] 非発動判定 or tdd 委譲 | ○ | SKILL.md L25・L41 を引用、非発動と明示 |
| 2 | [critical] 根拠明示（URL/画面/DB なし、純粋関数） | ○ | 対象プロンプトの「DB/UI/ブラウザ操作一切なし、純粋な数値計算関数」を根拠に引用 |
| 3 | tdd 委譲 or RED-GREEN-REFACTOR 提示 | ○ | tdd SKILL.md のステップ 2-3 を参照、テストリスト案 + サイクル手順提示 |
| 4 | 「悪夢ケース」という語に引きずられない | ○ | エッジケース（負数/NaN/Infinity/浮動小数）を tdd の異常系テストリスト項目として整理 |
| 5 | 前提条件不成立の指摘 | ○ | 「対象機能名・画面URL」未提供を L34・L48 で指摘 |
| 6 | 「関連スキル・境界」節の引用 | ○ | **L37-50 を表形式で直接参照**、iter 2 追加節が hold-out で発動 |

### subagent 挙動の特徴

- **境界節（L37-50）を直接引用・表形式で整理**: 「対象粒度 / 画面・APIの有無 / 発動除外条件 / `$ARGUMENTS` 不足 / 「悪夢ケース」という語」の 5 観点でテーブル化、SKILL.md の該当行を明示
- **tdd スキル SKILL.md も能動的に Read**: 委譲先の手順を具体化するため（tdd L118「テストリスト作成後のユーザー確認」・L124-185「RED-GREEN-REFACTOR」・L235「仕様確度テンプレート」）。境界節の「委譲先スキル」列が読者を次スキルへ正しく誘導
- **test-coverage-guard を補助として提示**: 「tdd で GREEN 達成後の偽陽性検出が必要であれば」= iter 2 境界節で列挙した 4 スキルのうち 2 つを hold-out 内で活用
- **再試行 0 回**: 境界節が明快で一読で非発動判定に到達

### 不明瞭点（新出）

- `calculateTax(1050, 0.1, 'ceil')` の期待値（要件に `'round'`・`'floor'` のみ例示）→ シナリオ情報不足由来、SKILL.md 構造問題ではない
- 「悪夢ケース」という語がスキル指定意図か比喩か曖昧 → subagent は境界説明で対処（非発動判断に影響なし）

### 裁量補完

- テストリスト案の具体ケース列挙（要件は「エッジケース」と方向性のみ提示）
- 浮動小数点丸め仕様（banker's rounding か否か）は「仕様確認が必要」と留保
- tdd 手順の参照粒度は概要のみ（詳細はスキル本体に委譲）

## baseline との比較（過適合チェック）

| 指標 | baseline 平均（iter 3-4） | hold-out | 差分 | 閾値 | 判定 |
|---|:---:|:---:|:---:|:---:|:---:|
| 精度 | 100% | 100% | ±0pt | -15pt 以上で過適合 | **○ 過適合なし** |
| tool_uses | 4.0 | 2 | -50% | — | 非発動判定は本質的に短くなる、想定内 |
| duration | 87.0s | 44.0s | -49.4% | — | 早期離脱（非発動判定 + 委譲案内のみ）、想定内 |

precision 100% 維持 + 境界節の直接引用 = **iter 2 境界節の効果を hold-out で実地確認**。refactoring / consultation / interface-first-design / e2e-browser hold-out と同型の「境界節が誤発動阻止コストを下げる」パターン。

## 収束判定

- **連続 2/2 + hold-out パス = 典型スキル収束目標達成** ✅
- 過適合なし、中核 3 柱（Phase 1-3 順守 / `NM-` プレフィックス / S ランク除外禁止）は baseline でも hold-out でも安定
- iter 2 で追加した境界節（L37-50）が hold-out で直接引用され、効果を実地観察。tdd / test-coverage-guard / e2e-browser / systematic-debugging / consultation の 5 スキル委譲表が機能

## 次アクション

1. PR 化: `docs/tuning-logs/qa-nightmare/{iter-3,iter-4,hold-out}.md` + `.claude/progress.md` をコミット（SKILL.md は iter 2 で既にコミット済 = 7494df8）
2. qa-nightmare 収束完了 → **Phase 2 残: measure（典型）/ failure-logging（典型）/ empirical-prompt-tuning（構造審査）**
