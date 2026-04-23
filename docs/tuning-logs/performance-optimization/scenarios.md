# performance-optimization シナリオカタログ

empirical-prompt-tuning でチューニングするための評価シナリオ。**iter 開始後は変更しない**。

- 対象スキル: `claude/skills/performance-optimization/SKILL.md`
- description: 「パフォーマンス最適化やプロファイリング時に使用。計測手法、ボトルネック特定、負荷テスト、レポート出力をカバー。」
- 収束目標: **連続2** イテレーション（典型スキル）

## 隣接スキルとの境界（iter 0 整合確認の焦点）

| スキル | 対比 |
|---|---|
| systematic-debugging | sd = **誤動作・バグの原因分析**、perf-opt = **動作は正しいが遅い**の計測ベース改善 |
| refactoring | refactoring = 振る舞い不変の**構造改善**（計測不要）、perf-opt = **計測で効果実証**した上での変更（振る舞い変更も可） |
| test-coverage-guard | TCG = テストの信頼性検証、perf-opt = 本体コードの性能検証（別観点） |
| tdd | tdd = 正しさの駆動、perf-opt = 速さの駆動。ベンチは RED-GREEN の対象外 |
| failure-logging | failure-logging = 失敗記録、perf-opt = 失敗を含めず計測値を蓄積（別目的） |

## Baseline シナリオ

### シナリオA（中央値: API エンドポイント遅延の改善依頼）

**状況**:
ユーザー「`GET /api/orders/:user_id` が遅い。管理画面で一覧開くのに 5 秒かかると苦情が来た。Rails 7 + PostgreSQL 15、ステージング環境あり。ローカル Docker で再現可能」

```ruby
# app/controllers/orders_controller.rb
class OrdersController < ApplicationController
  def index
    @orders = Order.where(user_id: params[:user_id])
    @orders.each do |order|
      order.items  # N+1 の疑いあり
      order.customer  # N+1 の疑いあり
    end
    render json: @orders.map { |o|
      {
        id: o.id,
        total: o.items.sum { |i| i.price * i.quantity },
        customer_name: o.customer.name,
      }
    }
  end
end

# Order has_many :items, belongs_to :customer
# 1 user あたり 平均 200 orders、1 order あたり 平均 5 items
```

**要件チェックリスト**（○/×/部分的で判定、[critical] は最低1つ必須）:
1. [critical] **Step 1 でベースライン計測を最初に宣言**（p50/p95/p99 + スロークエリ数）
2. [critical] **プロファイリング → ホットスポット特定 → 最適化** の順序を遵守（いきなり「includes つけろ」禁止）
3. [critical] **1 最適化 = 1 計測** の原則を明示（複数同時適用は原因特定不能）
4. N+1 クエリ（orders.items / orders.customer）を識別し、eager load（`includes`）適用を提案
5. `items.sum { ... }` のループ内計算について、DB 側集約（SUM）への置換可否を検討
6. レポートテンプレート（ベースライン / 実施内容 / 改善結果 / 残課題）で結果報告の雛形を提示
7. 鉄則「50%を占める処理を2倍速くせよ。1%の処理を10倍速くするな」の適用（ホットスポット優先）

### シナリオB（edge 1: 計測環境なし・本番のみ遅い）

**状況**:
ユーザー「本番でだけ特定の時間帯に API が遅くなる。ステージングには同じデータ量がない。k6 のスクリプトもない。とにかく本番で直接 APM 仕込んで原因見つけて直してほしい。リリースは今週金曜」

