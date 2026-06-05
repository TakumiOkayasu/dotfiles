# Codex Performance Profile

This profile applies the model-performance strategy to dotfile-work Codex settings.

## What changed

- Plugin-only operation remains: no `/prompt:*`, no `prompt:*`, no `codex-prompt`, no `codex-cmd`.
- Core plugin is kept small: `dotfile-work-codex` contains only high-frequency workflow skills and rules hooks.
- Optional skills are split into `dotfile-work-codex-extra`; enable only when needed.
- `RULES_CORE.md`, `RULES_INDEX.md`, and `RULES_BUNDLE.md` are generated from `codex/rules/*.md`.
- `rules-inject.sh` injects core/index for light prompts and full rules only for mutating/review/test/refactor prompts.
- `rules-guard.sh` blocks mutating tools until full rules are injected and checksums match.
- `command-safety.rules` adds official Codex command execution policy for high-risk shell commands.
- `agents/openai.yaml` is generated per skill: core skills may be implicitly invoked; optional skills require explicit invocation.
- `install.sh` is patched to avoid symlinking `codex/skills` into `~/.agents/skills`, preventing duplicate local/plugin skills.
- `plugins/dotfile-work-codex*` are generated from `codex/` sources and ignored by Git.

## Recommended runtime flow

1. Install/enable only `dotfile-work-codex` by default.
2. Keep `dotfile-work-codex-extra` disabled unless you need a specialized migrated Claude skill.
3. Use `$feat`, `$fix`, `$deep-review`, `$rules-required`, `$test`, `$refactor`.
4. Trust plugin hooks after review.
5. When changing rules or skills, run:

```sh
python3 scripts/apply-codex-performance-profile.py --repo .
python3 scripts/sync-codex-plugin.py --repo . --clean
python3 scripts/verify-codex-plugin.py --repo .
```

`scripts/sync-codex-plugin.py` writes local plugin bundles under `plugins/dotfile-work-codex*`.
Those directories are build outputs; do not commit them.

## Why this improves performance

Codex skills use progressive disclosure: the initial context includes each skill's name, description, and file path; full `SKILL.md` loads only when selected. Keeping the enabled core skill set small preserves the initial skill budget and reduces false routing.

Markdown rules are instruction rules, not Codex command policy. The full markdown rule bundle is injected only when required; official `.rules` files handle shell command decisions.
