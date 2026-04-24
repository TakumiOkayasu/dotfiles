# implementation-policy iter 1: baseline 3 並列 dispatch

**実施日**: 2026-04-24
**rule 変更**: なし (baseline)

## 実行結果 (シナリオ別)

| シナリオ | 成功/失敗 | 精度 | 自己申告 retries |
|---|:---:|:---:|:---:|
| A (HTTP retry + loguru) | ○ | 6/6 = 100% | 0 |
| B (月次集計 / 生 SQL 境界) | ○ | 5/5 = 100% | 0 |
| C (パスワードリセットトークン) | ○ | 5/5 = 100% | 0 |
| **合計** | **○** | **100%** | **0** |

*(tool_uses / duration_ms は Agent tool 実行メタ未取得。subagent 自己申告で「Read 1 回のみで回答」。)*

全 [critical] 達成。各 subagent の成果物:

- **A**: `requests.Session + HTTPAdapter(urllib3.util.retry.Retry)` + `loguru`、`APIClientConfig` dataclass で外部化、新規依存なし明示
- **B**: 3 ステップ判定 (ORM 困難性 → 読み取り専用確認 → パフォーマンス根拠) → `sqlalchemy.text()` + バインドパラメータ、docstring で理由記載、SELECT 明示列挙
- **C**: `secrets.token_urlsafe()` (CSPRNG) + `hashlib.sha256` (短期) / `bcrypt` (パスワード)、`os.getenv("TOKEN_EXPIRY_MINUTES", "30")` で外部化、ハッシュのみ DB 保存 + ORM 前提

## 不明瞭点 (今回新出)

**全 3 subagent が「なし」と回答。** これは前例 hallucination-prevention iter 1 と対照的 (当該 rule は 3 subagent 独立で同一の曖昧点を指摘)。

implementation-policy の rule 本文は本番向けコード文脈では自己完結性が高く、subagent が迷う余地が少ない。

## 裁量補完 (今回新出)

- **A**: 環境変数読み込み方法 (`dotenv` の具体採用は自裁量)、`status_forcelist=(429, 500, 502, 503, 504)`、POST のリトライ除外 (冪等性配慮)、タイムアウトデフォルト 10 秒
- **B**: PostgreSQL 方言想定 (`RANK() OVER`, `EXTRACT()`, `DECIMAL`)、Python 標準 `csv` 選定 (pandas 不要判断)、エラーハンドリング省略
- **C**: トークンとパスワードのハッシュアルゴリズム使い分け (sha256 vs bcrypt) を実装で示唆、ORM 実装を疑似コードで SQLAlchemy/Django 並記、ワンタイム削除フロー、`print` 使用箇所あり (demo mock のみ、コメントで「実装時はメールサービス経由」)

## 分析

### baseline 100% だが hold-out D が未検証

iter 1 は本番向けコード文脈 (A/B/C) のみ。iter 0 で最有力候補だった **IP-0-1 (L28 ロギング必須 vs L55「本番コード」scope 不整合)** は、A/B/C がすべて本番向けのため顕在化しない。hold-out D (ワンショットスクリプト、個人作業) で誤発動の有無を見る必要がある。

### 裁量補完の傾向観察

- 複数 subagent (A / C) が「環境変数読み込み具体手段」を自裁量で補完 → L32 (設定値外部化) の記述に「読み込み方法」指針の欠落 (IP-0-5 関連) が軽微に顕在。baseline pass に影響せず、放置して良い。
- subagent C が `print()` を demo mock で使用 → hold-out D で「ワンショット個人スクリプトで print を使ってよいか」の判定が割れる予兆

### tool_uses 相対観察

全 subagent が Read 1 回のみで自己完結 → `tool_uses` の偏りなし。構造的欠陥なし (decision-tree index 寄りの兆候なし)。

## iter 2 テーマ選定

**テーマ**: **IP-0-1** — L28 「ロギング」行に scope を明記し、L55 括弧書きと整合させる最小修正

**修正案** (L28 のみ 1 行修正):

```diff
-| **ロギング** | ロギングライブラリ経由。`print` / `console.log` / `echo` の直接使用禁止 |
+| **ロギング** | 本番コードはロギングライブラリ経由 (`print` / `console.log` / `echo` の直接使用禁止)。個人ワンショット/使い捨てスクリプトは対象外 |
```

**狙い**:
- L28 と L55 の scope 整合 (IP-0-1 解消)
- hold-out D での誤発動を構造的に予防
- baseline A/B/C への影響: 「本番コード」文脈ではロギング必須方針は不変 → 100% 維持見込み

**連続 pass カウント**: iter 1 が 1 回目、iter 2 で修正後 pass なら連続 2 回 (典型 rule 目標達成)。iter 3 で hold-out D を評価。

## 次アクション

- [x] iter-1.md 作成
- [ ] iter 2: rule 修正 (L28 scope 明記) → 3 並列再評価
- [ ] iter-2.md に結果記録
- [ ] iter 3: hold-out D 評価 (連続 2 後)
