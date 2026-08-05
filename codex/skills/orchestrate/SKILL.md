---
# codex_port_source: claude/skills/orchestrate/SKILL.md
name: orchestrate
description: 仕様が固まった複数 task の実装を、計画 → subagent 実装 → 2 段階レビュー (仕様適合 → 品質) で一気通貫に回す。task に分解できる機能追加・改修をまとめて自走実装したいときに使う。「実装計画」「計画立てて」「plan して」「まとめて実装」「全部作って」「順番に実装」「タスク分解」「subagent で回す」「2 段階レビュー」で起動。単発の小修正 (→ feat/fix) や設計未確定 (→ consult) では使わない。
---

# Plan and Review

<!-- codex-port: managed; source=claude/skills/orchestrate/SKILL.md; generated-by=scripts/port-claude-assets-to-codex.py -->

## Codex portability notes

- This file was ported from `claude/skills/orchestrate/SKILL.md`.
- Codex skills are packaged into `plugins/dotfile-work-codex` or `plugins/dotfile-work-codex-extra`; `install.sh` should not duplicate them into `${HOME}/.agents/skills` in plugin-only mode.
- Rules are not automatically loaded. Read `RULES_CORE.md`, `RULES_INDEX.md`, and only the detailed rules applicable to the task.
- Claude slash-command references should be invoked through Codex plugin/local skills such as `@feat`, `@fix`, `@deep-review`, or `/skills`. Do not use custom `/prompt:*` commands.
- Subagent usage must follow `${HOME}/.codex/SUBAGENTS.md` and the current Codex tool contract.

## 概要

仕様が確定した複数タスクの実装を、**計画 → subagent 実装 → 2 段階レビュー**の一本道で回す。
3 つの原則で構成する: ①文脈ゼロの後輩でも辿れる計画粒度、②task ごと fresh subagent、③仕様適合と品質を分離した 2 段階レビュー。

**実行は連続させる。** 計画承認後は task 間で「続けますか?」と止まらず、全 task を通しで実行する。レビュー → 差し戻し → 再レビューのループも自走させる。停止するのは次の 3 つだけ: 副作用承認ゲート (後述) / 自力解決できない BLOCK / 全 task 完了。進捗の逐次報告や確認プロンプトはユーザーの時間を浪費するため出さない。

設計判断が未確定なら本スキルに入らず `consult` へ。仕様が固まっていることが前提。

## トリガー条件

- **明示**: 「実装計画」「計画立てて」「plan して」「タスク分解して」「2 段階レビュー」「spec 適合チェック」
- **自然発話**: 「まとめて実装」「全部作って」「順番に実装して」「一気にやって」「subagent で回して」「複数機能を実装」
- **状況**: 確定仕様/設計ドキュメントを渡されて「これ実装して」、複数の独立した変更を一括依頼された
- `@orchestrate` 直接起動

## 非対象

- 単一ファイルの小修正 → `feat` / `fix` 直行
- 設計判断・技術選定が未確定 → `consult`
- 振る舞い保持の整理のみ → `refactoring`
- レビュー単体 → `deep-review`

## 鉄則

- 計画にプレースホルダを残さない。`TBD` / `後で実装` / `適切にエラー処理` は計画の失敗とみなす
- 1 task = fresh subagent。親セッションの文脈を継承させず、必要な情報だけを構築して渡す
- レビューは**仕様適合 → 品質**の順。順序を入れ替えない (過剰実装を品質レビュー前に削るため)
- 仕様適合が ✅ になるまで品質レビュー (`deep-review`) に進まない
- subagent 起動不可なら親単独実装で代替せず、その旨を報告してユーザー判断を仰ぐ
- main / master 上で実装着手しない。新規ブランチ必須 (→ global の Git ワークフロー)
- **連続実行**: 計画承認後は task 間で停止・確認しない。全 task を自走で実行し、レビューループも自動で回す
- **副作用承認ゲート (連続実行の唯一の例外)**: commit / push / 依存追加・更新 / DB スキーマ変更 / 公開 API 契約変更 / 破壊的操作 / 特権コマンド / 外部書き込み は、自走中でも必ず止まって明示承認を得る。subagent にもこの境界を渡し、越えさせない (→ `implementation-policy.md`)

## 入出力

| 入力 | 内容 |
| --- | --- |
| 確定済み仕様 | `docs/specs/*` または会話中の合意済み設計 |
| `ユーザー指定の保存先` | 計画の保存先パス (省略時は `.codex/plans/YYYY-MM-DD-<topic>.md`) |
| 適用rules | `RULES_CORE.md`と`RULES_INDEX.md`を読み、taskに該当する詳細ruleだけを明示的に読む |

