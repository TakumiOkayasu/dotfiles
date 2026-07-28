# Codex skill recommendations - plugin-only

## 方針

- prompt command 互換は持たない。
- 主要 workflow は `@feat`, `@fix`, `@review`, `@deep-review`, `@security-review`, `@rules-required` などの skill として提供する。
- 詳細手順は skill に置き、`AGENTS.md` は短い不変条件に限定する。
- rules は `rules-inject.sh` と `rules-guard.sh` で編集前に強制する。

## 既存 skill 改善

| skill | 改善 |
| --- | --- |
| `tdd` | 明示的なテスト追加指示で確実に発動するよう trigger を OR 寄りにする |
| `systematic-debugging` | 実行環境なしの場合の static trace mode を明記する |
| `premise-questioning` | high-risk 作業で必須、normal-risk は軽量化する |
| `feature-pruning` | 入力不足時は `[要確認]` を残して棚卸しを進める |
| `empirical-prompt-tuning` | skill 変更時の eval scenario と hold-out を標準化する |
| `failure-logging` | `codex_tmp/failure_log/` と単一 markdown の path 不整合を解消する |
| `test-coverage-guard` | `tdd` という実 skill 名へ表記を統一する |
| `refactoring` | 判定不能な「デッドライン直前」ではなく risk gate を使う |
| `measure` | 明白な N+1 / O(n^2) は計測前に設計バグとして扱う例外を定義する |

## Done when

- `python3 scripts/sync-codex-plugin.py --repo . --clean` が成功
- `python3 scripts/verify-codex-plugin.py --repo .` が成功
- plugin 内に `prompts/` が存在しない
- `codex/hooks/prompt-command-expand.sh`, `codex/bin/codex-prompt`, `codex/bin/codex-cmd` が存在しない
