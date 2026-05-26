# rules

Codex rules を読み込み、今回の作業に適用する。

## Input

`$ARGUMENTS`: optional。特定 task / file / rule 名。

## Steps

1. `rules-required` skill を使う。
2. 以下の順で rules を読む:
   - project-local `.codex/rules/*.md`
   - repo-local `codex/rules/*.md`
   - global `~/.codex/rules/*.md`
3. `$ARGUMENTS` があれば、該当 task に関係する rule を優先して要約する。
4. 実装・修正・レビュー作業なら最低限以下を適用する:
   - `coding-conventions.md`
   - `implementation-policy.md`
   - `hallucination-prevention.md`
   - `hierarchical-architecture.md`

## Output

```text
## Rules loaded
- 読んだ rule files:
- 今回必須の rule:
- 競合:
- 作業時の禁止事項:
```
