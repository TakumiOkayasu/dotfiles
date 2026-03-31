---
name: e2e-browser
description: ブラウザE2Eテスト生成・実行・レポート(Docker内Playwright+Bun+Knex.js)。UI操作+DB検証。プロジェクト非汚染。
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
argument-hint: <対象機能> <シナリオ概要>
---

# Browser E2E Test (Docker + Bun)

対象: $ARGUMENTS

## 概要

Docker コンテナ内で Playwright + Bun によるブラウザE2Eテスト(UI操作 + DB検証)を
生成・実行・レポートする。プロジェクトディレクトリには一切ファイルを配置しない。

- 共通基盤(helpers, config, 全DBドライバ): `e2e-browser:latest` イメージに焼き込み済み
- 作業領域: `/tmp/e2e-browser-<hash>/` (使い捨て)
- ビルドコンテキスト: `~/.local/share/e2e-browser/docker/`
- composeテンプレート: `~/.local/share/e2e-browser/compose-templates/`

## パス定義

以降のPhaseで使うパス変数:

```bash
E2E_DATA="$HOME/.local/share/e2e-browser"
E2E_WORK="/tmp/e2e-browser-$(echo "$PWD" | md5sum | cut -c1-12)"
```

`E2E_WORK` は `pwd` のハッシュでプロジェクトごとに一意。同一プロジェクトで再実行すれば前回のworkspaceを再利用する。

---

## Phase 0: 環境チェック

### 0-1. イメージ確認

```bash
docker image inspect e2e-browser:latest > /dev/null 2>&1 || \
  docker build -t e2e-browser:latest "$E2E_DATA/docker/"
```

イメージがなければビルド。2回目以降はスキップ。

### 0-2. workspace作成

```bash
mkdir -p "$E2E_WORK"/{tests,fixtures,screenshots}
```

### 0-3. .env.e2e 生成

`$E2E_WORK/.env.e2e` が存在しなければ、ユーザーに確認:
- DB種別(PostgreSQL / SQL Server / MySQL / SQLite)
- テスト対象アプリURL(デフォルト: http://host.docker.internal:8080)
- DB接続情報(DB名、ユーザー、パスワード)

```env
DB_CLIENT=pg
DB_HOST=e2e-db
DB_PORT=5432
DB_NAME=app_e2e
DB_USER=test
DB_PASSWORD=test
E2E_BASE_URL=http://host.docker.internal:8080
```

### 0-4. docker-compose.e2e.yml 生成

DB_CLIENT に応じて `$E2E_DATA/compose-templates/` からテンプレートを読み、
`$E2E_WORK/docker-compose.e2e.yml` に書き出す。

テンプレートの `${E2E_WORK}` プレースホルダを実際のパスに置換すること。

---

## Phase 1: コンテナ起動

テスト対象アプリの起動確認:

```bash
curl -sf "${E2E_BASE_URL:-http://localhost:8080}" > /dev/null
```

失敗したらアプリ起動方法をユーザーに案内。

DBコンテナ起動:

```bash
docker compose -f "$E2E_WORK/docker-compose.e2e.yml" up -d e2e-db
```

ヘルスチェック通過待ち:

```bash
docker compose -f "$E2E_WORK/docker-compose.e2e.yml" ps e2e-db --format '{{.Health}}'
```

---

## Phase 2: テスト生成

### 2-1. シナリオ設計

ユーザーに確認:
- 対象画面URL
- 操作手順(入力・クリック・遷移)
- 期待UI表示(成功メッセージ、一覧反映等)
- 検証すべきDBテーブル・カラム・期待値

### 2-2. Fixture JSON 生成

`$E2E_WORK/fixtures/<feature>/<scenario>.json`:

```json
[
  { "table": "テーブル名", "truncate": true, "rows": [{ "col": "val" }] }
]
```

FK制約がある場合は依存順に並べる。

### 2-3. テストコード生成

`$E2E_WORK/tests/<feature>/<scenario>.spec.ts`:

```typescript
import { test, expect } from '@playwright/test';
import { destroyDb } from '../../helpers/db-client';
import { dbAssert } from '../../helpers/db-assert';
import { seed } from '../../helpers/db-seed';
import { cleanup } from '../../helpers/db-cleanup';

test.describe('<機能名>', () => {
  test.beforeEach(async () => {
    await seed('<feature>/<scenario>.json');
  });

  test('<シナリオ>', async ({ page }) => {
    // 1. 画面遷移
    // 2. UI操作
    // 3. UI検証
    // 4. DB検証(dbAssert.exists / notExists / count / columnEquals)
  });

  test.afterEach(async () => {
    await cleanup(['対象テーブル群']);
  });

  test.afterAll(async () => {
    await destroyDb();
  });
});
```

**必須ルール:**
- 1テスト1シナリオ、他テストに依存しない
- セレクタ優先: `data-testid` > `role` > `label` > CSS selector
- DB操作は beforeEach/afterEach で完結
- 明示的待機: `waitForResponse` / `waitForSelector`
- `page.waitForTimeout()` 禁止
- `afterAll` で `destroyDb()` 必須
- DB操作は Knex クエリビルダまたは提供ヘルパー(`dbAssert`, `seed`, `cleanup`)を使用。生SQL(`knex.raw()` 等)は原則禁止

**dbAssert API:**
- `dbAssert.exists(table, where, message?)` - レコード存在検証
- `dbAssert.notExists(table, where, message?)` - レコード非存在検証
- `dbAssert.count(table, where, expected)` - 件数検証
- `dbAssert.columnEquals(table, where, column, expected)` - カラム値検証
- `dbAssert.dump(table, where?, limit?)` - デバッグ用ダンプ

---

## Phase 3: テスト実行

特定テスト:

```bash
docker compose -f "$E2E_WORK/docker-compose.e2e.yml" \
  run --rm e2e-runner \
  bun run playwright test tests/<feature>/<scenario>.spec.ts \
  --reporter=list --project=chrome
```

全テスト:

```bash
docker compose -f "$E2E_WORK/docker-compose.e2e.yml" \
  run --rm e2e-runner \
  bun run playwright test --reporter=list --project=chrome
```

---

## Phase 4: レポート

### 成功時
pass件数・所要時間を報告 → Phase 5 へ。

### 失敗時
1. Playwright エラーメッセージ
2. スクリーンショット(`$E2E_WORK/screenshots/`)
3. DB実値ダンプ(`docker compose exec e2e-db` で直接クエリ)

修正案提示 → ユーザー承認後 → Phase 3 再実行。

---

## Phase 5: クリーンアップ

コンテナ・ボリューム破棄:

```bash
docker compose -f "$E2E_WORK/docker-compose.e2e.yml" down -v
```

workspace削除するか確認:

```bash
rm -rf "$E2E_WORK"
```

> イメージ(e2e-browser:latest)は再利用するので削除しない。

---

## 禁止事項

- `page.waitForTimeout()`
- テスト間の暗黙的DB状態共有
- `headless: false`
- fixture への本番データ混入
- テストコード内のハードコード接続情報
- `workers > 1` でのDB操作テスト
- ホストへの Node/Bun/npm 直接インストール
- プロジェクトディレクトリへのファイル配置
- 生SQL文字列の直接記述（Knex クエリビルダ / 提供ヘルパー API を使用すること）
