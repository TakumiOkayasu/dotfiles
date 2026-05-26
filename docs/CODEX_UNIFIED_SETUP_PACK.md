# CODEX_UNIFIED_SETUP_PACK

この pack は以下を一括適用する。

1. prompt command router
2. custom prompt commands
3. prompt fragments/templates/evals
4. Claude skills/rules -> Codex migration
5. mandatory rules injection/guard
6. installer mapping patch

## 適用後の主な生成物

- `codex/prompts/commands/*.md`
- `codex/skills/*/SKILL.md`
- `codex/rules/*.md`
- `codex/rules/RULES_INDEX.md`
- `codex/rules/RULES_BUNDLE.md`
- `codex/skills/CLAUDE_PORT_REPORT.md`

## smoke test

```sh
echo '{"prompt":"prompt:list","cwd":"'"$(pwd)"'"}' | codex/hooks/prompt-command-expand.sh
echo '{"hook_event_name":"UserPromptSubmit","prompt":"test","cwd":"'"$(pwd)"'"}' | codex/hooks/rules-inject.sh
```
