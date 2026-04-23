# interface-first-design iter 1: baseline 3並列 dispatch

**実施日**: 2026-04-23
**対象**: `claude/skills/interface-first-design/SKILL.md`
**フェーズ**: baseline 3 シナリオ並列 dispatch（シナリオカタログ `scenarios.md` 準拠）

---

## 評価表（指示側メトリクス + 自己申告）

| シナリオ | 精度 | tool_uses | duration (s) | retries | 不明瞭点 | 裁量補完 |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| A: 新規注文確定処理 | **8/8 ○** | 1 | 43.1 | 1 | 3件 | 4件 |
| B: UserService 責務分割 | **7/7 ○** | 2 | **1375.5** ⚠️ | 1 | 3件 | 4件 |
| C: 既存 Article 逆算誘惑 | **6/6 ○** | 2 | **1367.9** ⚠️ | 0 | 2件 | 3件 |

**集計**:
- 精度: 21/21 = **100%**（全シナリオ全項目○）
- tool_uses 偏り: A=1 vs B/C=2 → 2倍（empirical-prompt-tuning 閾値 3-5 倍未満、許容）
- duration 偏り: A に対し B/C が **31倍超** → **要注意の外れ値**（refactoring iter 2 シナリオC の 423s と同種の一過性レイテンシと仮定、応答品質は正常）
- retries: 0-1 回、全て ISP 違反の自己検知 → 自己修正機能は正常

---

## [critical] 要件達成詳細

### シナリオA（新規注文確定処理）

| # | 要件 | 結果 |
|:-:|---|:-:|
| 1 [crit] | 疑似コードを実装前（given/when/then 準拠） | ○ |
| 2 [crit] | 1 interface = 1 メソッド = 1 責務 | ○ |
| 3 | 動詞→メソッド / 名詞→データ型 / 分岐→エラー型 変換 | ○ |
| 4 | FW 固有型（Request/Row/Paginator）を含めない | ○ |
| 5 | 戻り値を `Ok \| Error` で明示 | ○ |
| 6 | 上位層で組み立て、下位 interface は「何を」を知らない | ○ |
| 7 | 設計完了チェックリスト 10 項目を提示 | ○ |
| 8 | TDD スキル移行を明示 | ○ |

**特筆**:
- SKILL.md 疑似コード例 (L72「決済失敗 → 在庫を戻す」) と向き合い、**StockChecker 単一 IF では補償できない** と判断し `StockReserver/StockReleaser` へ 3 分割（ISP 遵守）
- `Result<T, E>` discriminated union を TypeScript 慣習に合わせて補完
- TDD 移行を「`~/.claude/skills/TDD/SKILL.md` を起動」と具体パスで指示

### シナリオB（UserService 責務分割）

| # | 要件 | 結果 |
|:-:|---|:-:|
| 1 [crit] | 既存実装を写さず疑似コードから書き直す | ○ |
| 2 [crit] | refactoring に委譲せず本スキルで対応 | ○ |
| 3 | ISP で複数 interface 分割 | ○ |
| 4 | 各 interface 1 メソッド | ○ |
| 5 | hierarchical-architecture「同レイヤー直接参照禁止」 | ○ |
| 6 | 上位層で組み立て | ○ |
| 7 | 「interface 追加で既存実装が壊れないか」チェック | ○ |

**特筆**:
- `find/save/delete/send_welcome_email/export_to_csv` の 5 メソッドから引きずられず、**疑似コード起点で再設計**
- `UserLister` を新設（`read(id)` と `list(filter)` は変更理由が異なる = ISP 原則から導出、L273）
- **refactoring へ引き込まれそうになったが抑制**（自己申告、iter 0 IFD-0-1~0-4 懸念の実害は軽微）
- UseCase 層 + Controller 層の 2 段構成で hierarchical-architecture に整合

### シナリオC（既存 Article 逆算誘惑）

| # | 要件 | 結果 |
|:-:|---|:-:|
| 1 [crit] | Anti-pattern 4 を名指しで提示 | ○ |
| 2 [crit] | ORM 固有型（ActiveRecord::Relation, Paginator）を含めない | ○ |
| 3 | ユーザー急かしでも鉄則を曲げない | ○ |
| 4 | 利用側フローから疑似コード起こし | ○ |
| 5 | `find/all/where/paginate` 写経は ISP 違反を指摘 | ○ |
| 6 | 戻り値型を明示 | ○ |

**特筆**:
- 「急いでいるからこそ疑似コード 10 分」と**鉄則を曲げない応答**
- `ArticleReader.read` / `ArticleLister.list` / `ArticleCounter.count` に 3 分割し、`all`/`where` が同一責務・`paginate` が `list+count` の合成であることを指摘
- `ArticleCriteria` / `PageRequest` を値オブジェクト化して ORM 非依存を徹底

---

## 不明瞭点（自己申告）全集約

| ID | シナリオ | 内容 | 実害 |
|:-:|:-:|---|:-:|
| IFD-1-A-1 | A | SKILL.md 疑似コード例「在庫を戻す」と StockChecker 単一 IF の整合 | なし（ISP 準拠で 3 分割判断） |
| IFD-1-A-2 | A | 通知失敗時の扱い（全体失敗 or 部分成功）未指定 | 小（ログのみで吸収） |
| IFD-1-A-3 | A | OrderId 生成タイミング（決済前/後）未規定 | 小（決済後採番で裁量） |
| **IFD-1-B-1** | B | **Step 3「上位層」の粒度（UseCase / Service / Controller）が未特定** | 中 |
| IFD-1-B-2 | B | 複数取得が元の Reader で済むか（ISP で Lister 新設） | 小（ISP 導出で解消） |
| IFD-1-B-3 | B | Notifier 失敗時のトランザクション扱い | 小（範囲外と明示） |
| IFD-1-C-1 | C | L108「戻り値は Ok/Error の 2 値」と Anti-pattern 1 の `User \| null` のずれ | なし（読取=null、副作用=Ok/Error と解釈）|
| **IFD-1-C-2** | C | **「上位層」の粒度が未規定**（B-1 と同一） | 中 |

