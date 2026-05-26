# Skills 改善提案

## 方針

Codex 性能を最大化するには、prompt command は薄い router、skill は詳細手順、AGENTS.md は常時守る短い不変条件に分離する。

公式 docs 上、Skills は metadata で発見され、選択時に `SKILL.md` を読む progressive disclosure が前提。従って長い手順を prompt / AGENTS.md に常時入れるより、skill に寄せる方がよい。

## 追加した skill

| Skill | 目的 |
| --- | --- |
| `prompt-command-router` | `/prompt:*` 入力を prompt file に解決する |
| `implementation-router` | feat/fix/test/refactor の risk gate と skill chain 選定 |
| `deep-review` | security / performance / maintainability の統合レビュー |
| `consultation` | 2-3案比較と Codex 引き継ぎ作成 |
| `codex-handoff` | Context / Tasks / Files / Done when 形式の引き継ぎ |
| `security-review` | security-only レビュー |

## 既存 skill の改善点

### `tdd`

- トリガー条件が「以下のすべてに該当」となっているため、明示的に「テストを書いて」と言われた場合でも keyword / work type の判定次第で発動しない可能性がある。
- 推奨: trigger を OR 型にする。
  - 明示指示がある
  - 実装 / 修正でテスト変更を伴う
  - RED / GREEN / REFACTOR が要求される
- 探索的作業では確認が多くなりすぎるため、`prototype mode` を追加する。prototype mode は本実装前に throwaway branch / throwaway file として扱う。
- `RED確認できない場合` の fallback を明確化する。例: runtime 不可なら static expected-fail proof として扱い、未検証に残す。

### `systematic-debugging`

- 前提条件に「テスト実行環境が利用可能」とあるが、現実には壊れた環境調査もある。
- 推奨: 3 mode に分ける。
  - reproduction mode: 実行可能
  - static trace mode: 実行不可だがコードとログあり
  - environment recovery mode: 実行環境自体が壊れている
- 「再現できなければ修正提案禁止」は維持。ただし static trace mode では「修正提案」ではなく「仮説と検証手順」までは許可する。

### `premise-questioning`

- 3 round subagent 前提は高品質だが、軽中量タスクでは重い。
- 推奨: risk による段階化。
  - high-risk: 3 round 必須
  - normal-risk: 1 round + checklist
  - low-risk: skipped 明示
- `spawn_agent` が使えない場合の parent fallback を冒頭に明記する。
- 数値根拠が出せない場合に再 dispatch としているが、探索初期は数値がないことが多い。`qualitative provisional` ラベルを追加する。

### `feature-pruning`

- 機能リスト全列挙は良い。ただし入力不足時に停止しがち。
- 推奨: 機能リストを推定ではなく「抽出候補」として作り、`[要確認]` を付けて棚卸しに進む。
- UI だけでなく CLI / batch / config / logging にも適用できる例を追加する。
- 削除判定に migration / backward compatibility リスクを追加する。

### `empirical-prompt-tuning`

- 既存の評価軸は強い。prompt command に対しては専用 scenario を `codex/prompts/evals/` に置く運用を標準化する。
- 推奨: prompt 変更時の Done when を追加する。
  - baseline scenario 2本 PASS
  - hold-out 1本 PASS
  - 新規不明瞭点 0
- `tool_uses` / `duration` が取得できない環境の reporting template を短くする。

### `failure-logging`

- `codex_tmp/failure_log/[連番範囲]-fail.md` と `codex-config-info.sh` の `codex_tmp/failure_log.md` が食い違っている。
- 推奨: path を `codex_tmp/failure_log/` に統一する。
- prompt command / skill eval の失敗も記録対象に追加する。

### `test-coverage-guard`

- `test-driven-development` という委譲先名が出るが、実 skill 名は `tdd`。名称を統一する。
- 推奨: mutation testing は3段階にする。
  - tool available: 実行
  - tool unavailable: thought experiment
  - high-risk: 導入提案
- mock 数の基準は言語 / framework により差があるため、硬い禁止ではなく review trigger として扱う。

### `refactoring`

- 「デッドライン直前」は判定不能なので、risk gate に置換する。
- 推奨: characterization test がない場合の entry path を追加する。
- 公開 API 変更を伴う場合は refactoring ではなく migration / design task へ委譲する。

### `performance-optimization`

- ベースライン計測を強制する方針は良い。
- 推奨: `obvious complexity bug` mode を追加する。N+1 / O(n^2) がコード上明白な場合は、計測前に risk と再現条件を示して修正案まで出せる。
- ベンチマークが揺れる場合の run count / warmup / p95 比較の手順を追加する。

### `architecture-design`

- レイヤー分類は明確だが、Web framework / DDD / Clean Architecture など既存 project の命名と衝突する可能性がある。
- 推奨: 「project convention overrides this skill」を冒頭に強調する。
- `*Service` / `*Repository` 許容条件を project-local AGENTS で上書きできるようにする。

### `interface-first-design`

- 疑似コード → interface の流れは良い。
- 推奨: 生成する interface が過剰にならないように `no interface until second implementation` 例外を追加する。
- TypeScript / Go / Python など言語別の interface 最小例を references に分離する。

## AGENTS.md 側で直したい点

- テスト節に `~/.claude/skills/tdd/SKILL.md` 参照が残っている場合は `~/.agents/skills/tdd/SKILL.md` または Codex 認識済み skill 参照へ統一する。
- `~/.codex/rules/` は自動 import 前提にしない方針は維持。ただし重複している rule は AGENTS.md に全文コピーせず、短い invariant + skill/rule 参照に寄せる。
- 常時読む AGENTS.md は短くし、詳細は skills に逃がす。

## Prompt command 側で守るルール

- command prompt は 100-150行以内を目安にする。
- `$ARGUMENTS` を必ず置く。
- `Purpose`, `Routing`, `Constraints`, `Output` の4節を揃える。
- 詳細手順は skill に置く。
- prompt の変更時は `prompt-tune` で eval を回す。

## 優先度

| 優先 | 作業 |
| --- | --- |
| P0 | `/prompt:*` hook + `prompt-command-router` を導入 |
| P0 | `feat.md` / `fix.md` / `deep-review.md` を薄い router に置換 |
| P1 | `implementation-router` を導入し risk gate を一元化 |
| P1 | `deep-review` を prompt から skill に分離 |
| P1 | `failure-logging` の path 不整合を修正 |
| P2 | prompt eval scenario を追加 |
| P2 | skill 名称の不整合を修正 |
| P3 | plugin 化を検討 |
