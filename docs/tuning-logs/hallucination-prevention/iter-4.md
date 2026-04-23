# hallucination-prevention iter 4: L38 注記末尾にコマンド引数内 REST API パス例外追記 → 3 並列再評価

**実施日**: 2026-04-23
**SKILL.md (rule) 変更**: L38 注記末尾に「コマンド引数中に現れる REST API パス (例: `gh api repos/{owner}/{repo}/pulls/{n}/comments`) は**コマンド仕様の一部**として扱い、URL 提示制限の対象外」を 1 文追加
**連続クリアカウント**: **3/3** ✅ (重要 rule 目標到達)

## 実行結果 (シナリオ別)

| シナリオ | 成功/失敗 | 精度 (critical) | ステップ数 | duration | retries |
|---|:---:|:---:|:---:|---:|:---:|
| A (axios retry) | ○ | 2/2 = 100% | 1 | 46.9s | 0 |
| B (Node import attributes) | ○ | 2/2 = 100% | 1 | 52.3s | 0 |
| C (gh CLI PR comments) | ○ | 2/2 = 100% | 1 | 36.4s | 0 |
| **平均** | **○** | **100%** | **1** | **45.2s** | **0** |

全 [critical] 達成、tool_uses 全 1 に揃う、duration は iter 3 (52.3s) 比 -13.6% (A=2→1 回復と B 若干増の相殺で平均改善)。iter 1 (37.4s) 比 +20.9%。

## HP-3-X-1 (REST API パス境界) の解消確認

iter 4 追記は**コマンド引数内の URL-like パス**への `[要確認]` 過剰付与を抑制する狙い。結果:

- **subagent C** (gh CLI): `gh api repos/<owner>/<repo>/pulls/123/comments` を**マーカー付与なしで主提案**。iter 3 では同じパスに「コマンド仕様の一部かパス断片か」と迷っていた部分が、iter 4 では迷いなく提示。裁量補完にも関連言及なし (=構造的に解決)。
- **subagent A** (axios): 該当しない (URL 以外のオプション名が主)
- **subagent B** (Node): 該当しない (import 構文が主)

副作用なし。duration は A=46.9s (iter 3 A=62.3s から -24.7%) で最大の改善、lockfile 確認 bash 呼び出しも発生せず tool_uses=1 に回復。

## 不明瞭点 (iter 4 時点)

### HP-4-X-1: L38 パス断片の粒度境界 (3 subagent 指摘、軽微・自覚)

3 subagent すべてが「パス断片と深い URL の境界」を自覚的に指摘:
- A: `github.com/softonic/axios-retry` を「パス断片」として `[要確認]` 付与で保守
- B: `github.com/tc39/proposal-import-attributes` をドメイン root 参照に止め深い URL 回避
- C: `docs.github.com/en/rest/pulls/comments` をスキーム付きフル URL でなければパス断片扱いと整理

iter 3 からの継続指摘だが、**実害ゼロ** (全 subagent が保守的に裁量運用で統一)。3 回連続指摘 = 構造問題というより「自覚的な注意喚起」として機能している。Rule 本文側では追加の説明は不要と判断 (追加すると冗長化し duration 悪化リスク)。

### HP-4-C-1: L50 既定 vs L52-55 追加対処の切替閾値 (subagent C)

subagent C: 「4 項目が**追加**対処なのか**置換**対処なのかは L50 本文で『追加対処』と明記されているため解釈迷いは小さいが、どのケースで 4 項目側に切り替えるかの閾値は個別判断」。

iter 2 の HP-2-A-3 (subagent A 単独指摘) の再浮上。今回は C 単独指摘。B-1, A-2 では迷わなかったため**個別判断で処理可能な範囲**と評価。優先度中。

### HP-4-B-1: L18「否なら保留」vs L50「既定: マーカー付き出力」の優先関係 (subagent B、iter 1-3 残存)

subagent B: 「ステップ1 の表はコード生成固有の厳格フィルタと解釈し、ステップ 4 の既定対処 (マーカー付き出力) を採用。判断が分かれやすい箇所」。

iter 1 HP-1-A-1 / iter 2 HP-2-A-1 / iter 3 と継続指摘。iter 2 の「既定の対処」追記で大部分は吸収されたが、subagent B はなお「ステップ1 vs ステップ4」の構造上の切り分けに引っかかる。**自己解釈で処理可能** (全 iter で精度 100% 維持) だが、根本解決にはステップ1 冒頭の文言変更が必要。連続 3/3 達成済のためここは hold-out 後に再判断。

### HP-4-B-2: L27 Deprecated チェックの扱い (subagent B、新出)

subagent B: 「import assertions が Node で deprecation 状態か否かを自力で確認できないため `[要確認]` で保留。ルール上これが『否』扱いなら出力保留だが、代替案併記で対応可と解釈した」。

iter 4 新出。ステップ1 の L27「非推奨 (Deprecated) ではないか」が WebFetch 不可環境でどう扱われるかの指摘。subagent B 単独かつ裁量で処理済。優先度低。

## 裁量補完 (今回新出)

- subagent A: `npm install` コマンドを「ユーザー自身が実行する確認手順」として提示 (Claude 自身の install 実行は回避)、リトライ条件 (`retryCondition`) デフォルトの冪等性重視、CJS 選択
- subagent B: パターン A/B 併記 + 代替 (`createRequire` / `fs.readFile`) + 構文実地テストコマンド提示、実地確認手段を 7 種 (asdf / mise / volta / fnm / .nvmrc / node --version / 構文テスト) 提示
- subagent C: 3 種別分解 (review / reviews / issue)、`--paginate` 追加、`gh --version` 検証手順追加

## 分析

### 最重要: 連続 3/3 達成 ✅

重要 rule (hallucination-prevention は他 rule の前提) としての目標到達:
- iter 2 (既定の対処): L12 vs L50 整合
- iter 3 (URL 範囲): L36 提示基準明文化
- iter 4 (REST API パス例外): コマンド引数内の URL-like パス迷い解消

本 rule はコード生成の前提として全スキルが暗黙参照するため、連続 3 基準での収束は妥当。

### 観察: 残存の不明瞭点 4 件はすべて「自覚 + 裁量処理」

HP-4-X-1 / HP-4-C-1 / HP-4-B-1 / HP-4-B-2 はすべて subagent が自分で気付き、自分で整理して処理している。精度への影響ゼロ。本文の追加説明は **duration コストと肥大化リスクに見合わない**と判断し、hold-out D に進む。

### 観察: duration リバウンド成功

iter 1: 37.4s → iter 2: 43.6s (+16%) → iter 3: 52.3s (+40%) → iter 4: 45.2s (+21%)。iter 4 の 1 文追記で duration が iter 2 水準近辺まで戻った。大量追記による思考コスト膨張は避けられている。

## 次アクション

- [x] iter-4.md 作成
- [ ] hold-out D: 確認済み一般知識 (`requests.get(url, timeout=30)` の timeout 引数) への過剰 `[要確認]` マーカー回避シナリオ評価
- [ ] PR 準備 (連続 3/3 + hold-out パス条件)
