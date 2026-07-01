# deep-review

<!-- thinking_hint: max | subagent_thinking_budget: security=xhigh, performance=high, maintainability=high -->

直近の変更を多角的にレビューする。セキュリティ・パフォーマンス・保守性の 3 観点を並列の subagent で検査し、優先度順に統合する。
公式 `code-review` プラグインとは別物で、3 並列 dispatch + synthesis が特徴。

`$ARGUMENTS` にレビュー対象を指定する (省略時は直近の変更)。

## トリガー語

- 「多角的なコードレビュー」「並列レビュー」「deep review」「3 視点でレビュー」
- `/deep-review` 直接起動

## 入出力

| 入力 | 内容 |
| --- | --- |
| `$ARGUMENTS` | ブランチ名・コミットハッシュ・ファイルパス (省略可) |
| `git diff` | ステージ済み + 未ステージの差分 |
| ロード済み rules | `${HOME}/.claude/rules/*` は @import 済みで context にある |

| 出力 | 内容 |
| --- | --- |
| 判定ヘッダー | `BLOCK` / `WARN` / `PASS` |
| サマリー表 | Critical / Warning / Suggestion 件数と観点内訳 |
| 統合済み指摘リスト | 重要度順、file:line + 観点タグ + 修正案 |

## 鉄則

- 全指摘に修正コードを添える。修正案なき指摘は指摘ではない
- subagent は必ず3つ起動する。起動不可なら親セッション単独レビューで代替せず BLOCK とする
- 3 並列 subagent の結果を統合し、1 つの優先度順リストに集約する
- 推測で指摘しない。実コードで確認できるもののみ扱う

## 手順

### Step 1: 差分取得

`$ARGUMENTS` 指定時はそれを使う。省略時は `git diff HEAD` → `git diff HEAD~1` の順に試行する。

### Step 2: 全体把握

変更の目的・スコープ・影響範囲を理解し、変更ファイルの import / 依存グラフを確認する。

### Step 3: 適用ルールの特定

`${HOME}/.claude/rules/*` は @import 済みで既に context にある。読み直さず、今回の差分で違反しうる具体パターンを観点別に列挙する。

- アーキ・設計・命名・テスト系 → 保守性 subagent へ
- 性能系 → パフォーマンス subagent へ
- 秘密情報・暗号・入力検証系 → セキュリティ subagent へ

プロジェクト固有の `CLAUDE.md` / `.claude/rules/` があれば追加で読み、同様に振り分ける。

### Plan Gate (Step 3 → Step 4)

3 並列 subagent dispatch に進む前に内省する:

- [ ] 差分の全体把握ができている (Step 2 完了)
- [ ] 観点別のルール振り分けが完了している
- [ ] **deep-review固有**: subagent 起動可能性を確認した (不可なら BLOCK)
- [ ] 各 subagent への入力フォーマットが固定されている
- [ ] **subagent dispatch 入力契約**: thinking_budget を明示している (security=xhigh / performance=high / maintainability=high)

詳細規約: `${HOME}/.claude/rules/phase-gate-framework.md`

### Step 4: 3 並列 subagent dispatch

`code-reviewer` subagent を 1 メッセージ内で 3 並列起動する (逐次起動は禁止、並列性が失われる)。`code-reviewer` は読み取り専用・sonnet モデルで安定した出力形式を持つため、3 並列 dispatch に適合している。
起動ツールが未ロードなら、利用可能な tool discovery で subagent / multi-agent tool を確認してから dispatch する。
tool contract 上どうしても起動できない場合は、レビューを実施せず `## 判定: BLOCK` とし、理由を `subagent dispatch unavailable` と明示する。

共通入力: Step 1 の差分全量 + Step 2 のサマリー + Step 3 で振り分けた担当観点のルール + thinking_budget 指定 (security: xhigh / performance: high / maintainability: high)。

共通出力フォーマット:

```text
### [Critical|Warning|Suggestion] <カテゴリ>
- file:line — <1 行要約>
- ❌ 現状: <該当コード>
- ✅ 修正案: <修正後コード>
- 理由: <1 文>
```

担当割り (各 subagent は担当外観点に踏み込まない):

- **Subagent 1 セキュリティ**: インジェクション (SQL / コマンド / XSS / パストラバーサル / SSRF)、認証認可漏れ、機密情報露出、入力検証、動的コード実行、CORS / CSRF、TOCTOU。判定基準は「本番障害・データ漏洩を引き起こしうるか」
- **Subagent 2 パフォーマンス**: N+1、不要な再計算、メモリリーク、非効率なデータ構造、race condition / await 漏れ、計算量。判定根拠は「実行頻度 × データ量 × 計算量」の最悪ケース。実行頻度が不明なら Warning 以下に留め計測を推奨する
- **Subagent 3 保守性**: ロード済み rules (アーキ依存方向・SOLID・エラーハンドリング・命名・テスト品質) への違反、破壊的変更、スコープ逸脱。加えて方針検証発動跡 (後述) を確認する