| 出力 | 内容 |
| --- | --- |
| 実装計画 | task 分解済み Markdown (粒度規約準拠) |
| 実装差分 | task ごとの作業差分 + commit message 案 |
| レビュー結果 | 仕様適合判定 + `deep-review` 判定 (BLOCK/WARN/PASS) |

## 手順

### Step 1: 仕様読込と計画スコープ確認

確定仕様を読む。複数の独立サブシステムを含むなら、計画を分割する (1 計画 = 単体で動作・テスト可能な単位)。分割が必要なら着手前にユーザーに提示する。

### Step 2: ファイル構成の確定

task 分解の前に、作成・変更するファイルと各責務を列挙する。

- 1 ファイル 1 責務。境界とインターフェースを明確にする
- 同時に変わるものは同じ場所に置く。技術レイヤーでなく責務で分割する
- 既存コードベースでは既存パターンに従う。肥大化したファイルに触る場合のみ分割を計画に含める

### Step 3: task 分解 (粒度規約)

**1 step = 1 アクション (2〜5 分)** に分解する。TDD の RED-GREEN-REFACTOR を step に展開する。

```text
- [ ] Step 1: 失敗するテストを書く        (コードブロック必須)
- [ ] Step 2: テストを実行し失敗を確認      (コマンド + 期待出力)
- [ ] Step 3: 最小実装でパスさせる          (コードブロック必須)
- [ ] Step 4: テストを実行しパスを確認      (コマンド + 期待出力)
- [ ] Step 5: 変更内容を要約                (commit message 案必須)
```

各 task のヘッダーに変更ファイルを明示する:

```text
### Task N: <コンポーネント名>
Files:
- 作成: exact/path/to/file.ts
- 変更: exact/path/to/existing.ts:123-145
- テスト: tests/exact/path/to/file.test.ts
```

dispatch 前に、全 task が単体で意味を成すこと・型と関数名が task 間で一貫していること (Task 3 の `clearLayers()` が Task 7 で `clearFullLayers()` になっていない) を揃える。計画にプレースホルダを残さない。

#### 禁止プレースホルダ

| 禁止パターン | 理由 |
| --- | --- |
| `TBD` / `TODO` / `後で実装` / `詳細は埋める` | 計画の体を成していない |
| `適切にエラー処理` / `バリデーション追加` / `エッジケース対応` | 何をするか不明 |
| 「テストを書く」(テストコードなし) | step は実コードを含む |
| 「Task N と同様」(コード省略) | subagent は task を順不同で読みうる |
| 未定義の型・関数・メソッドへの参照 | どこにも実体がない |

### Step 4: task ごとに subagent 実装

task を 1 つずつ処理する。**並列 dispatch しない** (差分競合のため)。各 task で:

1. task 全文 + 周辺文脈 + 担当範囲を構築し、fresh subagent に渡す (計画ファイルを読ませず全文を渡す)
2. subagent が質問したら実装着手前に回答する
3. subagent が TDD で実装・テスト・自己レビューする
4. subagent の status を処理する (下表)

| status | 対応 |
| --- | --- |
| DONE | 仕様適合レビュー (Step 5) へ |
| DONE_WITH_CONCERNS | 懸念を読む。正しさ・スコープに関わるならレビュー前に対処 |
| NEEDS_CONTEXT | 不足文脈を渡して再 dispatch (自走。ユーザーに聞かない) |
| BLOCKED | **種別で分岐** (下表)。自力解決を試みてから、解決不能なもののみエスカレーション |

#### BLOCKED 種別分岐

連続実行を止めないため、BLOCK は種別を見極めて自力リカバリを試す。エスカレーションは「人間にしか決められない種別」に限る。

| BLOCK 種別 | 自力リカバリ | エスカレーション |
| --- | --- | --- |
| 文脈不足 (情報が足りない) | 周辺コード・rules・既存実装を自分で調査し、補足して再 dispatch | 調査しても不明な外部仕様のみ |
| 推論力不足 (task が難しい) | reasoning_effort を1段階上げて再 dispatch | 最大の reasoning_effort でも解けない場合 |
| task 過大 (1 task に収まらない) | task をその場で分割し、順に dispatch | 分割しても各片が依然過大な場合 |
| 計画の誤り (spec/計画が矛盾) | — (自力修正しない) | **即エスカレーション**。計画はユーザー資産 |
| 副作用承認待ち (commit/依存/DB 等) | — (越えない) | **即停止して承認を仰ぐ** (鉄則) |

同一 model・無変更でのリトライは禁止。リカバリは「model 昇格 → 分割 → 別アプローチ」の順で必ず何かを変える。文脈不足・推論不足・過大の 3 種は自走でリカバリし、計画の誤りと副作用のみ人間を呼ぶ。

