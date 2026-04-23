# iter 0 — e2e-browser（description/body 整合チェック）

empirical-prompt-tuning の iter 0 フェーズ。SKILL.md 本体の構成と description の整合性を審査する。subagent dispatch は iter 1 から。

## 対象

- スキル: `claude/skills/e2e-browser/SKILL.md`（327行）
- description: 「ブラウザE2Eテスト生成・実行・レポート(Docker内Playwright+Bun+Knex.js)。UI操作+DB検証+全ステップスクショ。WSLg/noVNC/headless切替対応。プロジェクト非汚染。」
- 収束目標: **連続2**（典型スキル）

## description の構成要素

| 要素 | 内容 |
|------|------|
| 対象 | ブラウザE2Eテスト / UI操作 / DB検証 |
| 主要動作 | 生成・実行・レポート |
| 技術スタック | Docker内 Playwright + Bun + Knex.js |
| 特徴 | 全ステップスクショ、WSLg/noVNC/headless 切替、プロジェクト非汚染 |

## body の主要セクション

| セクション | 行 | 内容 |
|---|---|---|
| トリガー条件 | L13-22 | 5項目（作成依頼/UI+DB/スクショ/CI headless/失敗調査） |
| 前提条件 | L24-32 | 4項目（Docker / イメージ / アプリ起動 / DB接続情報） |
| 概要 | L34-41 | 目的 + 表示モード3種 |
| パス定義 | L43-48 | `E2E_DATA` / `E2E_WORK` |
| Phase 0: 環境チェック | L50-108 | イメージ確認 / workspace / .env.e2e / docker-compose |
| Phase 1: コンテナ起動 | L110-126 | `docker compose up -d` + ヘルスチェック + noVNC 案内 |
| Phase 2: テスト生成 | L128-276 | シナリオ設計 / Fixture JSON / テストコード / helpers API / dbAssert |
| Phase 3: テスト実行 | L278-289 | `docker compose run --rm --service-ports` |
| Phase 4: レポート | L291-303 | 成功/失敗時の報告手順 |
| Phase 5: クリーンアップ | L305-312 | `docker compose down -v` + `rm -rf $E2E_WORK` |
| 禁止事項 | L314-327 | 8項目（waitForTimeout / 暗黙DB共有 / 本番データ / ハードコード 等） |

## 整合性評価

### ✅ description と body が整合している箇所

| description | body 裏付け |
|---|---|
| 「Docker内Playwright+Bun+Knex.js」 | Phase 0-1 `docker build`, Phase 3 `docker compose run`, `playwright test`, `helpers/db-client` の Knex 直叩き（L262-276） |
| 「UI操作+DB検証」 | Phase 2-3 テストコードで `captureStep` + `dbAssert.exists / columnEquals` 併用（L195-206, L237-254） |
| 「全ステップスクショ」 | L219 `beginCapture`、L220 captureStep が前後2枚自動撮影、L327 禁止事項「captureStep なしの UI 操作」 |
| 「WSLg/noVNC/headless切替対応」 | L38-41 表示モード3種、Phase 0-4 mode別 compose 分岐（L93-108） |
| 「プロジェクト非汚染」 | L36 「プロジェクトディレクトリには一切ファイルを配置しない」、L326 禁止事項「プロジェクトディレクトリへのファイル配置」 |

### ⚠️ 乖離点（iter 1 観測後に修正判断）

