# hallucination-prevention iter 3: L36 URL 範囲明文化 → 3 並列再評価

**実施日**: 2026-04-23
**SKILL.md (rule) 変更**: ステップ2 の URL 行を「確認できないURLは提示しない (下記注記参照)」に変更し、直下に「**『確認できない』の定義**」注記を追加 (ドメイン root + パス断片は公知の参照先として提示可、深いフル URL は `[要確認: 実在確認推奨]` 付与)
**連続クリアカウント**: **2/3** (重要 rule 目標は連続 3)

## 実行結果 (シナリオ別)

| シナリオ | 成功/失敗 | 精度 (critical) | ステップ数 | duration | retries |
|---|:---:|:---:|:---:|---:|:---:|
| A (axios retry) | ○ | 2/2 = 100% | 2 | 62.3s | 0 |
| B (Node import attributes) | ○ | 2/2 = 100% | 1 | 47.5s | 0 |
| C (gh CLI PR comments) | ○ | 2/2 = 100% | 1 | 47.2s | 0 |
| **平均** | **○** | **100%** | **1.33** | **52.3s** | **0** |

全 [critical] 達成、duration は iter 2 (43.6s) 比 +19.9%、iter 1 (37.4s) 比 +39.8%。tool_uses は A のみ 2 (lockfile 不在確認で bash を 1 回追加)、B/C は 1。

## HP-2-X-1 (L36 URL 提示範囲) の解消確認

3 subagent すべてが iter 3 追記 (L38 注記) を**本文参照ガイダンス**として使用:

- **subagent A** (axios): 「L38 注記『**ドメイン root** および**パス断片** は公知の参照先として提示してよい。深い具体的 URL (`https://...` フルパス) を提示する場合は `[要確認: 実在確認推奨]` を付ける』— `axios-http.com/docs/req_config` は境界上。保守的に `[要確認: 実在確認推奨]` を付けた」
- **subagent B** (Node): 「L38『**パス断片** (例: `docs.github.com/en/rest/pulls/comments`) は...提示してよい』: TC39 proposal リポジトリパス (`github.com/tc39/proposal-import-attributes`) が『パス断片』か『深い具体的 URL』かの境界が曖昧。リポジトリパスまでは断片扱いとし、念のため `[要確認: 実在確認推奨]` を付記」
- **subagent C** (gh CLI): 「L38『ドメイン root およびパス断片は公知の参照先として提示してよい』— パス断片の粒度が曖昧。`docs.github.com/en/rest/pulls/comments` は断片扱いで OK と判断」

全 subagent が**ルール本文の該当行を特定し、その文言を判断基準に据えた**。iter 1-2 で裁量に任されていた「URL 提示するか否か」が、構造的に「ドメイン root / パス断片 / フル URL」の 3 層分類で判断可能になった。

結果として URL 提示数が増え (A: 5 URL、B: 7 URL、C: 6 URL)、一次ソース参照手段の具体化が iter 1-2 比で大幅向上。

## 不明瞭点 (iter 3 時点で新出)

### HP-3-X-1: 「パス断片」vs「深いフル URL」の境界 (3 subagent 独立指摘)

iter 3 追記の文言そのものに起因する副作用。3 subagent が共通して境界の曖昧さに気付いた:

- subagent A: `axios-http.com/docs/req_config` (2 階層パス) の扱い → 保守的に `[要確認]` 付けた
- subagent B: `github.com/tc39/proposal-import-attributes` (リポジトリパス) の扱い → リポジトリパスは断片扱いと解釈
- subagent C: **コマンド引数中の REST パス** (例: `gh api repos/.../pulls/{n}/comments`) がパス断片扱いかコマンド仕様の一部か

C の指摘が最も本質的: URL 提示制限は「文章中での参照」を想定しているが、コマンド引数内の URL-like パスは「コマンドの必須引数」であり区別が必要。iter 4 テーマに選定。

### HP-3-A-1: 「否 (存在しない)」vs「不確実 (未確認)」の区別 (subagent A、iter 2 HP-2-A-1 の残存)

