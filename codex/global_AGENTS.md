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

- 作業開始時、`~/.codex/rules/*.md`、repo-local `codex/rules/*.md`、project-local `.codex/rules/*.md` のうち存在するものを読む。
- `rules-inject.sh` が full content を context に注入した場合、その注入内容を読了済み rules として扱う。
- 実装 / 修正 / リファクタ / テスト追加 / レビュー / 設計では、最低限 `coding-conventions.md`, `implementation-policy.md`, `hallucination-prevention.md`, `hierarchical-architecture.md` を適用する。
- rules 未読または checksum 不一致のまま mutating tool を使わない。`rules-guard.sh` が block した場合は、先に rules を再読する。
- plugin-only 運用では workflow 起動は `$feat`, `$fix`, `$deep-review`, `$rules-required` などの `$skill` を使う。独自 `/prompt:*` や `prompt:*` 互換導線は使わない。
- 競合時は project-local rule を優先し、競合内容を完了報告に明示する。

<!-- codex-rules-required: end -->