### Step 5: 仕様適合レビュー (1 段目)

実装が**仕様通りか**を検査する。品質ではなく過不足を見る。専用 subagent は立てず、親の内省で行う (推測指摘を避けるため差分は実コードで確認する):

- [ ] 仕様の各要件に対応する実装がある (実装漏れがない)
- [ ] 仕様にない機能を足していない (過剰実装がない。例: 要求にない `--json` フラグ)
- [ ] 仕様の具体記述を満たしている (例: 仕様「100 件ごと進捗報告」を実装したか)

過不足があれば実装 subagent に差し戻して修正させ、再度この Gate を通す。✅ になるまで Step 6 に進まない。

### Step 6: 品質レビュー (2 段目)

仕様適合 ✅ を確認後、`deep-review` を起動する (セキュリティ/パフォーマンス/保守性の 3 並列 + synthesis)。

`deep-review` の判定に従う:

| 判定 | 対応 |
| --- | --- |
| BLOCK (Critical ≥ 1) | 実装 subagent に差し戻して自動修正 → Step 5 から再ゲート (自走) |
| WARN (Warning ≥ 3) | 副作用を伴わない修正は自走で対処し、`.codex/notes/{task-id}.md` に対処内容を記録。副作用を伴う対処 (依存追加等) のみ承認を仰ぐ |
| PASS | task 完了。次 task (Step 4) へ |

BLOCK/WARN とも、修正が副作用承認ゲートに触れない限り止まらず自走する。Critical の差し戻しループも人間を介さず回す。

### Step 7: 全 task 完了後

全 task が PASS したら、実装全体に対し最終 `deep-review` を一度かける。
完了報告の前に、全 task のテストが緑であることとスコープに過不足がないことを確認する。
報告には各 subagent の成果 (`.codex/notes/{task-id}.md` に集約) と、BLOCK で止めた task があればその理由を含める。

## model 選択

task の複雑度と driver/worker の役割を掛け合わせて割り当てる。**各役割を担える最小コストの model** を選ぶ。

| task 種別 / 役割 | 複雑度シグナル | Driver | Worker |
| --- | --- | --- | --- |
| 機械的実装 (1〜2 ファイル・完全仕様) | 隔離された関数、明快な spec | 監督のみ | worker 適 |
| 統合実装 (複数ファイル・連携あり) | パターン適合、結合、デバッグ | 計画/レビュー | worker 可 |
| 設計判断・アーキ・レビュー | 設計判断、広い理解が必要 | driver が担当 | worker 不適 |
| 仕様適合レビュー (Step 5) | 読み取り中心、判定 | driver が担当 | — |
| 品質レビュー (`deep-review`) | 3 観点並列、修正案生成 | `deep-review` 統合 | code-reviewer subagent |

役割分担の原則 (既存方針に準拠):

- **Driver (司令塔)**: 計画・dispatch・レビュー統合・ユーザー対話
- **Worker (実装担当)**: 機械的〜中程度の実装 task を委譲
- driver は高い reasoning_effort、worker は task 複雑度に応じた reasoning_effort
- 1 task が 1〜2 ファイル + 完全な spec なら 低い reasoning_effort の worker で十分。多ファイル結合は reasoning_effort を上げる

## アンチパターン

| 禁止 | 理由 |
| --- | --- |
| 計画にプレースホルダを残す | subagent が実装できない |
| 実装 subagent の並列 dispatch | 差分競合 |
| 計画ファイルを subagent に読ませる | 全文を渡す方が文脈が確実 |
| 仕様適合より先に品質レビュー | 過剰実装を削る前に品質を見ると手戻り |
| レビュー指摘の未対処で次 task へ | 問題が累積する |
| 自己レビューでレビューを代替 | 自己レビューと外部レビューは別物 |
| main/master で実装着手 | Git ワークフロー違反 |
| task 間チェックインの乱発 | 「続けますか?」はユーザーの時間を浪費する。副作用ゲート/解決不能 BLOCK/全完了以外は止まらず実行 |
| 副作用承認ゲートの自走突破 | commit/push/依存/DB/API/破壊的操作は自律実行でも必ず承認を得る。連続実行の唯一の例外 |
| 文脈不足・推論不足・過大 BLOCK で即エスカレーション | まず自力リカバリ (調査/model 昇格/分割) を試す。人間を呼ぶのは計画の誤りと副作用のみ |

## 関連スキル

- 前段 (設計未確定時): `consult` / `arch`
- 実装単位: `tdd` (subagent が各 task で従う) / `feat` / `fix`
- 品質レビュー (2 段目): `deep-review`
- 詰まり対処: `systematic-debugging` (BLOCKED task の根本原因調査)
- Codex 連携: `implementation-router` / `codex-handoff`
