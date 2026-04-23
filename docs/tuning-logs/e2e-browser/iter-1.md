# iter 1 — e2e-browser（baseline）

empirical-prompt-tuning iter 1。3 シナリオを並列 dispatch し、**baseline 評価**を記録する。

- 対象: `claude/skills/e2e-browser/SKILL.md`（327行）
- 前回差分: なし（iter 0 の段階で SKILL.md は未改訂）
- 収束目標: 連続2（典型スキル）

## 変更点（前回差分）

なし（baseline）。

## 実行結果（シナリオ別）

| シナリオ | 成功/失敗 | 精度 | steps (tool_uses) | duration | retries |
|---|:---:|---:|---:|---:|---:|
| A（ログインE2E / PostgreSQL / headless） | ○ | 90% (9.0/10) | 2 | 58.7s | 0 |
| B（既存テスト失敗調査 / reCAPTCHA） | ○ | 92.9% (6.5/7) | 1 | 54.7s | 0 |
| C（注文E2E / MySQL / novnc / 外部キー） | ○ | 93.75% (7.5/8) | 2 | 89.9s | 0 |
| **平均** |  | **92.2%** | 1.67 | 67.8s | 0 |

全シナリオ `[critical]` 全 ○ で成功判定。tool_uses 偏り（他比3-5倍）なし。

### 要件別詳細

**シナリオA (10項目)**: ○=8, 部分的=2
- 部分的=要件1（Docker 不能環境のため Phase 0-1 / 1 / 3 / 5 未実行 = 制約通り）
- 部分的=要件7（`last_login_at` 検証は `getDb().whereNotNull()` で実装 = SKILL.md L258-276 の「dbAssert で不可能な検証」パターン準拠）

**シナリオB (7項目)**: ○=6, 部分的=1
- 部分的=要件1（systematic-debugging 境界が概念的記述に留まる、auto-load 禁止制約下での限界）

**シナリオC (8項目)**: ○=7, 部分的=1
- 部分的=要件4（MySQL テンプレート本体 `$E2E_DATA/compose-templates/mysql.yml` の実内容を SKILL.md から読めず、推定で書いた）

## 不明瞭点（今回新出）

### ⭐ 最重要

- **EB-1-AC-1**: `docker-compose.e2e.yml` の DB 別テンプレートが `$E2E_DATA/compose-templates/` にあるとされるが body に inline されておらず、subagent は推定で生成（A / C 両方で独立報告、2 subagent 独立 = 構造的曖昧）
- **EB-1-A-1**: fixture 配列順について SKILL.md L162「外部キー親→子」と L163「afterEach(cleanup) で事前空化前提」を読んだ上で、subagent A は **逆（子→親）で生成** した。理由「`seed` は配列順に空化→insert で、子を先に空化しないと親の DELETE 時 FK 違反が怖い」と自己申告 → **L162 と L230（cleanup = 子→親）の方向逆転が subagent 混乱の直接原因**。実害: シナリオA fixture が仕様違反

### 中（隣接スキル境界）

- **EB-1-B-1**: Phase 4 失敗調査フローの手順番号が箇条書き3項目のみで、systematic-debugging との境界（原因分析 vs 再現修正）が SKILL.md 単体から読み取れず、subagent B は概念記述で補完
- **EB-1-A-2**: helpers の import 相対パス（`../../helpers/`）のディレクトリ配置元（`$E2E_WORK/helpers/` が何によって配備されるのか）が body に明記なし
- **EB-1-C-1**: `playwright.config.ts`（`workers: 1` を書く場所）の生成手順が body になく、subagent C は注記形で補完

### 軽微

- **EB-1-A-3**: `captureState` と「待機 only ステップ」（例: `waitForSelector`）の使い分け基準が薄い（シナリオB で能動操作でない待機を `captureStep` に入れるか `captureState` に入れるか判断）
- **EB-1-C-2**: `DB_CLIENT` の値（`pg` / `mysql2` / `mssql` / `sqlite3`）が Knex ドライバ名に従う必要があるが body に列挙なし

## 裁量補完（今回新出）

