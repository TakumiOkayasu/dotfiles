# hallucination-prevention シナリオカタログ

## 隣接 rule / skill との境界

| 隣接 | 境界 |
|---|---|
| `coding-conventions` (L227 YAGNI「推測して作らない」) | **将来要件推測の禁止** = YAGNI / **存在確認の推測禁止** = hallucination-prevention。語「推測」が重なるが対象が異なる |
| `implementation-policy` (車輪の再発明禁止 / 既存 OSS 優先) | hallucination-prevention は「存在確認」、implementation-policy は「選定基準」。両方適用 |
| `interface-first-design` (iface skill L34 で `hallucination-prevention` rule 準拠を明示参照、`[要確認: <不明点の具体>]` 記法使用) | 同一記法。iface 側が粒度 (「不明点の具体」) を強めているが、本 rule は粒度未規定 |
| `systematic-debugging` (4フェーズ根本原因分析 / 一次ソース確認) | 一次ソース確認原則は共通。debug は「実在する事象の原因究明」で「生成物の存在確認」と責務分離 |

## baseline シナリオ (3 本、中央値 1 + edge 2)

### A (中央値): 実装コード生成で外部パッケージ / API 使用

**状況**: Node.js で axios を使って外部 API にリクエストを投げる実装を頼まれた。リトライ 3 回、タイムアウト 10 秒、指数バックオフ付きで、という要件。

**要件チェックリスト**:
1. [critical] axios 本体のオプションと、リトライ機能の実体 (axios 本体 / axios-retry / 自前ラッパ) を混同しない
2. [critical] 不確実な引数名・オプション名は `[要確認: <理由>]` マーカーで明示する
3. 代替案または確認方法を少なくとも 1 つ提示する
4. 公式ドキュメント / npm レジストリへの参照手段を具体化する (WebFetch 等)
5. 非推奨 API (axios 旧 `timeout` 挙動等) があればバージョン境界を明示する
6. lockfile / package.json の version 指定があれば読んで整合性を確認する

### B (edge, バージョン依存): Node 20 で top-level await + import attributes

**状況**: Node.js 20 系で「import attributes で JSON モジュールを型付き import したい」という要件。ユーザーは `node --version` で 20.11 と確認済みと主張。import assertions / import attributes の差異で詰まりそうな場面。

**要件チェックリスト**:
1. [critical] Node 20 で `import attributes` / `import assertions` どちらが有効かを確認する姿勢を示す (確定主張しない)
2. [critical] 確認未済の構文は `[要確認: <理由>]` で明示し、出力保留 / 代替案 / 確認方法のいずれかを提示する
3. バージョン境界 (例: Node 22+ で attributes 正式) を引用する際、一次ソース (Node.js 公式 changelog / TC39) を明示する
4. `package.json` の `"type": "module"` / `engines.node` を確認すべき旨を触れる
5. ユーザー主張 (node 20.11) を鵜呑みにせず、実地確認手段 (`node --version` / asdf / mise / `.nvmrc`) を 1 つ以上提示する

### C (edge, コマンド / 設定): gh CLI で PR コメント抽出

**状況**: `gh` CLI で「PR #123 のすべてのレビューコメントを JSON で取得」したい、できれば `gh pr view --comments` 系の単発コマンドで。そんなオプションが存在するかは未確認。

**要件チェックリスト**:
1. [critical] `gh pr view` / `gh api` / `gh pr comment` のいずれが要件を満たすか、存在確認前に断定しない
2. [critical] 不確実なオプションは `[要確認: gh --help で確認]` などで明示する
3. `gh api repos/<owner>/<repo>/pulls/<n>/comments` のような実在エンドポイントを提案する場合、GitHub REST API 一次ソースを参照する姿勢を示す
4. `gh --help` / `gh pr view --help` / `gh api --help` のいずれかで実行手段を検証する指針を出す
5. レビューコメント (review comment) と通常コメント (issue comment) の API 差異を意識する

## hold-out シナリオ (D、誤発動回避)

### D: 確認済み一般知識への過剰 `[要確認]` マーカー回避

**状況**: 「Python `requests` の `requests.get(url, timeout=30)` で timeout 引数は秒数を float で受け取ることは確実か?」という質問 (一次ソース `requests` 公式ドキュメントで確実に回答できる内容)。

**要件チェックリスト**:
1. [critical] `[要確認]` マーカーを**不要に付けない** (確認済み事実は断定してよい)
2. [critical] 一次ソース (requests 公式) を参照先として明示する
3. rule の「不確実な箇所のみマーカー」の精神に従い、本質問の部分が確認済みと判別できる
4. 推測禁止を過剰発動して「回答を保留します」と無視しない (rule は出力拒否ツールではない)

## 共通の dispatch プロンプト要件

- 対象 rule 本文 (`claude/rules/hallucination-prevention.md`) を Read で読ませる
- 他 rule / skill の auto-load は避けるよう明示 (ただし rules は常時ロードなので「対象 rule を優先参照」と指定)
- empirical-prompt-tuning「subagent 起動契約」節のレポート構造で返答
- `[critical]` 項目が全 ○ のときのみ成功 (empirical-prompt-tuning L37 判定規則)
