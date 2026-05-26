---
codex_port_source: claude/skills/architecture-design/SKILL.md
name: architecture-design
description: クラス・モジュールのアーキテクチャ設計時に使用。レイヤー構造の決定、コンポーネントの配置、責務分割、合成と継承の判断、依存関係の整理をカバー。新規コンポーネント追加や既存設計のリファクタリング時に発動。常に守る不変条件は hierarchical-architecture ルール、疑似コードからのインターフェース起こしは interface-first-design スキルを参照。
---

# Architecture Design

<!-- codex-port: managed; source=claude/skills/architecture-design/SKILL.md; generated-by=scripts/port-claude-assets-to-codex.py -->

## Codex portability notes

- This file was ported from `claude/skills/architecture-design/SKILL.md`.
- Codex skills are installed under `~/.agents/skills/<skill>/SKILL.md` by `install.sh`.
- Global and project rules live under `~/.codex/rules/*.md`; do not assume they are automatically loaded unless the rules-inject hook injected them into context.
- Claude slash-command references should be invoked through `prompt:<name>` or `codex/prompts/commands/<name>.md`.
- Subagent usage must follow `~/.codex/SUBAGENTS.md` and the current Codex tool contract.

コンポーネントをどのレイヤーに置き、どう責務分割し、合成で組み立てるかの設計手順。常に守る不変条件 (依存方向・継承深度・命名等) は `hierarchical-architecture` ルールにあり、本スキルはその不変条件を満たす設計の進め方を扱う。

## レイヤー構造

| # | 役割 | 責務 | 命名例 |
| --- | --- | --- | --- |
| 1 | Interface | 契約の定義 (単一責任) | `Readable`, `Writable` |
| 2 | 管理層 | 下位の生成・破棄・ライフサイクル | `*Manager`, `*Context` |
| 3 | 提供層 | 同種能力のグルーピング | `*Provider`, `*Registry` |
| 4 | 操作層 | 特定リソースへのアクセス | `*Accessor`, `*Client` |
| 5 | サブコンポーネント (任意) | ドメイン固有オブジェクト | `*Record`, `*Entity`, `*Value` |
| 6 | Platform | プラットフォーム固有実装 | — |

## 設計手順

1. レイヤーを特定する — そのクラス/モジュールは管理 / 提供 / 操作 / Platform のどれか
2. 依存先が自分より下位かを確認する (上位・横・段階飛ばしの依存は不可)
3. 単一責任の契約 (インターフェース) を先に書く — 疑似コードからの起こし方は `interface-first-design` スキル
4. コンストラクタ注入でインターフェースに依存して組み立てる
5. サフィックスでレイヤー役割が読み取れる命名にする

## 合成優先

- 小さく独立した機能単位を組み合わせて複雑な機能を実現する
- 機能の追加・変更時、既存コードへの影響を最小化する
- 組み合わせる順序・構成を外部から制御可能にする (DI)
- 各実装は他の実装を知らない。バッファ管理・最適化などの内部は完全に隠蔽する

## 良い設計 / 悪い設計の兆候

良い設計: 新しい実装クラスを追加するだけで拡張でき、既存コードは変更不要。インスタンス化時の組み合わせで挙動を制御できる。各クラスが単一責務。

悪い設計: 新機能のたびに引数・メンバ変数・条件分岐が増える。新機能追加に既存クラスの変更が必要。1 クラスが複数責務を抱える。

## 継承を採用してよい場面

「悪い設計の兆候」に該当しないことを条件に、次は継承を許可する。

- フレームワーク/ランタイムが要求する基底 (React `Component`, Django `View` 等)
- is-a 関係が明確なドメイン階層、値オブジェクト階層
- Mixin (`LoginRequiredMixin` 等)

それ以外の能力・振る舞いの差分は、継承ではなく合成 (コンストラクタ注入) で注入する。継承深度は 2 段までを目安とする。

## 入力の抽象化

`Raw Input` (引数・パス文字列等の生データ) → `Calibrated Input` (検証・正規化済み) → `Intent` (意図レベル、例 `TargetFile`) の順で変換する。アプリケーションコードは `Intent` のみに依存する。

## リソースのライフサイクル

生成と利用を分離する。確保と解放はワンセットにし、管理層が自律的に確保・解放する。

## ユーザー実例

### Context パターン (階層化)

責務スコープを段階的に絞る Context の階層構造。pre-omusubi (C++17 組み込み) と ISLe で実証済み。

```
SystemContext       # システム全体のライフサイクル管理
  └─ CategoryContext   # 機能カテゴリ単位 (通信 / 描画 / 入力 等)
       └─ DeviceContext    # 個別デバイス・リソース単位
```

親 Context が子の生成・破棄・ライフサイクルを所有する。子は親の API を知らない (依存は上位→下位のみ)。新しいカテゴリやデバイスを追加するときは対応する Context を 1 つ作り、親に登録するだけで済む。

### *able 単一責任インターフェース

能力ごとに最小単位のインターフェースを切り、命名は `動詞 + able` にする。インターフェース分離原則 (ISP) の徹底適用。

| インターフェース | メソッド | 責務 |
| --- | --- | --- |
| `Readable` | `read()` | 読み取り |
| `Writable` | `write()` | 書き込み |
| `Drawable` | `draw()` | 描画 |
| `Resettable` | `reset()` | リセット |

複数能力が必要なクラスは複数の `*able` を実装する (Mixin 的合成、継承ではない)。インターフェース 1 つ = メソッド 1 つを原則とし、メソッドが増えそうなら別インターフェースに分割する。

## 複数設計案の並列出し (明示要求時のみ)

dispatch 形式・並列起動の作法は `~/.codex/SUBAGENTS.md` を参照。

### 起動条件

以下のいずれかに該当する場合、**3 並列 subagent で異なる設計案を出させて比較する**:

- ユーザーから「複数案を出して」「設計の選択肢を比較したい」と明示要求された
- レイヤー構造に複数の妥当な切り方があり、選択基準が定まらない
- 既存コードが歴史的経緯で破綻しており、再設計の方向性が定まらない

### dispatch 内容

各 subagent に対象機能の要件 + `hierarchical-architecture` 不変条件を渡し、**互いに異なるレイヤー切り分け案**を 1 つ出させる (例: 案 A = 管理層厚め / 案 B = 提供層分割 / 案 C = Platform 層に逃がす)。subagent 種別は `general-purpose` (`Plan` は単一計画立案用途のため、3 並列で互いに異なる案を出す本節と不整合)。

### 評価軸 (親が事後集約)

| 軸 | 確認内容 |
| --- | --- |
| 単一責任の充足度 | 各クラス・モジュールが 1 責務に収まっているか |
| 依存方向の単純さ | 上位→下位の純度、横参照・段階飛ばしの有無 |
| 機能追加時の影響範囲 | 新クラス追加で済むか / 既存変更が必要か |
| インターフェース数 | 薄さ (必要最小限のメソッドのみか) |

### 起動しないケース

既存パターン (DI + 単一 Manager + 複数 Provider 等) でほぼ自明な設計 / 1 クラス追加レベルの局所変更 / `premise-questioning` が必要な「方針自体の妥当性」検証段階。本 skill は方針確定後の**設計形状の比較**専用。
