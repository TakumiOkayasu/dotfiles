# Codex Performance Profile

This profile applies the model-performance strategy to dotfile-work Codex settings.

## What changed

- Plugin-only operation remains: no /prompt:*, no prompt:*, no codex-prompt, no codex-cmd.
- Core plugin is kept small: dotfile-work-codex contains only high-frequency workflow skills and rules hooks.
- Optional skills are split into dotfile-work-codex-extra; enable only when needed.
- codex/global_AGENTS.md is the canonical, concise set of cross-project personal defaults. Profile generators do not rewrite it.
- RULES_CORE.md, RULES_INDEX.md, and RULES_BUNDLE.md are generated from codex/rules/*.md.
- rules-inject.sh emits a compact contract and records the active rules checksum; the relevant workflow must explicitly read only the task-applicable detailed rules.
- rules-guard.sh blocks mutating tools unless enforcement mode is active and the checksum matches.
- command-safety.rules adds official Codex command execution policy for high-risk shell commands.
- agents/openai.yaml is generated per skill: core skills may be implicitly invoked; optional skills require explicit invocation.
- install.sh is patched to avoid symlinking codex/skills into ~/.agents/skills, preventing duplicate local/plugin skills.
- plugins/dotfile-work-codex* are generated from codex/ sources and ignored by Git.

## Recommended runtime flow

1. Install/enable only dotfile-work-codex by default.
2. Keep dotfile-work-codex-extra disabled unless you need a specialized migrated Claude skill.
3. Use $feat, $fix, $deep-review, $rules-required, $test, $refactor.
4. Trust plugin hooks after review.
5. When changing rules or skills, run:

```sh
python3 scripts/apply-codex-performance-profile.py --repo .
python3 scripts/sync-codex-plugin.py --repo . --clean
python3 scripts/verify-codex-plugin.py --repo .
```

scripts/sync-codex-plugin.py writes local plugin bundles under plugins/dotfile-work-codex*.
Those directories are build outputs; do not commit them.

## Human-facing views

Treat [temporary HTML as a view](https://x.com/t_wada/status/2082346806391058540), not as a universal output format:

- For explanations with several relationships, comparisons, or state transitions, use the smallest visual format that materially improves understanding and that the current client can render.
- HTML is one optional view. Prefer a Markdown table, compact diagram, or plain prose when it communicates the same information clearly.
- Keep Markdown or the project’s reviewable native source as the durable source of truth. Do not commit a generated HTML view unless the user explicitly requests it as a deliverable.
- Keep this policy in the relevant report or explanation workflow rather than the always-loaded global instructions. Promote a more specific rule only after representative tasks show a repeatable benefit.

## Prompt-cache implications

[OpenAI Prompt Caching](https://developers.openai.com/api/docs/guides/prompt-caching) reuses exact prompt prefixes, not semantically similar text. Apply that as a performance constraint without weakening correctness:

- Keep shared instruction surfaces deterministic and stable. Where ordering is controllable, put stable instructions before variable task data.
- Do not add timestamps, random ordering, temporary absolute paths, or per-run status to generated instruction and rule content.
- Changing the model, plugin/tool surface, or early instructions can produce a cold cache. Make those changes when the task requires them, not merely to chase a cache hit.
- Treat caching as an optimization, not durable memory. Before an intentional compaction or session reset on a long task, preserve material decisions, evidence, failed attempts, and the next step in a project-approved Markdown checkpoint.
- Do not delete useful context solely to reduce the visible token count. Compare latency, usage telemetry, and task quality on representative work.
- API controls such as prompt_cache_breakpoint are not assumed to be exposed by Codex clients. The runtime’s actual behavior and current official documentation take precedence.
- Cache retention and breakpoint behavior are model- and runtime-specific. Do not encode a fixed expiry window in AGENTS.md, hooks, or generated rules; verify current official OpenAI documentation and runtime telemetry.

## Why this improves performance

Codex skills use progressive disclosure: the initial context includes each skill’s name, description, and file path; full SKILL.md loads only when selected. Keeping both global_AGENTS.md and the enabled core skill set small preserves the initial context budget and reduces instruction conflicts and false routing.

Markdown rules are instruction rules, not Codex command policy. Keep detailed markdown rules on demand; official .rules files handle shell command decisions.