### Step 5: synthesis

3 subagent の findings を 1 リストに統合する。

1. 同一 file:line の指摘を集約し、観点タグを併記する
2. 重複指摘の重要度は最高位を採用する (Critical > Warning > Suggestion)
3. Critical → Warning → Suggestion の順、各内は file:line 昇順でソートする
4. 全件が単一観点に偏る場合は当該 subagent の出力品質を疑う

### Step 6: Verify Gate (自己検証)

統合済みリストの出力前に内省する。No が 1 つでもあれば該当 subagent を再 dispatch する:

- [ ] 推測指摘がない (実コードで確認できるもののみ)
- [ ] 修正案の構文が正しい
- [ ] 既存テストを壊さない
- [ ] 存在しない API を使っていない (`hallucination-prevention` 違反なし)
- [ ] 重要度が基準表に準拠
- [ ] スコープが目的に対し過不足ない
- [ ] **deep-review固有**: 3 観点全てに findings が分散している (単一観点偏重なら subagent 出力品質を疑い再 dispatch)
- [ ] **deep-review固有**: 全指摘に修正コードが添えられている
- [ ] **deep-review固有**: 方針検証発動跡の確認が完了している (該当差分の場合)

詳細規約: `${HOME}/.claude/rules/phase-gate-framework.md`

### Handoff Gate (Step 7 直前)

最終出力前に確認する:

- [ ] 3 subagent の出力を `.claude/notes/{task-id}.md` に集約済み (`## subagent: security/performance/maintainability` 形式)
- [ ] 同一 file:line の重複指摘が集約済み
- [ ] BLOCK 判定の場合、理由が明示されている (`subagent dispatch unavailable` 等)
- [ ] レビュー後の次ステップ (該当スキルへの引き継ぎ) が「レビュー後」セクションに沿って明示できる

### Step 7: 出力

下記「出力形式」で、マージ判定とともに統合済みリストを報告する。

## 方針検証発動跡の確認 (保守性 subagent)

差分が ``$HOME/.claude/CLAUDE.md`` の「着手前の方針検証」発動条件 (100 行以上の変更 / 外部依存の増減 / DB スキーマ・公開 API 変更 / 根本原因への修正 / UI 機能 5 個以上 等) に該当する場合、premise-questioning / feature-pruning の発動跡を確認する。

発動跡と認める記述 (いずれか 1 つ以上): PR 本文・コミットメッセージ・`.claude/progress.md` の判断ログ・差分内コメントに、検証結果 (✅ 採用 / skipped 等) が読み取れること。跡がない、または結論ラベルが読めない場合は Critical として指摘する。

## 重要度基準

- **Critical** — マージ不可。本番障害・データ損失・脆弱性を引き起こす/うる。セキュリティ脆弱性、データ破壊、未捕捉の致命的例外、競合状態、アーキテクチャ依存違反、破壊的 API 変更、規約の明示的禁止事項違反、方針検証スキップ
- **Warning** — マージ前に対処推奨。設計原則違反、エラー握り潰し、パフォーマンス懸念、テスト不足、命名・可読性、スコープ逸脱、非推奨 API
- **Suggestion** — 任意。許容範囲内のアルゴリズム改善、命名の微改善、テスト可読性

迷ったら上位の重要度を適用する。

## マージ判定

| 判定 | 条件 |
| --- | --- |
| BLOCK | Critical 1 件以上 |
| WARN | Critical 0 件 かつ Warning 3 件以上 |
| PASS | Critical 0 件 かつ Warning 2 件以下 |

## 出力形式

判定ヘッダー `## 判定: [BLOCK|WARN|PASS]` を先頭に置く。続けてサマリー表 (重要度 × 件数 × 観点内訳: セキュリティ / パフォーマンス / 保守性) を出し、各指摘を優先度順に列挙する。

```text
### [重要度] [観点タグ] カテゴリ
N. file:line — 要約
❌ 現状: <コード>
✅ 修正案: <コード>
理由: <1 文>
```

## 禁止事項

| 禁止 | 理由 |
| --- | --- |
| 修正コードなしの指摘 | actionable でない |
| 推測に基づく指摘 | 誤検知 |
| 「良い点」セクション | 問題発見に集中する |
| スタイルのみの指摘 | linter / formatter に委任 |
| 担当外観点への侵食 | 統合時の重複コストが増える |
| 3 並列 subagent の逐次起動 | 並列性が失われる |
| 指摘ゼロでの打ち切り | 担当観点を最後まで走査する |

## レビュー後

指摘カテゴリに対応するスキルを読んで対応する: パフォーマンス → `measure` / `optimize`、設計・保守性 → `refactoring`、方針検証スキップ → `premise-questioning` / `feature-pruning`、テスト不足 → `tdd` または `test-writer` subagent。ユーザーの許可を得てから Critical → Warning → Suggestion の順で修正する。
