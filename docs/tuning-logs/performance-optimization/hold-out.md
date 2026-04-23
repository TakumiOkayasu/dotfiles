# hold-out — performance-optimization

## シナリオ D（バグ修正依頼 = 発動すべきでない）

**状況**: `calculate_total` が時々マイナスを返す / 処理時間は正常（100ms 以内）

**期待**: 非発動判定 → systematic-debugging / tdd へ委譲

## 実行結果

| 指標 | 値 |
|---|---|
| 成功/失敗 | ○ |
| 精度 | 100%（6/6） |
| tool_uses | 1 |
| duration | 34.0s |
| retries | 0 |

**前回平均比** (iter 3 外れ値除外 49.6s): duration **-31.5%**（早期離脱）

## 要件達成

| # | 要件 | 判定 | 理由 |
|---|---|:---:|---|
| 1 | [critical] skill 発動せず systematic-debugging / tdd へ委譲 | ○ | 明示的に非発動・委譲宣言 |
| 2 | [critical] 「動作誤り」と判別（処理時間正常の明記） | ○ | 100ms 以内を非該当根拠に列挙 |
| 3 | [critical] description 非該当の認識 | ○ | description + トリガー条件いずれも非該当明示 |
| 4 | 4 フェーズ経路（現象→仮説→検証→修正）提案 | ○ | 表形式で提示 |
| 5 | 修正後 TDD で回帰テスト（RED→GREEN→REFACTOR） | ○ | 経路明示 |
| 6 | 誤発動阻止（「速くしたい」系語なし） | ○ | 非該当語リスト提示 |

## 境界節の効果（iter 2 修正の最終検証）

subagent は判定結果表の「根拠」列で次を**直接引用**:

> 「関連スキル表『誤動作・バグ修正（出力が誤っている）→ `systematic-debugging` → `tdd`』に該当」

さらに「3 重根拠」で非発動を確証:
1. description「パフォーマンス最適化やプロファイリング時に使用」非該当
2. トリガー条件（遅い / レイテンシ / スループット / メモリ）いずれも非該当
3. 誤発動阻止語「速くしたい / 遅い / プロファイル / メモリ」なし

→ **iter 2 で追加した「関連スキル・境界」節が誤発動阻止コストを下げた実地確認**。refactoring / consultation / interface-first-design / e2e-browser / qa-nightmare の hold-out と同型成功パターン。

## 不明瞭点

- `items` の型（ActiveRecord / POJO）、`price` / `quantity` の型（Integer / BigDecimal / Float）
- 「マイナス許容（返品行）」か「禁止」かの仕様
- 呼び出し元・永続化層の情報

→ すべて委譲先（systematic-debugging）で扱うヒアリング事項。skill 構造曖昧ではない。

## 裁量補完

- 仮説にオーバーフロー・型混入を追加（一般的候補）
- TDD 工程を RED→GREEN→REFACTOR で明示（委譲先 skill の精神を再現）

## 過適合チェック

| 指標 | baseline 平均 | hold-out | 差分 | 判定 |
|---|---:|---:|---:|:---:|
| 精度 | 100% | 100% | ±0pt | ✅ overfit なし（-15pt 閾値に遠く及ばず） |

## 収束判定

- **performance-optimization スキル収束完了** ✅
- 典型スキル目標（連続 2 + hold-out パス）達成
- 中核 4 本柱（鉄則 / Step 1-4 / 禁止事項表 / 関連スキル境界）は安定
- 残存不明瞭点はすべて周辺運用詳細 or シナリオ情報不足由来
