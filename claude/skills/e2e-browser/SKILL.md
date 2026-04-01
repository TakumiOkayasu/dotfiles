---
name: e2e-browser
description: ブラウザE2Eテスト生成・実行・レポート(Docker内Playwright+Bun+Knex.js)。UI操作+DB検証+全ステップスクショ。WSLg/noVNC/headless切替対応。プロジェクト非汚染。
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
argument-hint: <対象機能> <シナリオ概要>
---

# Browser E2E Test (Docker + Bun)

対象: $ARGUMENTS

## トリガー条件

以下のいずれかに該当する場合にこのスキルを発動する:

| 条件 | 例 |
|------|----|
| ユーザーがE2Eテストの作成・実行を依頼した | 「ログイン機能のE2Eテストを書いて」 |
| UI操作とDB検証を組み合わせたテストが必要 | 「フォーム送信後にDBレコードを確認したい」 |
| ブラウザ操作のスクリーンショット付きテストが必要 | 「全ステップをキャプチャしながらテストしたい」 |
| CI/CD向けのheadlessブラウザテストが必要 | 「Dockerで動くE2Eテストを用意して」 |
| 既存E2Eテストの失敗調査・修正を依頼された | 「E2Eテストが落ちているので直して」 |

## 前提条件

| 項目 | 要件 |
|------|------|
| Docker | daemon が起動していること |
| e2e-browserイメージ | `e2e-browser:latest` が存在するか `$E2E_DATA/docker/` にDockerfileがあること |
| テスト対象アプリ | 起動済みでアクセス可能であること |
| DB接続情報 | ユーザーが提供できること |

## 概要

Docker コンテナ内で Playwright + Bun によるブラウザE2Eテスト(UI操作 + DB検証 + 全ステップスクリーンショット)を生成・実行・レポートする。
プロジェクトディレクトリには一切ファイルを配置しない。

表示モード:
- `headless`: ヘッドレス実行(デフォルト、CI向き)
- `wslg`: WSL2のXサーバー経由でネイティブウィンドウ表示
- `novnc`: ブラウザで `http://localhost:6080/vnc.html` を開いてリアルタイム視聴

## パス定義

```bash
E2E_DATA="$HOME/.local/share/e2e-browser"
E2E_WORK="/tmp/e2e-browser-$(echo "$PWD" | md5sum | cut -c1-12)"
```

---

## Phase 0: 環境チェック

### 0-1. イメージ確認

```bash
docker image inspect e2e-browser:latest > /dev/null 2>&1 || \
  docker build -t e2e-browser:latest "$E2E_DATA/docker/"
```

### 0-2. workspace作成

```bash
mkdir -p "$E2E_WORK"/{tests,fixtures,screenshots}
```

### 0-3. .env.e2e 生成

