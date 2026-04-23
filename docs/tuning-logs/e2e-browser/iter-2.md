# iter 2 — e2e-browser

## 変更点（前回差分）

SKILL.md L165-166 直後に **fixture (seed) と cleanup の列挙順対比表** を追加（5行）。

```markdown
**fixture (seed) と cleanup の列挙順対比** (方向が逆になる点に注意):

| 操作 | 列挙順 | 理由 |
|------|--------|------|
| seed (fixture 配列) | **親 → 子** | insert 時に FK 子側が親を参照できる。DB が空（初回 or `afterEach(cleanup)` 後）なら親側の DELETE でも FK 違反は起きない |
| cleanup | **子 → 親** | DELETE 時に子を先に消さないと親が消せない (MySQL/SQL Server では明示必須、PG は `TRUNCATE CASCADE` のため省略可) |
```

**修正意図（EB-1-A-1 対応）**: fixture 節と cleanup 節が SKILL.md 内で離れて記述されており、親→子 / 子→親 の方向逆転が subagent の混乱源だった（iter 1 シナリオA で実地観察）。fixture 節末尾に対比表を置くことで両方向を同時に視野に入れさせる。

## 実行結果（シナリオ別）

| シナリオ | 成功/失敗 | 精度 | steps (tool_uses) | duration | retries |
|---|:---:|---:|---:|---:|---:|
| A（ログインE2E） | ○ | **100%** (10/10) | 1 | 59.5s | 0 |
| B（reCAPTCHA 失敗調査） | ○ | **100%** (7/7) | 1 | 61.5s | 0 |
| C（注文E2E MySQL/novnc） | ○ | 93.75% (7.5/8) | 1 | 60.3s | 0 |
| **平均** |  | **97.9%** | 1.0 | 60.5s | 0 |

**前回比 (iter 1 → iter 2)**:

| 指標 | iter 1 | iter 2 | 増減 | 飽和条件 | 判定 |
|------|:------:|:------:|:------:|:------:|:------:|
| 平均精度 | 92.2% | 97.9% | +5.7pt | +3pt以下 | ✗（改善継続） |
| 平均 tool_uses | 1.67 | 1.0 | -40% | ±10% 以内 | ✗（大幅低下） |
| 平均 duration | 67.8s | 60.5s | -10.8% | ±15% 以内 | ○ |
| 新規不明瞭点 | - | 2件 | - | 0件 | ✗ |

→ **連続クリア: 0/2（飽和未達、改善継続中）**。

### 要件別詳細

**シナリオA**: 全 10 項目 ○。iter 1 の「部分的」2 件（Phase 0-5 Docker制約 / dbAssert のみ必須問題）がいずれも ○ 昇格。iter 2 subagent は `dbAssert.exists + columnEquals + count` を組み合わせ、`whereNotNull` 用途と住み分けを自発実行

**シナリオB**: 全 7 項目 ○。iter 1 「部分的」だった要件1（systematic-debugging 境界）が ○ 昇格。iter 2 subagent は「E2E テスト環境の整合は本スキル、アプリ実装の論理欠陥は systematic-debugging」と**自力で境界を構造化**。新追加の対比表とは無関係の自発改善（iter 1 の気付きが白紙 subagent でも再現可能な構造、という示唆）

**シナリオC**: ○=7, 部分的=1（iter 1 と同じ、docker-compose MySQL テンプレート実体不在）。fixture 列挙順は **親→子** で正解生成（iter 1 と同じ、subagent C は元々正解。対比表の追加で「より明示的な正当化コメント」が付いた）

### 対比表追加の実地効果観察

- **シナリオA iter 2**: fixture は sessions→users（子→親）で生成。ただし rows=[]（sessions）+ SKILL.md「DB が空なら親側 DELETE でも FK 違反は起きない」の組み合わせで「順序不問」と状況判断。対比表の「親→子」原則は逸脱するが **実害なし**（空配列での seed は del のみで FK 関係なし）
- **シナリオC iter 2**: fixture users→products→orders→order_items で **正しく親→子**。対比表の存在により「外部キー親 → 子の順で列挙」を裁量補完箇所で明示的に根拠化
- **cleanup 順**: シナリオA=`['sessions','users']`（子→親）、シナリオC=`['order_items','orders','products','users']`（子→親）で 2 subagent 独立で正解。対比表の右半分が効いた

## 不明瞭点（今回新出）

### 真の新規（iter 1 未観察）

- **EB-2-A-1**: helpers 側コード（`helpers/db-client.ts`, `db-seed.ts`, `screenshot.ts` 等）を subagent が生成すべきか、既存扱いかが body から読み取れず。シナリオA subagent は「呼び出し側のみ生成、helpers は既存扱い」で解決（SKILL.md「一次ソース: `db-seed.ts`」の文言から既存と推測）。**実害は低**（正解判断できた）が構造的曖昧
- **EB-2-C-1**: 検証対象テーブル（アプリが自動採番する `orders` / `order_items`）を fixture に「rows:[] + truncate:true」で含めるべきか、省略すべきか。シナリオC subagent は含める方で解決（cleanup 対象と整合するため）が body に指針なし

### iter 1 と同源の残存

- **EB-1-AC-1 残**: docker-compose テンプレート実体不在は iter 2 でも A / C で再指摘（対比表追加では解決せず、元々別テーマ）
- **EB-1-C-1 残**: `playwright.config.ts` の生成要否 / `workers: 1` の位置は iter 2 でも A / C で自発裁量補完
- **data-testid の推測可否**: iter 1 で裁量補完、iter 2 でも同じ。SKILL.md「推測禁止」と「data-testid を優先」が「値の扱い方」で交錯