subagent A が iter 2 に続き同じ論点を指摘。ステップ1 の「否なら保留」とステップ4 の「既定の対処: `[要確認]` で出力」の切り分け。B/C はこの点で迷わなかった (裁量で処理)。iter 5 以降のテーマ候補 (優先度中)。

### HP-3-A-2: L28「ユーザー環境のバージョンで利用可能か」の架空プロジェクト対応 (subagent A、iter 1 から残存)

iter 1 HP-1-A-2、iter 2 HP-2-A-2 に続き 3 回目の指摘。架空プロジェクト文脈での運用が未規定。subagent A 単独指摘のため優先度中。

## 裁量補完 (今回新出)

- subagent A: 方式 A/B (axios-retry / 自前ラッパ) の並列提示、バックオフ係数 (`300 * 2^n`)、ESM/CJS 選択、コメント言語
- subagent B: 3 段階フォールバック構成 (`with` / `assert` / fs)、実地確認手順テーブルの 6 項目
- subagent C: `gh pr comment` をコマンド名の動詞的意味から取得用途として除外、案C (`--json comments`) のキー名選択

## 分析

### 最重要: HP-3-X-1 (パス断片境界、特にコマンド引数中の REST パス) 解消

iter 3 で導入した文言の副作用として 3 subagent が独立指摘。C の「コマンド引数中の REST パス」は**コマンド仕様の一部**として URL 提示制限対象外と整理すれば自然に解決。最小修正 (1 文追加) で iter 4 テーマとする。

### 観察: iter 3 修正の効果範囲

修正は URL 提示の判断基準を与えただけだが、副次効果として:
- 一次ソース URL の提示数が倍増 (裁量任せから構造的に促進された)
- `[要確認: 実在確認推奨]` マーカーが定着 (フル URL 提示時の付与が全 subagent で観察)
- 成果物の **一次ソース到達性** が向上

ただし duration は +20-40% 増 (L38 注記を読み込んで適用する思考コスト)。iter 4 は最小追記 (1 文) で抑制し duration リバウンドを確認。

### 観察: HP-3-A-1 / A-2 (subagent A の 2 回連続単独指摘)

B/C は迷わず処理。A は axios の「架空プロジェクト」要件で「ユーザー環境未指定」に繰り返し引っかかる。iter 4 テーマにするには 3 subagent 独立指摘が望ましいため、iter 5 以降に保留。

## iter 4 テーマ選定

**テーマ**: L38 注記末尾に「コマンド引数中の REST API パスは URL 提示制限対象外」の 1 文追加 (HP-3-X-1 解消)

**修正案** (L38 注記末尾):

```
| URL | 確認できないURLは提示しない (下記注記参照) |

**「確認できない」の定義**: WebFetch / 実行ログで実在確認できない URL を指す。一般に知られた公式ドキュメント / レジストリの**ドメイン root** (例: `nodejs.org`, `docs.github.com`, `npmjs.com`) および**パス断片** (例: `docs.github.com/en/rest/pulls/comments`) は、パッケージ名・API 名と同格の**公知の参照先**として提示してよい。深い具体的 URL (`https://...` フルパス) を提示する場合は `[要確認: 実在確認推奨]` を付ける。コマンド引数中に現れる REST API パス (例: `gh api repos/{owner}/{repo}/pulls/{n}/comments`) は**コマンド仕様の一部**として扱い、URL 提示制限の対象外。
```

**狙い**:
- HP-3-X-1 解消 (3 subagent 独立指摘を構造的に吸収)
- コマンド構築時の迷いを消し duration リバウンド
- 新規副作用なし (追加は 1 文のみ、既存運用を広げる方向で競合しない)

**予想波及**:
- subagent C の「コマンド引数内の REST パス」迷いが消える
- `gh api` / `curl` / `docker` コマンド内の URL-like 引数への `[要確認]` 過剰付与を抑制
- 連続 3/3 達成 (重要 rule 目標到達) の見込み

## 次アクション

- [x] iter-3.md 作成
- [ ] iter 4: L38 注記末尾に REST API パス扱い 1 文追加 → 3 並列再評価 → iter-4.md (連続 3/3 確認)
- [ ] hold-out D: 確認済み一般知識への過剰 `[要確認]` マーカー回避
