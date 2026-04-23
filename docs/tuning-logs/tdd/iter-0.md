# iter 0 — tdd 静的整合チェック

dispatch なし。description と body の整合 + trigger-overlap.md の境界確認のみ。

## description（frontmatter）

> 機能実装やバグ修正でテストを書く・変更する作業に使用。RED-GREEN-REFACTORサイクルを適用する。

## body の論点一覧（H2 レベル）

トリガー条件 / 前提条件 / 鉄則 / ステップ0-4 / テストコード変更ルール / 出力形式テンプレート / AI固有の注意点 / ユーザー確認ポイント / コミット戦略 / 関連スキル / 禁止事項

## 整合チェック

| 観点 | 結果 | 備考 |
|---|:---:|---|
| description「機能実装」→ body トリガー条件 | ✅ | 一致 |
| description「バグ修正」→ body トリガー条件 | ✅ | 一致 |
| description「RED-GREEN-REFACTOR」→ body ステップ3 | ✅ | 詳細記述あり |
| body「特性テスト（ステップ4）」→ description | ⚠️ | description に言及なし（body は 40行 使っている） |
| body「適用判断（ステップ1、探索的の申告）」→ description | ⚠️ | description に言及なし（シナリオC の critical 要件の根拠） |
| body「テストコード変更ルール」→ description | ⚠️ | description に言及なし（シナリオD hold-out の critical 要件の根拠） |

**結論**: description は body を過小表現している。subagent は description から body のこれらの章に辿り着く前に、他スキル（refactoring / systematic-debugging 等）に逃げるリスクがある。ただし具体的影響は iter 1 で観測してから判断。

## 隣接スキルとの境界（trigger-overlap.md 参照）

| スキル | 境界の明示度（tdd description 内） |
|---|:---:|
| test-coverage-guard（GREEN 後検証） | ✗ 言及なし |
| systematic-debugging（バグ**前**分析） | ✗ 言及なし（description「バグ修正」だけで境界は body の関連スキル節まで行かないと分からない） |
| qa-nightmare（悪夢ケース生成） | ✗ 言及なし |
| e2e-browser（ブラウザE2E） | ✅ body 除外条件に「E2Eテストの新規作成」→「本スキル対象外」と明記（body 側のみ） |
| interface-first-design（TDD 前段、設計） | ✅ iface-first 側に「TDDスキルの前段」記載あり（受け手側） |

**結論**: tdd description は隣接スキルとの境界を全く示していない。body 末尾の「関連スキルとの連携」表まで読めば最低限分かるが、description だけ読んだ subagent には伝わらない。**iter 1 で シナリオ C（探索的仕様）や edge が混乱したら、description 側に境界の1行追記が候補**。

## iter 0 修正判断

- **iter 1 を先に実行**。iter 0 の軽微な乖離（特性テスト / 適用判断 / 変更ルールの description 未記載）で subagent が実際に詰まるかを観測してから修正方針を決める
- 事前修正の誘惑に屈しない（empirical-prompt-tuning「修正の波及パターン」節: 軸名から推測した修正は判定文言のどれにも届かない `ゼロ振れ` リスク）

## 次アクション

- iter 1: シナリオ A / B / C を新規 subagent 3並列で dispatch → 結果分析 → iter-1.md に記録