- **シナリオA**: `data-testid` 値（`login-email` / `login-password` / `login-submit`）の仮置き + `[要確認]` 注記、login API パス `/api/login`、パスワード値、`waitForURL(/\/dashboard$/)` による遷移待機、fixture 配列順（sessions→users で誤選択）、`afterEach(cleanup)` 対象テーブル
- **シナリオB**: `Promise.all(waitForResponse, click)` 並列化パターン、`status === 200` → `request().method() === 'POST'` への変更、アプリ側 reCAPTCHA バイパス有無での案A/B 分岐、testid プレースホルダ扱い
- **シナリオC**: 商品 UI の `data-testid`（`product-100` / `quantity-100` 等）仮置き、注文完了 URL 待機 `waitForURL(/\/orders\/\d+\/complete/)`、orders/order_items を空配列 + `truncate: true` で事前クリーン担保、`DB_CLIENT=mysql2` 選択、`playwright.config` での `workers: 1` 位置判断

## empirical-prompt-tuning 側の曖昧点

- **シナリオA**: Phase 3 / 5 の docker 実行不可指示下で「生成物は提示のみ vs 実ファイル書込も可」の解釈、要件7「dbAssert を使う」が `dbAssert.exists/columnEquals` のみ必須かの粒度
- **シナリオB**: auto-load 禁止下で「systematic-debugging との境界を示す」の到達点、「生成物提示までで停止」の範囲（既存テスト修正なので新規生成物不要と判断したが要確認）、要件評価粒度
- **シナリオC**: 「実ファイル生成は不要、テキストで示せばよい」で `.env.e2e` 等の実ファイル書込も不要かの最終確認、`playwright.config.ts` の生成手順がプロンプトにもなく判断必要

## iter 2 テーマ選定

### 候補評価

| 候補 | 実害度 | 修正量 | 波及期待 |
|---|:---:|:---:|:---:|
| **EB-1-A-1** fixture/cleanup 列挙順の親子対比を明文化 | **高**（subagent A で実地誤生成） | 小（1-5行） | 中（fixture 節のみに効く） |
| EB-1-AC-1 docker-compose テンプレート inline | 中（2 subagent 独立） | 大（DB別 4種 × 30行 = 120行） | 中 |
| 隣接スキル境界節新設 (qa-nightmare / tdd / systematic-debugging) | 中（B の sd 境界で実害） | 中（refactoring iter 2 型、10-15行） | 高（複数軸に同時） |

### 選定: EB-1-A-1（fixture/cleanup 列挙順の親子対比を明文化）

**理由**:
- **実害最大**: シナリオA subagent が L162「親→子」を読みながら逆方向（子→親）に生成した。SKILL.md L162 と L230 の方向逆転が直接の混乱源、因果が明瞭
- **最小修正**: fixture 節末尾に「cleanup 節は逆方向」対比を 1-3 行追加、または対比表（3-5行）で対応可能
- **リスク低**: 既存記述の補強のみで他節への波及なし、副作用が出にくい
- **iter 3 で隣接スキル境界節を扱えば波及を狙える**: refactoring iter 2 / consultation iter 2 の成功パターン踏襲余地を残す

EB-1-AC-1（docker-compose テンプレート inline）は修正量が 1 iter の 1 テーマの範囲を超える（DB別 4種の YAML 記述 = 本体の 30% 近い増量）ため iter 4+ 以降に温存。

### 修正案（iter 2 差分）

SKILL.md L160-166 のブロック末尾に対比表を追加:

```markdown
**fixture (seed) と cleanup の列挙順対比**:

| 操作 | 列挙順 | 理由 |
|------|--------|------|
| seed (fixture) | **親 → 子** | insert 時に FK 子側が親を参照できる。DB が空（初回 or afterEach 後）なら親側の DELETE でも FK 違反は起きない |
| cleanup | **子 → 親** | DELETE 時に子を先に消さないと親が消せない (MySQL/SQL Server では明示必須、PG は CASCADE で省略可) |
```

4 行追加（ヘッダ1 + 本文3）。fixture 節（L140-166）と cleanup 節（L230）の方向逆転を明示することで、subagent が「どちらかを逆にする」誘惑を構造的に断つ。

## 次アクション

- iter 2: 上記 4 行追加 → 3 並列再評価（新規 subagent、シナリオ A/B/C 同一）
- 期待: シナリオA fixture 列挙順が正しく生成される、精度維持、tool_uses 変動なし、duration +5% 以内
- 連続 1/2 達成（iter 2 が初の「前回比」評価）

## 収束判定

- 連続 0/2（iter 1 = baseline、カウント開始 iter 2 から）
- 停止条件まで最短 2 iter
