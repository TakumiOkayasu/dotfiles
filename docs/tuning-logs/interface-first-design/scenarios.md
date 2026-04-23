# interface-first-design シナリオカタログ

empirical-prompt-tuning でチューニングするための評価シナリオ。**iter 開始後は変更しない**。

- 対象スキル: `claude/skills/interface-first-design/SKILL.md`
- description: 「機能追加・クラス設計・interface設計・依存関係整理・責務分割時に使用。疑似コードから interface→クラス→TDD→実装の順で設計する。TDDスキルの前段。」
- 収束目標: **連続3** イテレーション（重要スキル）

## 隣接スキルとの境界（iter 0 整合確認の焦点）

| スキル | 対比 |
|---|---|
| refactoring | refactoring = 振る舞い**保証**しながらコード構造改善、iface-first = 設計**変更**（構造変更を伴う機能追加や責務分割） |
| tdd | iface-first = 実装前の設計、tdd = 実装。iface-first → tdd の順 |
| consultation | consultation = 判断相談（設計方針に迷い）、iface-first = 設計**方法**（疑似コード→interface→組み立て） |

## Baseline シナリオ

### シナリオA（中央値: 新規機能の interface 設計）

**状況**:
TypeScript バックエンドで「注文確定処理」を新規実装することになった。要件は `注文内容（商品リスト、ユーザーID）を受け取り、在庫チェック → 合計計算 → 決済処理 → 確定メール送信 → 注文ID返却` の流れ。在庫エラー時は中断、決済失敗時は在庫を戻す。ユーザーは「TDD の前段として設計してほしい」と依頼。

**要件チェックリスト**:
1. [critical] **Step 1: 疑似コードを実装前に描く**（given / when / then 形式、SKILL.md テンプレート準拠）
2. [critical] **1 interface = 1 メソッド = 1 責務** の ISP 原則を守る（SKILL.md L109, Anti-pattern 3）
3. 動詞→メソッド / 名詞→データ型 / 分岐→エラー型 or 戻り値バリアント の変換ルールを適用
4. フレームワーク固有型（Request / Response / ORM の Row や Paginator）を interface に含めない
5. 戻り値を `Ok | Error` の2値で成功/失敗を明示
6. 上位層（OrderService 相当）で組み立て、下位 interface は「何を」を知らない
7. 設計完了チェックリスト（10項目）をチェックして提示する
8. TDD スキルへの移行を明示する（SKILL.md Step 4）

### シナリオB（edge 1: 責務肥大クラスの分割）

**状況**:
既存 Python プロジェクトの `UserService` クラスが 500 行に膨らみ、`find(id)` / `save(user)` / `delete(id)` / `send_welcome_email(user)` / `export_to_csv(users)` の 5 メソッドを持つ。ユーザーは「責務を分割したい、interface 設計から考えてほしい」と依頼。既存コードは触れるが**リファクタリングではなく設計から見直したい**とのこと。

**要件チェックリスト**:
1. [critical] **既存実装をそのまま interface に写さない。疑似コードから書き直す**（Anti-pattern 4）
2. [critical] **refactoring スキルに委譲せず、本スキル（設計変更）で対応する**（ユーザーが「設計から見直したい」と明示しているため境界は iface-first 側）
3. 分割後の複数 interface（Reader / Writer / Deleter / Notifier / Exporter 等）を ISP 原則で提示
4. 各 interface のメソッドは1つに絞る（複数なら責務混在を疑う）
5. hierarchical-architecture の「同レイヤー間で interface を直接参照しない」を考慮する
6. 上位層での組み立て（どの Service が複数 interface を合成するか）を提示する
7. 「interface にメソッドを追加しても既存実装が壊れないか」チェック項目を確認

### シナリオC（edge 2: 既存実装から interface を逆算しようとする危険）

**状況**:
既存の Rails プロジェクトで `Article` モデル（ActiveRecord）があり、ユーザーが「この Article を interface 化して testable にしたい。とりあえず `find`、`all`、`where`、`paginate` のメソッドを interface に写してくれれば」と依頼。ユーザーは急いでいて「早く作って」と促している。

**要件チェックリスト**:
1. [critical] **既存実装から interface を写さず、疑似コードから書き直すことをユーザーに説明する**（Anti-pattern 4 を名指しで提示）
2. [critical] **ORM 固有型（ActiveRecord::Relation, Paginator 等）を interface に含めない**（SKILL.md L229 原則、Anti-pattern 4）
3. ユーザーが急いでいても鉄則（設計は必ず実装前 / 疑似コードを省略しない）を曲げない
4. 「記事を読む」「記事一覧を絞り込む」など**利用側のフロー**から疑似コードを起こす
5. `find` / `all` / `where` / `paginate` を単純に写すと interface が肥大化し ISP 違反になることを指摘
6. 戻り値の型（`Article | null`、`Article[]`）を明示的に決める

## Hold-out シナリオ（収束判定時のみ使用）

### シナリオD（設計不要の小規模修正での誤発動回避）

**状況**:
ユーザーから「`utils/format_currency.ts` の桁区切り処理でカンマが入らないバグがある。直して」と依頼。対象は純粋関数で既存の単体テストあり、1 ファイル・20 行程度。interface 設計の必要性は低い。

**要件チェックリスト**:
1. [critical] **本スキルのトリガー条件（新規クラス / 責務肥大化 / 依存関係整理 / interface 不明 / TDD 前段）に該当しないと判定し、本スキルを発動しない**
2. [critical] 代わりに適切な隣接スキル（systematic-debugging でバグ原因分析 → tdd で再現テスト → 修正）に誘導する
3. 「interface 設計は本件では過剰」と明示し、理由をトリガー条件に照らして説明する
4. 疑似コードや interface 表を強制的に生成しない（誤発動の兆候）

## 運用メモ

- シナリオ A は純粋な中央値。最も典型的な利用シーン
- シナリオ B は **refactoring スキルとの境界** を試す。ユーザーが「設計から見直したい」と明示するので iface-first が正解
- シナリオ C は **Anti-pattern 4 を実地で回避できるか** を試す。ユーザーの急かしに流されて既存モデルから写すと失敗
- シナリオ D (hold-out) は **誤発動回避**。トリガー条件を正しく評価して「発動しない」判断ができるか
