# hold-out — test-coverage-guard (シナリオD)

iter 2 で連続2クリア (典型スキル目標) 到達。hold-out として **シナリオD = 発動すべきでない場面 (TDD 委譲)** を single subagent dispatch し、overfit 判定を行う。

## 対象

- スキル: `claude/skills/test-coverage-guard/SKILL.md` (iter 2 時点)
- シナリオ: `docs/tuning-logs/test-coverage-guard/scenarios.md` D
- 目的: 「`calculateDiscount` のテストを書いてくれ」= テスト新規作成依頼。SKILL.md L22「非対象 (委譲先): テスト新規作成 → `test-driven-development`」の自然適用を試す

## 結果サマリ

| 項目 | 結果 |
|---|---:|
| 精度 | 5/5 (100%) |
| [critical] | 2件 ○○ |
| tool_uses | 0 |
| duration | 13.5s |

**hold-out パス、overfit 兆候なし** ✅

## 要件別観察

| # | 要件 | 判定 | 備考 |
|---|---|---|---|
| 1 | [critical] 本スキル非発動・TDD 委譲明示 | ○ | 冒頭で「非対象です。test-driven-development スキルに委譲します」と明言 |
| 2 | [critical] テスト作成依頼であることを認識 | ○ | 「本件の性質 = テスト作成 (RED → GREEN サイクル)」と分類 |
| 3 | 責務境界の明示 | ○ | 表で「本スキル = GREEN 後の信頼性検証」「担当 = test-driven-development」を対比 |
| 4 | RED/GREEN/網羅性設計を TDD 側に委ねる | ○ | 「境界値・異常系の洗い出しは TDD 側で実施」と明記 |
| 5 | 本スキルは「GREEN 後の信頼性検証」と明示 | ○ | 表および次アクション2で2回言及 |

**偽陽性スキャン・ミューテーション・テストダブル検証は非実行** (非対象判定を先に出して Step 2 以降を抑制)。

## overfit 判定

| 基準 | 判定 |
|---|---|
| baseline 平均精度 (iter 2) | 100% (18/18) |
| hold-out 精度 | 100% (5/5) |
| 差分 | ±0pt |
| overfit 閾値 (-15pt) | 超過なし |

**overfit 判定: なし**。SKILL.md の非対象 → 委譲フローがシナリオ D で自然適用され、TDD 側に `calculateDiscount` 仕様ヒアリング + RED 誘導を引き渡した。

## TCG-0-4 (委譲フォーマット未規定) 観察

iter 1 で「hold-out D で要検証」として保留された懸念を、このシナリオで最終検証:

- subagent は裁量補完箇所として TCG-0-4 を**自ら申告**: 「非対象時の応答形式」規定が SKILL.md にない
- 実際の応答は穏当な形 (表 + 次アクション 2 ステップ + 仕様ヒアリング) に着地。SKILL.md「関連スキルとの連携」節の精神から推測して「GREEN 後の再発動フロー」を案内
- 実害: **低**。裁量補完が SKILL.md の目的節・責務分担表の精神に整合しており、ユーザーにとっても次の動きが明確

**TCG-0-4 は「SKILL.md 未規定だが subagent の裁量で穏当に処理される曖昧さ」として残置許容**。iter 3 のテーマには昇格させない (中核 3本柱に影響せず、明文化すると SKILL.md 肥大化)。

## 残存不明瞭点 (hold-out 新規)

- **TCG-D-1**: GREEN 後の再発動案内を入れるべきかの規定不在 (subagent は「関連スキル連携」節の精神から推測して追加)
- **TCG-D-2**: 仕様ヒアリング (割引率テーブル・境界条件・入力型) は TDD の責務か本スキルの非対象応答に含めるかの規定不在

いずれも周辺運用詳細。中核 (非対象判定 → 委譲明示) は揺るがず。

## 収束判定

| 判定軸 | 結果 |
|---|---|
| 連続クリア 2/2 (典型スキル) | ✅ iter 1 + iter 2 |
| hold-out overfit なし | ✅ 100% → 100% |
| 中核 3本柱の安定 | ✅ 偽陽性スキャン / ミューテーション / テストダブル分類 |

**test-coverage-guard スキル収束完了** ✅

## 次スキル (Phase 2 順序)

- **refactoring** (ブランチ未作成、scenarios.md 未作成)
- iter 0 着手: description/body 整合チェック
- 収束目標: 連続 2 (典型スキル)

## observer note

- hold-out duration 13.5s は baseline シナリオ C (21.8s) より -38%。**非対象判定で早期離脱した効果**。Step 2 以降を実行しないため短絡した
- TCG-0-2 (トリガー接続規則) は hold-out でも誤発動なし。トリガーキーワードに「テストレビュー」「テスト削除」等が並ぶが、「テストを書いてくれ」は委譲キーワードと整合し混乱なし
- description 文「既存テストの信頼性を検証し、偽陽性を検出・排除するガードレール」が「既存」「検証」「偽陽性」と 3 語で非対象 (新規作成) を自然除外。iter 0 で description 修正不要と判定した判断が結果的に正しかった
- 3連続 overfit 試験不要 (典型スキル目標は連続2 + hold-out)。systematic-debugging / tdd (重要スキル = 連続3 + hold-out) より軽量