**要件チェックリスト**:
1. [critical] **前提条件「計測環境が明確」「ベースライン計測が可能」が未充足であることを明示**
2. [critical] **禁止事項「本番環境でのみ計測する」を引用**し、本番直接計測+直接変更を拒否
3. [critical] **ステージング再現 or 本番同等のデータ投入環境の整備を先行依頼**
4. 本番で取得可能な既存テレメトリ（APM / スロークエリログ / アクセスログ）の収集と分析提案（変更を伴わない観測は可）
5. 時間帯依存（バッチ/cron/他ジョブ競合/cold cache）の仮説立案を促す（systematic-debugging の領域との差分を意識）
6. 急ぎ圧力（金曜リリース）に流されず、計測→原因→最適化→検証の順序を崩さない
7. 「本番でのみ再現」そのものは perf-opt の範囲外であり、再現環境構築が前提条件充足の最短経路と説明

### シナリオC（edge 2: 闇雲最適化の「ついで依頼」）

**状況**:
ユーザー「DB が遅い。`users`、`orders`、`payments` の全カラムに片っ端からインデックス貼って。ついでに ORM が遅そうだから気になるクエリは全部 raw SQL に置き換えて。あと Redis キャッシュもとりあえず全エンドポイントに入れとこう」

```sql
-- 現状のスロークエリログ（該当1件のみ）
SELECT o.* FROM orders o
  WHERE o.user_id = 42 AND o.status = 'pending'
  ORDER BY o.created_at DESC LIMIT 20;
-- 平均 800ms、500万行
```

**要件チェックリスト**:
1. [critical] **禁止事項「インデックスを闇雲に追加する」「ORM を迂回して生SQLを書く」「invalidation 戦略なしにキャッシュを追加する」の3件を引用**
2. [critical] **スロークエリが1件のみ特定されている状態で、全カラムインデックス+全面 raw SQL 化+全面キャッシュを拒否**
3. [critical] **実行計画（EXPLAIN）→ 対象クエリ限定の複合インデックス設計（例: `(user_id, status, created_at DESC)`）を先に提案**
4. ORM 迂回は「計測で必要と証明されてから検討」を引用し、現状証拠不足を指摘
5. キャッシュ導入は invalidation 戦略（TTL / 依存更新時の失効）とセットで検討する必要があると説明
6. RDBMS 共通の診断手順（EXPLAIN / スロークエリログ / 未使用インデックス検出）を順序立てて提示
7. 「複数の最適化を同時に適用する」禁止を引用し、1 変更ずつ計測する運用に引き戻す

## Hold-out シナリオ（収束判定時のみ使用）

### シナリオD（バグ調査依頼 = 発動すべきでない）

**状況**:
ユーザー「`calculate_total` が時々マイナスの金額を返してくる。直近 1 時間で 3 件、全部ユーザーごとに違う。処理時間は正常（100ms 以内）。直してほしい」

```ruby
def calculate_total(items)
  items.reduce(0) { |sum, i| sum + i.price * i.quantity }
  # 時々 -1500 等マイナスを返す
end
```

**要件チェックリスト**:
1. [critical] **本スキル（performance-optimization）を発動せず、systematic-debugging / tdd へ委譲**
2. [critical] **「動作が正しいが遅い」ではなく「動作が誤っている」ケースと判別**（処理時間は正常と明記されている）
3. [critical] **description「パフォーマンス最適化やプロファイリング時に使用」に該当しないことを認識**
4. systematic-debugging の 4 フェーズ（現象→仮説→検証→修正）経路を提案
5. 修正後に TDD で回帰テストを追加し、再発防止を図る経路を提示
6. 誤発動阻止: 「速くしてほしい」系の語が含まれていないことを根拠に非対象判定

## 運用メモ

- シナリオ A は最頻出「API 遅延 + N+1」の中央値。鉄則・手順・レポートテンプレの3本柱を一度に試す
- シナリオ B は前提条件（計測環境）未充足下での急ぎ圧力試験（systematic-debugging との境界を意識）
- シナリオ C は「闇雲最適化」誘惑で、禁止事項表 3 件（闇雲インデックス / ORM 迂回 / キャッシュ invalidation 欠如）の境界試験
- シナリオ D は hold-out として、**バグ修正依頼での誤発動回避**（systematic-debugging 境界）を試す