| # | 乖離 | 重要度 | 詳細 |
|---|---|:---:|---|
| EB-0-1 | description の「実行・レポート」と subagent 実行可能性の乖離 | 中 | subagent は Docker CLI を持たない可能性が高く、Phase 0-1 / Phase 1 / Phase 3 / Phase 5 の `docker` コマンドは dispatch 不能。body 側に「生成までで止める場合の指針」が不在。evaluation として「テストコード + fixture + .env.e2e + docker-compose を生成すれば合格」とするかが不明瞭 |
| EB-0-2 | Phase 0-4 で `$E2E_DATA/compose-templates/` を参照するが、テンプレート本体が body に記載なし | 中 | 「DB種別に応じたテンプレートをコピー」とだけ書かれ、subagent は実体を見ずに生成する必要がある。PostgreSQL / MySQL / SQL Server / SQLite の4種類それぞれの docker-compose.e2e.yml の骨格が body 内に inline されていない |
| EB-0-3 | Fixture JSON の列挙順（L162「外部キー親→子」）と cleanup の列挙順（L230「MySQL/SQL Server では子→親」）が逆 | 中 | シナリオC 焦点。同じ body 内に親→子と子→親が共存し、subagent が取り違えるリスクあり。PostgreSQL は CASCADE で子→親不要、MySQL/SQL Server は明示的に子→親必要、の条件分岐が「まとめ表」で示されていない |
| EB-0-4 | qa-nightmare との境界が body に未言及 | 中 | qa-nightmare は e2e-browser を実行基盤として使う依存関係（qa-nightmare SKILL.md description「e2e-browser で自動実行する」）があるが、e2e-browser 側に逆リンクがない。subagent が「悪夢ケース列挙依頼」を受けたとき e2e-browser で応じる誤発動リスク |
| EB-0-5 | tdd との境界が body に未言及 | 中 | ユニットテスト領域（純粋関数、UI/DB なし）での誤発動回避ガイドが body にない。シナリオD 焦点。trigger-overlap.md で「テスト」が 🔴 高リスク判定済 |
| EB-0-6 | トリガー5「既存E2Eテスト失敗調査・修正」と systematic-debugging の境界未明示 | 中 | 失敗調査は systematic-debugging 領域、再現・修正は e2e-browser 領域、の分離が body に書かれていない。シナリオB 焦点 |
| EB-0-7 | `captureStep` の前後 2 枚自動撮影（L220）挙動が「自分で before/after を二重に呼ばない」の注意書きしかなく、helpers 実装を読まないと完全理解できない | 低 | `captureStep(page, label, action)` の第3引数が callback で、helpers 内部で callback 前後に自動撮影する挙動は body のコード例からは推測困難。ただし**ルールは守れる**（二重呼び出し禁止） |
| EB-0-8 | 前提条件「テスト対象アプリが起動済みでアクセス可能」と Phase 1「curl でアクセス確認」が重複 | 低 | 前提条件で起動済みを要求する一方、Phase 1 で curl 確認を挟む。role 分離が薄い |
| EB-0-9 | helpers API の import パス（`../../helpers/db-client` 等）の相対パスが固定で、`$E2E_WORK/tests/<feature>/<scenario>.spec.ts` からの `..` 2 段上がり構造を読み解かせる | 低 | 固定構造だが body 内の解説が薄い。テスト配置が 2 段ネスト（`tests/<feature>/<scenario>.spec.ts`）であることを読み取らないと相対パスを間違える |
| EB-0-10 | 「表示モード」（headless / wslg / novnc）の選択指針が body に薄い | 低 | L38-41 は列挙のみ、L92-108 は分岐処理。「どう使い分けるか」の指針（CI=headless、WSL ローカル=wslg、リモートデバッグ=novnc 等）が明文化されていない。ユーザーが指定してくる前提だが、未指定時のデフォルト動作は headless（L85）で OK |

### 📝 observer note

- SKILL.md 327 行は厚めのスキル（interface-first-design 276 の次に多い）。Phase 0-5 の手順明示 + helpers API inline サンプルで自己完結性は高い
- ただし subagent が Docker を持たない場合の「生成までで止める指針」が書かれていない。シナリオ A/B/C すべてで Docker 実行は評価対象外にせざるを得ない
- 隣接スキル境界の未言及が 3 件（qa-nightmare / tdd / systematic-debugging）。refactoring iter 2 / consultation iter 2 の「委譲先節新設」パターンが有効候補
- `captureStep` と `captureState` の使い分けは body で明示済（L220-222）で、シナリオA で差分観察可能
- Fixture / cleanup の列挙順の親子逆転（EB-0-3）は「DB別条件」+「親→子 or 子→親」の 2 軸交差で、シナリオC での実害確認が最重要

## iter 0 時点の判断

- **iter 0 での SKILL.md 修正はしない**（過去全スキル iter 0 と同じ方針）
- 乖離 EB-0-1 〜 EB-0-10 は iter 1 の baseline 観測で実害が出るか確認してから iter 2 以降で修正判断
- 特に EB-0-3（fixture / cleanup 列挙順の逆転）、EB-0-4/5/6（隣接スキル境界3件）は実害リスク高
- EB-0-1（subagent の Docker 実行可否）はシナリオ設計側の問題でもあるため、要件チェックリストで「生成物の完成度」を評価軸の中心にしている

## 次アクション

- iter 1: baseline 3並列 dispatch（scenarios.md の A/B/C）
- dispatch パラメータ: 新規 subagent、SKILL.md 全文貼付、各シナリオの要件チェックリストを subagent 自己評価させる
- subagent 起動契約: empirical-prompt-tuning「subagent 起動契約」節のレポート構造に従う
- 他スキル auto-load 禁止を明示
- Docker 実行不能環境での「生成までで停止」指示を dispatch プロンプトに含める
