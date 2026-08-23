# Project AI Knowledge

`.ai/` is the project-local canonical store for durable knowledge that should be reusable across AI runtimes and sessions.

## Ownership

- `.ai/`: runtime-neutral durable state and reusable knowledge.
- `.claude/`: Claude Code-owned project state and configuration.
- `.codex/`: Codex-owned project state and configuration.
- `claude_tmp/` and `codex_tmp/`: disposable runtime workspaces. They are not canonical knowledge stores.

Do not copy raw runtime state into `.ai/` mechanically. Promote only information that can change a future task's decision or avoid repeated investigation.

## Structure

```text
.ai/
├── manifest.toml
├── state/
├── inbox/
└── knowledge/
```

- `state/`: runtime-neutral task continuity that intentionally survives sessions. Existing runtime-native progress files remain valid until explicitly migrated.
- `inbox/`: unverified observations and reusable-knowledge candidates.
- `knowledge/`: verified reusable knowledge with enough evidence to influence future work.

## Promotion

Use this lifecycle:

```text
runtime observation -> inbox candidate -> verification/reuse -> knowledge
```

A single successful attempt is not enough to turn a candidate into a global rule. Promote a finding into `common/rules/`, `AGENTS.md`, or another always-loaded instruction surface only when it is broadly applicable and repeatedly validated or otherwise supported by reproducible evidence.

## Cross-project collection

The project-local `.ai/` directory is the only source that the cross-project collector should export. Do not make the collector scrape `.claude/`, `.codex/`, `claude_tmp/`, or `codex_tmp/` directly.

Runtime-specific adapters may inspect their own state and explicitly harvest reusable findings into `.ai/inbox/`. This keeps backup/export independent from runtime-specific file formats and prevents raw logs or scratch data from becoming durable knowledge by accident.

Managed `.ai/` projects are included in sibling collection by default. Set `[export].enabled = false` only when a specific project must be excluded from the external private knowledge repository.

## Privacy

`.ai/` is private local state and is excluded by the global gitignore. The cross-project repository is also private, but export remains an external write: reusable knowledge must not contain credentials, tokens, private keys, environment files, raw secret-bearing logs, or customer-confidential source contents.

Preserve the decision-relevant abstraction and evidence reference instead of copying sensitive source material.
