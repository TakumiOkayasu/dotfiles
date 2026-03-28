# Performance Optimization

## 鉄則

**計測なき最適化は推測。Profile → Measure → Optimize → Verify**

- 最適化前に必ずベースラインを記録する
- 50%を占める処理を2倍速くせよ。1%の処理を10倍速くするな
- 明らかなO(n²)やN+1は設計時に潰す。それ以外は計測してから判断

## 入力

- 最適化対象: 言語・フレームワーク・エンドポイント・処理名
- 目標指標: 応答時間・スループット・メモリ使用量など（例: p95 < 200ms）
- 制約: 変更不可の箇所、デプロイ環境など

## 出力

- ボトルネック特定結果（箇条書き）
- 実施した最適化内容と効果（before/after 数値）
- 残課題リスト
- レポート（後述テンプレート形式）

## プロファイリング手順

1. 言語/フレームワークのプロファイラを有効化する
   - 実行時間の内訳（関数/メソッド単位）を取得
   - フレームワーク付属の開発ツール（SQLログパネル等）があれば併用
2. ホットスポット（累積時間上位）を特定する
3. ホットスポットに対して最適化を検討 → 計測 → 効果確認
4. 改善前後の数値を必ず記録する

## よくあるボトルネック

### N+1クエリ

ループ内で個別クエリを発行している → eager load またはバッチ取得に置き換える。
フレームワークのORM機能（contain, include, prefetch_related 等）を活用する。

### O(n²)アルゴリズム

配列の線形探索をループ内で繰り返している → Set/Map/辞書に変換してO(1)検索にする。
ネストループでの突合 → ハッシュ結合パターンに書き換える。

### 不要な再計算

同じ引数で何度も重い処理を呼んでいる → メモ化（Map/辞書キャッシュ）を導入する。
フレームワークのキャッシュ機構（Cache::remember, @cache, lru_cache 等）があれば活用する。

### メモリリーク / リソース枯渇

- 解放されないイベントリスナ、タイマー、コネクション
- 無制限に成長するキャッシュ（TTL/LRU上限なし）
- 大量データの一括ロード → ストリーミング/チャンク処理に切り替える

## データベース

```sql
-- 複合インデックス(標準SQL)
CREATE INDEX idx_orders_user_date ON orders(user_id, created_at);

-- 必要なカラムのみ取得
SELECT id, name FROM users;  -- ✅
SELECT * FROM users;         -- ❌
```

### RDBMS共通の診断手順

1. **実行計画を確認する**: EXPLAIN 系コマンドで全表スキャン（Full Table Scan）がないか確認
2. **スロークエリログを有効化する**: RDBMS固有の設定で閾値（例: 1秒）以上のクエリを記録
3. **未使用インデックスを検出する**: RDBMS のシステムビュー/統計情報から使用頻度を確認し、不要なら削除
4. **テーブルサイズを把握する**: データ量とインデックス量のバランスを確認

## 負荷テスト

```bash
# k6 (推奨: スクリプトベースで再現性が高い)
k6 run --vus 50 --duration 30s script.js

# wrk (簡易ベンチマーク)
wrk -t4 -c100 -d30s http://localhost:8080/api/endpoint

# Apache Bench (最小限の確認)
ab -n 1000 -c 10 http://localhost:8080/
```

```javascript
// k6 script example
import http from 'k6/http';
import { check } from 'k6';

export default function () {
  const res = http.get('http://localhost:8080/api/items');
  check(res, {
    'status 200': (r) => r.status === 200,
    'latency < 200ms': (r) => r.timings.duration < 200,
  });
}
```

## フロントエンド

```
Core Web Vitals 目標:
  LCP  < 2.5s   (Largest Contentful Paint)
  INP  < 200ms  (Interaction to Next Paint)
  CLS  < 0.1    (Cumulative Layout Shift)

チェックリスト:
  □ 画像: 次世代フォーマット(WebP/AVIF) + lazy loading + width/height 明示
  □ JS: バンドルサイズ確認 (目安: 初期ロード < 300KB gzip)
  □ CSS: 未使用CSS除去、クリティカルCSS インライン化
  □ フォント: font-display: swap + preload
  □ キャッシュ: Cache-Control + ETag 設定
```

## レポートテンプレート

最適化作業後、以下の形式で結果を記録する:

```markdown
## Performance Report - [対象] - [日付]

### ベースライン
- エンドポイント: GET /api/xxx
- p50: ___ms / p95: ___ms / p99: ___ms
- スロークエリ数: ___件 (> 1s)

### 実施した最適化
1. [内容] → [効果: p50 ___ms → ___ms]
2. [内容] → [効果]

### 改善結果
- p50: ___ms → ___ms (___% 改善)
- p95: ___ms → ___ms (___% 改善)

### 残課題
- [ ] ...
```

## 使用例

```
# ボトルネック調査
「/api/orders のレスポンスがp95で800msかかっている。目標はp95 200ms以下。
Django + PostgreSQL 環境でプロファイリングして最適化してほしい。」

# フロントエンド改善
「ECサイトのトップページのLCPが4.2s。Core Web Vitals を合格基準まで改善したい。」

# 負荷テスト実施
「新機能リリース前に /api/search に対してk6で同時50ユーザー・30秒の負荷テストを実施し、
レポートを出力してほしい。」
```

## アンチパターン

```
❌ 計測前に最適化する
❌ 影響の小さい処理に時間をかける
❌ invalidation 戦略なしにキャッシュを追加する
❌ インデックスを闇雲に追加する(書き込み性能が劣化する)
❌ ORM を迂回して生SQLを書く(保守性と引き換えにする前に計測)
```