### 裁量補完（自己申告）全集約

| ID | シナリオ | 補完内容 | SKILL.md との整合 |
|:-:|:-:|---|:-:|
| A-c1 | A | `Result<T, E>` を TS discriminated union として実装 | ○（明示されない） |
| A-c2 | A | StockReserver/Releaser を補償トランザクション用に追加 | ○（ISP 原則から導出） |
| A-c3 | A | OrderIdGenerator を独立 IF 化 | ○（ISP 原則から導出） |
| A-c4 | A | 通知失敗をログのみで吸収 | 推測（SKILL.md 未規定） |
| B-c1 | B | UserLister を追加 | ○（ISP 原則から導出） |
| B-c2 | B | Welcome 通知を save から切り離し UseCase 合成に | ○（ISP 原則から導出） |
| B-c3 | B | エラー型名（SaveError / NotFound 等）仮称 | 推測 |
| B-c4 | B | 管理層を UserController 命名 | 推測（hierarchical-architecture 由来） |
| C-c1 | C | `list` と `count` を分離 | ○（ISP 原則 + 変更理由） |
| C-c2 | C | `ArticleCriteria` / `PageRequest` 値オブジェクト化 | ○（「FW 固有型含めない」原則の具体化）|
| C-c3 | C | 「null vs []」ポリシー（coding-conventions 整合意識） | ○（SKILL.md 単独でも導出可） |

---

## 隣接スキル混同の兆候

| シナリオ | 混同候補 | 結果 |
|:-:|---|---|
| A | TDD 先取り / consultation 逃避 | **抑制成功**（Step 4 移行明示に留める）|
| B | refactoring（500 行分割の手順論） | **抑制成功**（ユーザー明示「設計から見直したい」に従い疑似コード起点）|
| C | TDD / refactoring / consultation 全て | **抑制成功**（本スキル範囲内で完結）|

**iter 0 IFD-0-1~0-4 予想（refactoring との境界曖昧が実害化）は部分的に外れ**:
- B で refactoring 引き込みの引力は働いたが subagent が自制
- 明文化がなくても user 明示「設計から見直したい」という強信号で境界判断成立
- → **iter 2 での refactoring 境界明文化は優先度下げ**

---

## iter 2 テーマ選定

### 候補比較

| テーマ候補 | 根拠 | 修正コスト | 波及期待 |
|:-:|---|:-:|:-:|
| **上位層粒度の明示** | 2 subagent（B/C）独立で挙がった共通不明瞭点 = **構造的曖昧**。hierarchical-architecture 参照だけでは粒度選好が決まらない | 小（Step 3 末尾に 3-5 行）| 中（2 シナリオ波及 + 他スキル誤発動抑止）|
| refactoring 境界明文化 | iter 0 懸念だが B で subagent が自制成功、実害軽微 | 小（委譲先節 5 行）| 小（user 明示信号があれば自力判断可） |
| 戻り値ポリシー null/Ok-Error 整理 | C で軽度の疑問、実害なし | 中（L108 前後の表現調整）| 小 |

### 選定: **上位層粒度の明示**（B-1 + C-2 の共通解消）

**理由**:
1. 2 subagent 独立発生 = **単一 subagent の裁量補完**ではなく**構造的な記述不足**
2. hierarchical-architecture の管理層/提供層/操作層分類を本スキル側から逆引きできる小さな案内がない
3. 最小修正（Step 3 末尾に 3-5 行）で済む
4. tdd iter 2 / sd iter 2 でも採用した「2 subagent 共通 = 優先」の empirical 原則と整合

### 修正案（Step 3 末尾に追加予定、3-5 行）

```
**上位層の粒度の目安:**

- 用途単位の薄い組み立て → UseCase (提供層)
- 複数 UseCase を束ねる配線点 → 管理層 (Controller / Orchestrator / Application 等)
- 命名は hierarchical-architecture の役割サフィックス規則に従う
- 「どの層で組み立てるか」は利用側の複雑度で決める（単一 UseCase で済むなら UseCase 自体が上位層）
```

---

## duration 外れ値の扱い

- B: 1375s / C: 1367s は A の 43s に対し **31倍超**
- refactoring iter 2 シナリオC で観察された **423s 外れ値** と同じ一過性 subagent レイテンシと解釈
- 応答品質（精度・retries・裁量補完の妥当性）は正常
- iter 2 で再発するか観測。再発すれば構造要因、単発なら外れ値確定
- empirical-prompt-tuning L132「duration ±15%」判定は外れ値除去後に実施（refactoring iter 3 で採用した運用）

---

## 次アクション

iter 2: SKILL.md Step 3 末尾に「上位層の粒度の目安」を追加（3-5 行） → 3 並列再評価
- 観測点1: IFD-1-B-1 / IFD-1-C-2 の解消（新修正の直接引用 or 自然適用）
- 観測点2: 精度 100% 維持（副作用の検知）
- 観測点3: duration B/C が A 並に戻るか（外れ値か構造要因かの確定）
- 観測点4: 新規不明瞭点の発生有無
