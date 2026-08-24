# Private AI Knowledge Repository Policy

The aggregate repository is a **sanitized, derived knowledge store**. It is not a backup destination for raw `.ai/`, runtime logs, source code, credentials, or customer data.

## Export boundary

`ai-knowledge-sync` reads only managed project `.ai/` directories, then builds a temporary sanitized tree before touching the destination repository.

| Local source | Default aggregate behavior |
| --- | --- |
| `.ai/knowledge/` | export after validation/redaction |
| `.ai/inbox/` | excluded; opt in with `export.include_inbox = true` |
| `.ai/state/` | never export |
| `.ai/manifest.toml` | never export |
| `.claude/`, `.codex/`, `*_tmp/` | never read by collector |

Only UTF-8 text files with the supported knowledge suffixes are exportable. Symlinks, binary files, sensitive-looking paths, unsupported file types, and oversized files fail the entire sync before destination mutation.

Project IDs and source paths are not written to the aggregate. A local HMAC key derives opaque project references and opaque file names. Absolute local paths are normalized to `$PROJECT` / `$HOME` when found in exported text.

## Data classification

Use the following decision before writing reusable knowledge:

| Class | Examples | Export rule |
| --- | --- | --- |
| `public` | generic technical finding | allowed |
| `internal` | non-sensitive project context | allowed only when reusable |
| `confidential` | customer/company names, internal hosts, incident IDs, private labels | abstract or pseudonymize before export |
| `secret` | password, API token, private key, cookie, bearer token | prohibited; sync must fail |

A private GitHub repository does not lower the classification of its contents.

## Redaction syntax

For a confidential value whose identity must remain correlatable across findings, use an explicit private marker in the local knowledge file:

```text
{{private:customer:Example Corporation}}
{{private:host:prod-db-01.internal}}
```

The aggregate stores deterministic HMAC-derived placeholders such as:

```text
<customer:5b8f2e3d96c1>
<host:84e1177d3850>
```

The original values are not written to the aggregate. The same `kind + value` under the same local HMAC key produces the same pseudonym.

For one-off data that should not remain correlatable, use:

```text
{{redact:INC-12345}}
```

which becomes:

```text
<redacted>
```

Do not use masking such as `secret=****` as a way to permit secret-bearing records. Remove the record or extract a reusable abstraction instead.

The exporter also rejects recognized credential formats, credential assignments, authorization/cookie headers, private-key blocks, and suspicious high-entropy tokens. This is a guardrail, not semantic DLP: customer names and business-confidential prose cannot be identified reliably without explicit abstraction/redaction.

## HMAC key

Create the key once on each machine that must produce or search the same aggregate:

```bash
ai-knowledge-keygen
```

Default path:

```text
~/.config/dotfiles/ai-knowledge-redaction.key
```

Requirements:

- keep the file outside every Git repository;
- permission `0600` or stricter on POSIX;
- do not pass the key value through shell arguments or environment variables;
- back it up only through an encrypted secret/credential backup mechanism;
- use the same key on machines that must derive the same project/file references.

`AI_KNOWLEDGE_REDACTION_KEY_FILE` changes the key path without exposing the key value.

Rotating the key changes every pseudonymous project/file reference. If rotation is caused by suspected key disclosure, rebuild the aggregate history rather than committing a normal rename-only migration.

## Private repository controls

The destination repository should be dedicated to this dataset and have no unrelated worktree changes.

Required operating rules:

- repository visibility is **private**;
- grant access only to accounts that require the knowledge corpus;
- use a dedicated Git credential with the minimum repository-content permissions needed for sync;
- keep Pages, public forks, and unnecessary integrations disabled;
- disable Actions/third-party apps unless the aggregate has a specific audited need for them;
- enable GitHub secret scanning/protection features when available;
- keep the local clone on encrypted storage;
- do not manually copy raw `.ai/`, source files, logs, or incident dumps into the repository;
- treat generated `projects/` and `index.json` as collector-owned output rather than hand-edited content.

Before enabling scheduled push, verify the remote repository's visibility and credential scope manually. The local collector intentionally does not depend on network/API access to prove GitHub visibility on every run.

## Legacy schema 1 migration

The old collector copied broad `.ai/` content and stored readable project IDs. A normal follow-up commit cannot remove that data from Git history.

If `index.json` uses `schema_version = 1`, the hardened exporter and search command fail closed. Use one of these approaches before re-enabling scheduled sync:

1. **Preferred when the aggregate is disposable:** create a fresh private repository, create/restore the HMAC key, and run the hardened exporter into the empty repository.
2. **When history must be retained:** audit the old repository, remove sensitive paths/identifiers with a history-rewrite tool such as `git filter-repo`, force-push the rewritten history, invalidate old clones, then rebuild the schema-2 aggregate.

Do not simply change `schema_version` by hand.

## Incident response

If secret or confidential raw data reaches the aggregate:

1. stop scheduled sync and set the affected project's `export.enabled = false`;
2. if a credential is involved, revoke/rotate it first;
3. identify every affected file/commit and whether clones/remotes may contain it;
4. purge affected data from Git history or recreate the aggregate repository;
5. force-push only after the rewrite is verified;
6. delete/re-clone every stale local copy that still contains the old objects;
7. add a regression case or detection rule that prevents the same leak class;
8. re-enable export only after the sanitized dry-run is reviewed.

Deletion in a later commit is not sufficient for a secret that already entered Git history.
