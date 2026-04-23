# hallucination-prevention iter 0: rule 間重複・矛盾 + 自己完結性チェック

**モード**: 静的 (dispatch なし、rules 版 iter 0 再定義)
**実施日**: 2026-04-23
**対象**: `claude/rules/hallucination-prevention.md` (79 行)

## 再定義: rules 版 iter 0

skills 版 iter 0 (description ↔ body 整合) は rules に直接適用不可 (description / trigger なし、常時ロード)。rules 版は以下を静的チェック:

1. **rule 間の用語重複・矛盾** (grep クロス参照)
2. **自己完結性** (rule 名と本文だけで subagent が適用可能か)
3. **スコープ宣言と処理手順のギャップ**
4. **参照する記法・概念が隣接 rule / skill と整合するか**

## クロス参照結果 (grep 抽出)

| ファイル | 該当行 | 文言 |
|---|---|---|
| `rules/coding-conventions.md` | L227 | YAGNI「将来の要件を推測して作らない」 |
| `rules/hallucination-prevention.md` | L3 / L12 / L46 / L57 / L66 / L79 | 「不確実」「推測」「要確認」「未確認」の定義と使用例 |
| `skills/refactoring/SKILL.md` | L140 | テンプレ内で `[要確認]` 例示 |
| `skills/interface-first-design/SKILL.md` | L34 | **`hallucination-prevention` rule 準拠を明示参照**、`[要確認: <不明点の具体>]` 記法 |

## 懸念点 (iter 1 で検証する候補)

### HP-0-1: スコープ宣言と処理手順のギャップ (最有力、iter 2 候補)

- L3: 「『たぶん正しい』で出力禁止。不確実なものは不確実と明示」(スコープ: AI 生成物全般)
- L14-44: 処理手順は「コード生成 (ステップ1)」「情報提供 (ステップ2)」「設定/コマンド (ステップ3)」の 3 軸限定
- **ギャップ**: 要約テキスト / 設計判断文 / 非構造化説明 (「〜のはずです」のような自信表明文) が 3 軸いずれにも該当しない。宣言 (L3) は広範、手順は 3 軸限定
- iter 1 シナリオ B / C は設定コマンド系なのでステップ3 で拾えるが、**自然言語の自信表明** を扱うシナリオがない。iter 1 の挙動で要検証

### HP-0-2: 「出力しない」vs「`[要確認]` 付き出力」の関係未定義

- L12: 「不確実な箇所は `[要確認: <理由>]` で明示」 = 出力する
- L50-53 ステップ4: 「出力しない → 代替案 → 確認方法 → 訂正」 = 出力しない系 4 段階
- **矛盾**: `[要確認]` で出力することが「出力しない」と整合しない。L12 と L50 の関係が subagent 解釈に委ねられる
- 潜在リスク: subagent が「出力しない」を鉄則化すると `[要確認]` マーカーが不発動 / 過剰保守 (回答拒否) に振れる

### HP-0-5: 検証手段と実行手段の紐付けなし (中程度)

- L22-28 ステップ1: 「公式レジストリで確認」「公式リファレンスで確認」「リリースノートで確認」
- **欠落**: Claude Code 環境での実行手段 (WebFetch / WebSearch / `gh api` / `docker run --rm` 等) への紐付けなし
- subagent は「公式ドキュメントを確認」と書くだけで実地検証しない可能性 = 名目的確認に留まる

### HP-0-7: `[要確認]` 記法の理由欄粒度規定なし

- L12: `[要確認: <理由>]` 形式のみ
- L66 / L79 例: 「公式ドキュメント参照」「バージョン X.Y のリリースノートで確認してください」
- 隣接 skill `interface-first-design` L34: **「`[要確認: <不明点の具体>]`」で「不明点の具体」という粒度を強制**
- **不整合**: 本 rule が例示のみで粒度規定なし、参照元の iface skill の方が厳密 (下位が上位を強化する逆転現象)

### HP-0-8: ユーザー環境バージョン確認の具体手段なし

- L28: 「ユーザー環境のバージョンで利用可能か」
- **欠落**: lockfile (package-lock.json / poetry.lock / Cargo.lock) を読むべきか、version manager (asdf / mise / fnm / .nvmrc / .python-version) を見るべきか、ランタイム直接実行 (`node --version`) で確認するかの指針なし
- CLAUDE.md 側の「ランタイム直接実行禁止」ルールと整合するため、version manager 優先が本来の書き方

### HP-0-3 (残置候補): 「推測」語の rule 間用途差

- `coding-conventions.md` L227 YAGNI「将来の要件を推測して作らない」(設計判断)
- `hallucination-prevention.md` 全体「存在確認の推測禁止」(事実確認)
- **残置理由**: 語は同じだが文脈で区別可能、subagent が誤適用する実害は低い。明文化すると両 rule 肥大化

### HP-0-4 (残置候補): 使用例の粒度偏り

- L55-79 使用例は Python コード例 1 つ + 口語例 1 つ
- 設定/コマンド系 (ステップ3) の具体例なし
- **残置理由**: 使用例を増やすと肥大化、かつ iter 1 で設定コマンドシナリオ (C) が挙動を炙り出すので iter 1 以降で要判断

## iter 1 で集中観察する点

- シナリオ A で `axios` vs `axios-retry` の存在確認過程が適切か
- シナリオ B で import attributes / assertions のバージョン境界を **一次ソース引用で提示するか、`[要確認]` で保留するか**
- シナリオ C で `gh pr view --comments` の存在確認を **`gh --help` 実地確認する指示を出すか**
- hold-out D で `[要確認]` マーカーを**不要に付けない**か (rule 過剰発動判定)

## 収束目標

重要 rule (hallucination-prevention は他 rule の前提) → **連続 3 回 + hold-out パス**

## 次アクション

- [x] scenarios.md 作成
- [x] iter-0.md 作成
- [ ] iter 1: baseline 3 並列 dispatch (A / B / C)
- [ ] iter-1.md に結果記録
- [ ] iter 2+ で 1 テーマ修正 → 再評価
- [ ] hold-out D