`$E2E_WORK/.env.e2e` が存在しなければユーザーに確認:
- DB種別(PostgreSQL / SQL Server / MySQL / SQLite)
- テスト対象アプリURL(デフォルト: http://host.docker.internal:8080)
- DB接続情報
- 表示モード(headless / wslg / novnc)
- headed時の操作速度 E2E_SLOW_MO ミリ秒(デフォルト: 300)

.env.e2e テンプレート:
```env
DB_CLIENT=pg
DB_HOST=e2e-db
DB_PORT=5432
DB_NAME=app_e2e
DB_USER=test
DB_PASSWORD=test
E2E_BASE_URL=http://host.docker.internal:8080
E2E_DISPLAY=headless
E2E_SLOW_MO=300
```

### 0-4. docker-compose.e2e.yml 生成

`$E2E_DATA/compose-templates/` からDB種別に応じたテンプレートを `$E2E_WORK/docker-compose.e2e.yml` にコピー。

**E2E_DISPLAY=wslg の場合:**
compose内 e2e-runner の volumes に以下を追加(コメント解除):
```yaml
      - /tmp/.X11-unix:/tmp/.X11-unix:ro
```
かつ environment に追加:
```yaml
      environment:
        - DISPLAY=${DISPLAY:-:0}
```

**E2E_DISPLAY=novnc の場合:**
テンプレートのまま(port 6080 は既に含まれている)。

**E2E_DISPLAY=headless の場合:**
テンプレートのまま。

---

## Phase 1: コンテナ起動

```bash
curl -sf "${E2E_BASE_URL:-http://localhost:8080}" > /dev/null
docker compose -f "$E2E_WORK/docker-compose.e2e.yml" up -d e2e-db
```

ヘルスチェック通過を待つ。

**noVNC の場合:**
テスト実行前にユーザーに案内:
```
http://localhost:6080/vnc.html をブラウザで開いてください。
テスト実行中のChrome画面がリアルタイムで表示されます。
```

---

## Phase 2: テスト生成

### 2-1. シナリオ設計

ユーザーに確認: URL、操作手順、期待UI表示、検証DB。

### 2-2. Fixture JSON

`$E2E_WORK/fixtures/<feature>/<scenario>.json`

### 2-3. テストコード

`$E2E_WORK/tests/<feature>/<scenario>.spec.ts`

全操作で `captureStep` / `captureState` を使いスクリーンショットを撮る:

```typescript
import { test, expect } from '@playwright/test';
import { destroyDb } from '../../helpers/db-client';
import { dbAssert } from '../../helpers/db-assert';
import { seed } from '../../helpers/db-seed';
import { cleanup } from '../../helpers/db-cleanup';
import { beginCapture, captureStep, captureState } from '../../helpers/screenshot';

test.describe('<機能名>', () => {
  test.beforeEach(async () => {
    await seed('<feature>/<scenario>.json');
  });

  test('<シナリオ>', async ({ page }) => {
    beginCapture('<シナリオ名>');

    await captureStep(page, '画面表示', async () => {
      await page.goto('<URL>');
    });

    await captureStep(page, '入力', async () => {
      await page.fill('[data-testid="..."]', '値');
    });

    await captureStep(page, '送信', async () => {
      await page.click('[data-testid="..."]');
      await page.waitForResponse(resp => resp.url().includes('/api/') && resp.status() === 200);
    });

    await captureState(page, '結果画面');
    await expect(page.locator('[data-testid="..."]')).toBeVisible();

    await dbAssert.exists('table', { column: 'expected_value' });
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
- 全操作を `captureStep` で囲む
- 検証ポイントで `captureState`
- `beginCapture` をテスト冒頭で必ず呼ぶ
- 1テスト1シナリオ、他テストに依存しない
- セレクタ優先: `data-testid` > `role` > `label` > CSS selector
- `page.waitForTimeout()` 禁止
- `afterAll` で `destroyDb()` 必須

**helpers API:**
- `beginCapture(testName)` / `captureStep(page, label, action)` / `captureState(page, label)`
- `dbAssert.exists / notExists / count / columnEquals / dump`
- `seed(fixturePath)` / `cleanup(tables)`

---

## Phase 3: テスト実行

```bash
docker compose -f "$E2E_WORK/docker-compose.e2e.yml" \
  run --rm --service-ports e2e-runner \
  bun run playwright test tests/<feature>/<scenario>.spec.ts \
  --reporter=list --project=chrome
```

> `--service-ports` で noVNC のポート 6080 をホストに公開する。

---

## Phase 4: レポート

### 成功時
pass件数・所要時間 + スクリーンショット一覧を報告。

### 失敗時
1. エラーメッセージ
2. 失敗前後のスクリーンショット(`$E2E_WORK/screenshots/`)
3. DB実値ダンプ

修正案提示 → ユーザー承認後 → Phase 3 再実行。

---

## Phase 5: クリーンアップ

```bash
docker compose -f "$E2E_WORK/docker-compose.e2e.yml" down -v
rm -rf "$E2E_WORK"
```

---

## 禁止事項

| 禁止操作 | 理由 |
|----------|------|
| `page.waitForTimeout()` | フレーキーテストの原因。`waitForResponse` / `waitForSelector` を使う |
| テスト間の暗黙的DB状態共有 | テスト順序依存・干渉の原因 |
| fixture への本番データ混入 | データ漏洩・破壊リスク |
| テストコード内のハードコード接続情報 | `.env.e2e` 経由で渡す |
| `workers > 1` でのDB操作テスト | 並列実行によるDB競合の原因 |
| ホストへの Node/Bun/npm 直接インストール | Docker内で完結させる |
| プロジェクトディレクトリへのファイル配置 | `$E2E_WORK` 配下のみ使用 |
| `captureStep` / `captureState` なしのUI操作 | スクリーンショット証跡が失われる |
