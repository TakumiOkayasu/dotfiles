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

The private aggregate is a **sanitized export view**, not a backup of `.ai/`:

- `.ai/knowledge/` is exportable by default.
- `.ai/inbox/` is exported only when `[export].include_inbox = true`.
- `.ai/state/` and `.ai/manifest.toml` are never exported.
- project IDs, source file names, and source directory names are replaced by keyed HMAC references in the aggregate.

Runtime-specific adapters may inspect their own state and explicitly harvest reusable findings into `.ai/inbox/`. This keeps export independent from runtime-specific file formats and prevents raw logs or scratch data from becoming durable cross-project knowledge by accident.

Managed `.ai/` projects are included in sibling collection by default. Set `[export].enabled = false` when a project must be excluded from the external private knowledge repository. Keep `export.include_inbox = false` unless cross-project reuse of unverified candidates is intentionally required.

## Privacy and redaction

Treat the aggregate as a sanitized knowledge warehouse, not as a place where private data is acceptable merely because the GitHub repository is private.

- `secret`: credentials, tokens, private keys, cookies, authorization headers, environment secrets. Never export. Secret detection is fail-closed; do not commit a masked copy as a substitute.
- `confidential`: customer names, internal hosts, incident IDs, employee identifiers, private project labels. Preserve only the decision-relevant abstraction. Use `{{private:<kind>:<value>}}` when stable pseudonymous correlation is useful, or `{{redact:<value>}}` when it is not.
- `internal`: non-secret project-specific context. Export only if it is reusable and does not reveal confidential source material.
- `public`: generally reusable information that still belongs in project knowledge rather than an always-loaded rule.

The HMAC redaction key is local-only and must never be committed. Generate it with `ai-knowledge-keygen`; the exporter requires a regular key file with private permissions. Automatic semantic detection cannot reliably identify every customer/company name, so confidential identifiers must be marked or abstracted before they reach `knowledge/`.

Operational controls, key handling, legacy-repository migration, and incident recovery are defined in `docs/ai-knowledge-private.md`.
