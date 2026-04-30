# coding-conventions iter 0: rule 間重複・矛盾 + 自己完結性チェック

**モード**: 静的 (dispatch なし、rules 版 iter 0)
**実施日**: 2026-04-24
**対象**: `claude/rules/coding-conventions.md` (324 行、14 トピック)

## 再定義: rules 版 iter 0

skills 版 iter 0 (description ↔ body 整合) は rules に直接適用不可 (description / trigger なし、常時ロード)。rules 版は以下を静的チェック:

1. **rule 間の用語重複・矛盾** (grep クロス参照)
2. **自己完結性** (rule 名と本文だけで subagent が適用可能か)
3. **スコープ宣言と処理手順のギャップ**
4. **参照する記法・概念が隣接 rule / skill と整合するか**

## クロス参照結果 (grep 抽出)

| 隣接 | coding-conventions 側 | 隣接側 | 関係 |
|---|---|---|---|
| `hierarchical-architecture.md` | L213 「レイヤー役割のサフィックス命名は `hierarchical-architecture.md` を参照」 | L110-118 命名規則 | **順方向参照あり**、重複なし (曖昧命名 vs レイヤー命名で責務分離) |
| `implementation-policy.md` | L266 「print 直接禁止... 詳細は `implementation-policy.md`」 | L28 ロギングライブラリ経由 (本番コード scope 注記済) | **順方向参照あり**、scope 整合 |
| `hallucination-prevention.md` | 明示参照なし | L24-25 型・引数・戻り値の型確認 | 用途別 (HP=実在確認、CC=設計原則)、干渉なし |
| `oop-composition-over-inheritance.md` | L221 依存性逆転 (SOLID) | 全般 (合成 > 継承) | **重複なし** (SOLID 原則の宣言 vs 具体適用ガイド) |
| `skills/tdd/SKILL.md` | L288 「詳細は `~/.claude/skills/tdd/SKILL.md` 参照」 | RED-GREEN-REFACTOR 全般 | **順方向参照あり**、AAA/命名の書き出しのみ重複 |

**結論**: 隣接 rule / skill への **明示参照は揃っており、逆参照もなし**。rule 間の矛盾は検出できない。

## 懸念点 (iter 1 で検証する候補)

### CC-0-1: 優先順位の欠落 (14 トピック並列、最有力 iter 2 候補)

- L7-298 は 14 トピック (比較演算 / 制御フロー / 関数 / 変数 / null / 型注釈 / 非同期 / コメント / 命名 / SOLID / DRY-KISS-YAGNI / 関心の分離 / エラーハンドリング / ログ / テスト規約)
- **ギャップ**: レビュー時にどのトピックを優先的に適用するかの優先順位なし
- iter 1 で subagent が「14 全部等重量でコメント」になるか、「critical な違反に絞る」かの挙動を観察
- 潜在リスク: レビューコメントが肥大化してシグナル・ノイズ比が悪化

### CC-0-2: 硬い数値基準と「目安」の関係 (中程度、iter 2 候補)

- L31 「制御構造は **3 階層まで**」 (硬い上限)
- L57 「**30 行目安**」 (「目安」)
- L56 「引数上限 **3-4 個まで**」 (やや硬い)
- L225 DRY 「3 回繰り返したら抽出」 (具体)
- **ギャップ**: どの数値が「絶対禁止ライン」でどれが「判断の参考値」か subagent に伝わらない
- 3階層ネストを 1 行超えた既存コードに対して、subagent が機械的に関数抽出を要求すると YAGNI (L227) と衝突

### CC-0-3: 「空コレクション vs null」の判定基準不足 (edge シナリオ候補)

- L106 「空コレクション返却」 + 「ただし未取得と空結果を区別する必要がある場合は null 許容」
- **ギャップ**: 「未取得と空結果を区別する必要性」の判定条件なし。subagent は「念のため区別」か「常に空配列」のどちらかに振れる
- iter 1 シナリオで DB 取得関数を出すと挙動が炙り出される

### CC-0-4: 命名「曖昧な接頭辞」の例外判定 (edge シナリオ候補)

- L208-211 例外: フレームワーク規約 (React `handleClick`) / 極小スコープ / 目的語付き `execute*`
- **ギャップ**: 「フレームワーク規約」の判定基準なし (React は OK、カスタムフック内部は? ビジネスロジック層の `handleSubmit` は?)
- **ギャップ**: 「極小スコープ 2-3 行」の境界 (5 行なら NG? ローカルクロージャは?)
- iter 1 で React コンポーネント + ビジネスロジック混在コードを与えて挙動を観察

### CC-0-5: 非同期「try/catch で捕捉 or 呼出側に任せる」の選択基準なし (中程度)

- L149 「エラー伝播: try/catch で捕捉するか、呼出側に任せる (握り潰し禁止)」
- **ギャップ**: どちらを選ぶかの判定基準なし。subagent は「握り潰し禁止」を守るために毎回 try/catch を書く過剰反応に振れる可能性
- fail-fast 原則 (L241) との関係も未記述

### CC-0-6 (残置候補): 「汎用的すぎる例外」の境界

- L254 「`catch (Exception e)` で全てを捕捉」禁止
- **残置理由**: `Exception` の明示あり、Python `except Exception`、JS `catch (e)` の例示で subagent に伝わる可能性高
- iter 1 で挙動が問題なら iter N で追記

### CC-0-7 (残置候補): immutable の言語別扱い

- L82 「再代入不可 (JS/TS: `const`, Kotlin/Scala: `val`, Rust: `let` (デフォルト不変) 等)」
- **残置理由**: 言語例が豊富、Python が漏れているが `Final[...]` / dataclass frozen 等への言及なしでも致命的ではない

## iter 1 で集中観察する点

- **CC-0-1**: 3 シナリオすべてでコメント量/優先順位の取り扱い
- **CC-0-2**: 数値基準への機械的適用 or 判断適用の別
- **CC-0-3**: シナリオ B (DB 取得関数含む) で空配列/null 選択
- **CC-0-4**: シナリオ B (React + 業務ロジック混在) で `handleX` 命名の例外判定
- **CC-0-5**: シナリオ C (async + error) で try/catch 配置の判断

## 収束目標

重要 rule (coding-conventions は他 rule の前提、14 トピック広範囲) → **連続 3 回 + hold-out パス**

## 次アクション

- [x] iter-0.md 作成
- [ ] scenarios.md 作成 (A 複合レビュー / B 命名例外 / C async+error+log / D hold-out 既準拠コード)
- [ ] iter 1: baseline 3 並列 dispatch
- [ ] iter-1.md に結果記録
- [ ] iter 2+ で 1 テーマ修正 → 再評価
- [ ] hold-out D