### シナリオB 固有（実害なし）

- reCAPTCHA v2 checkbox / v3 invisible / Enterprise のバリエーション特定は SKILL.md の範囲外
- アプリ側のバイパス機構の有無は SKILL.md の範疇外

## 裁量補完（今回新出）

- **シナリオA**: `whereNotNull` + `columnEquals` + `count` の組合せ選択、`waitForURL` の正規表現パターン、compose 内の `extra_hosts: host-gateway`、`data-testid` 命名（`email-input` / `login-submit` / `welcome-message`）
- **シナリオB**: `expect().toBeEnabled()` 待機パターン、reCAPTCHA Google 公開テストキー `6LeIxAcTAAAAAJcZVRqyHh71UMIEGNQ_MXjiZKhI` 言及、修正優先度「テストコード待機 → 環境バイパス → アプリ改変」の順序
- **シナリオC**: 商品選択 UI の形態（チェックボックス / ボタン仮定）、数量 1/2 の選択、`created_at` の追加、`DB_CLIENT=mysql2` 選択

## empirical-prompt-tuning 側の曖昧点

- **共通**: 「生成物提示の粒度」（フルファイル vs 差分）、「helpers 側の生成要否」、「data-testid の要確認マーカーでの代替許容」
- **B 固有**: 「edge」定義（純 debug vs 仕様変更追従）、「修正方針の完成度」評価基準（差分具体性 vs 調査網羅性）
- **C 固有**: 「MySQL テンプレート使用を示す」の具体度（パス指定のみ / YAML 実体）

## iter 3 テーマ選定

### 候補評価

| 候補 | 実害度 | 修正量 | 波及期待 |
|---|:---:|:---:|:---:|
| **隣接スキル境界節新設** (qa-nightmare / tdd / systematic-debugging) | 中（iter 1 B で境界が概念記述、iter 2 で自発改善＝依存しても再現性懸念） | 中（refactoring iter 2 型、10-15行） | **高**（複数シナリオ同時） |
| EB-2-A-1 helpers / config 配置源の明示 | 低（全 subagent が正解） | 小（1-2行） | 低 |
| EB-2-C-1 検証対象テーブルの fixture 扱い | 低（subagent 判断で済む） | 小（1行） | 低 |
| EB-1-AC-1 docker-compose テンプレート inline | 中 | 大（DB別4種 ×30行） | 中 |

### 選定: 隣接スキル境界節新設（refactoring iter 2 / consultation iter 2 パターン踏襲）

**理由**:
- **波及効果高**: 1 節追加で qa-nightmare / tdd / systematic-debugging の 3 境界を同時明示、hold-out シナリオD（tdd 領域との誤発動回避）への備えにもなる
- **シナリオB の iter 1→2 改善は自発的**: 対比表は境界に無関係だったが、subagent が自力で sd 境界を書けた = 書ける subagent も書けない subagent も分岐する可能性。構造化した境界節で再現性を担保
- **refactoring / consultation の成功パターン確立済**: 10-15行の「委譲先」節新設で iter 1 懸念複数を一発解消の実績
- **1 テーマ原則遵守**: 境界という 1 軸で 3 スキルを同時扱い（関連する微修正のまとめ = L174-175 準拠）

### 修正案（iter 3 差分）

SKILL.md「概要」節（L34-41）の直後、または「前提条件」節（L24-32）の直後に「関連スキル・境界」節を新設（refactoring / consultation 前例に倣う）:

```markdown
## 関連スキル・境界

本スキルが **扱う範囲** と **委譲すべき範囲** を明示する（混用回避）。

| 依頼の性質 | 発動スキル | 理由 |
|-----------|-----------|------|
| ブラウザ UI 操作 + DB 検証の E2E テストを作る・実行する | **e2e-browser（本スキル）** | Docker 内 Playwright + Bun + Knex.js の構成を提供 |
| 純粋関数のユニットテスト（UI/DB 不要） | → `tdd` | RED-GREEN-REFACTOR 単位での実装は tdd の主幹 |
| QA が嫌がる悪夢ケース（異常系網羅）の列挙 | → `qa-nightmare` | 11カテゴリ109パターンのチェックリストは qa-nightmare が保有。本スキルは「qa-nightmare で抽出したケースを実行する基盤」として併用 |
| 既存 E2E テスト失敗の**原因分析**（アプリ実装の論理欠陥、データ不整合の仮説立て） | → `systematic-debugging` | Phase 1-4 の「なぜ?」反復は systematic-debugging の主幹。本スキル Phase 4 は**再現と修正提案**までを担い、アプリ側根因は systematic-debugging へ委譲 |
| 既存 E2E テストの信頼性検証（偽陽性検出） | → `test-coverage-guard` | テスト作成後の検証は本スキル範囲外 |
```

6 行（ヘッダ1 + 導入1 + 表ヘッダ1 + 本文5）+ 前後空行。

refactoring iter 2 の「## 委譲先（範囲外作業）」/ consultation iter 2 の「## 関連スキル・境界」と同型。

## 次アクション

- iter 3: 上記 6-10 行追加 → 3 並列再評価（新規 subagent、シナリオ A/B/C 同一）
- 期待: シナリオB の要件1（sd 境界明示）が新節引用で ○、シナリオA/C の精度維持、hold-out D 誤発動回避の備え
- 期待飽和: iter 3 で新規不明瞭点 0 + 精度変動 +3pt 以下 + tool_uses / duration が ±10% / ±15% 以内 なら**連続 1/2 達成**

## 収束判定

- 連続 0/2（iter 2 は精度 +5.7pt で改善継続、カウント成立せず）
- 停止条件まで最短 2 iter（iter 3 + iter 4）
