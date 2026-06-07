# Codex Global Instructions

## must rule

- 全ての応答は日本語で行うこと。

<!-- codex-performance-profile:start -->

## Performance profile

Keep the default context small and route details through skills.

Priority order:

1. User instruction
2. Project-local `AGENTS.md`
3. Active plugin rules and project rules
4. Active skill workflow
5. General best practice

Before mutating files or running mutating commands:

- Apply `RULES_CORE.md` and `RULES_INDEX.md` immediately.
- Ensure full rules were injected for implementation, review, test, refactor, fix, or any write operation.
- If `rules-guard.sh` blocks a tool, re-read rules instead of bypassing the guard.
- Do not overwrite user changes. Check `git status --short` when editing is involved.
- Never report unrun checks as passed. Report unverified risks explicitly.

Skill routing:

- Use `$feat` for feature implementation.
- Use `$fix` for bugs, failing tests, runtime errors, or unexpected behavior.
- Use `$review` or `$deep-review` for code review.
- Use `$rules-required` when the applicable rules are unclear.
- Use high-effort strategy skills (`premise-questioning`, `feature-pruning`, `deep-review`) only for high-risk tasks.

<!-- codex-performance-profile:end -->

<!-- codex-rules-required: begin -->

### Rules required loading

- 作業開始時、`$HOME/.codex/rules/*.md`、repo-local `codex/rules/*.md`、project-local `.codex/rules/*.md` のうち存在するものを読む。
- `rules-inject.sh` が full content を context に注入した場合、その注入内容を読了済み rules として扱う。
- 実装 / 修正 / リファクタ / テスト追加 / レビュー / 設計では、最低限 `coding-conventions.md`, `implementation-policy.md`, `hallucination-prevention.md`, `hierarchical-architecture.md` を適用する。
- rules 未読または checksum 不一致のまま mutating tool を使わない。`rules-guard.sh` が block した場合は、先に rules を再読する。
- plugin-only 運用では workflow 起動は `$feat`, `$fix`, `$deep-review`, `$rules-required` などの `$skill` を使う。独自 `/prompt:*` や `prompt:*` 互換導線は使わない。
- 競合時は project-local rule を優先し、競合内容を完了報告に明示する。

<!-- codex-rules-required: end -->

## Deterministic Rules Enforcement

- Treat all active `codex/rules/*.md` and plugin `rules/*.md` as mandatory.
- `rules-inject.sh` activates the current rules checksum and injects a compact rules contract.
- `rules-guard.sh` blocks mutating tools when rules are inactive or changed.
- `rules-enforce.sh` scans changed code after edits and at turn stop; if it reports `BLOCK`, fix the violations before final output.
- For semantic rules that cannot be fully scanned, use `$rules-compliance-review`; for large/high-risk diffs, dispatch one rules-only review subagent and then parent session makes the final decision.

## RTK

- `rtk` が利用可能な環境では、Bash コマンドは原則 `rtk <command>` で実行して出力を圧縮する。
- `rtk gain`, `rtk gain --history`, `rtk proxy <command>` は必要時のみ使う。
- safety hooks は `rtk` wrapper の内側コマンドを検査する。禁止されるローカル実行や破壊的操作を `rtk` で迂回しない。
