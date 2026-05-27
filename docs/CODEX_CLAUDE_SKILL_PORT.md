# Claude skills/rules to Codex port

## 目的

`claude/skills/*/SKILL.md` と `claude/rules/*.md` を Codex の運用方式へ移植する。
Codex 側では skills は `codex/skills/*/SKILL.md` から `~/.agents/skills/*/SKILL.md` へ配置され、rules は `codex/rules/*.md` から `~/.codex/rules/*.md` へ配置される。

## 実装内容

- `scripts/port-claude-assets-to-codex.py`
  - `claude/skills/*/SKILL.md` を全件 `codex/skills/*/SKILL.md` に変換
  - `claude/rules/*.md` を全件 `codex/rules/*.md` に変換
  - `~/.claude` / `CLAUDE.md` / `Claude Code` 参照を Codex 用語へ変換
  - `codex/rules/RULES_INDEX.md` と `codex/rules/RULES_BUNDLE.md` を生成
  - `codex/skills/CLAUDE_PORT_REPORT.md` を生成
- `codex/hooks/rules-inject.sh`
  - rules full content を context に注入
  - checksum marker を `codex_tmp/.codex_rules_loaded` に記録
- `codex/hooks/rules-guard.sh`
  - rules 未注入 / checksum 不一致時に mutating tools を block
- - `codex/skills/rules-required/SKILL.md`
  - rules 読了・遵守の運用 skill

## 適用

```sh
cd /path/to/dotfile-work
/path/to/claude-to-codex-skill-port/apply.sh
```

## 注意

- 既存 `codex/skills/*/SKILL.md` は上書きされる。初回上書き時は `.pre-claude-port.bak` を作る。
- 既存 `codex/rules/*.md` も上書きされる。初回上書き時は `.pre-claude-port.bak` を作る。
- Codex が rules を自動 import するとは仮定しない。hook で full content を context 注入する。
- `CODEX_RULES_MAX_BYTES` を超える場合、full injection は止まり、`rules-guard.sh` が mutating tool を block する。

## 推奨確認

```sh
git diff -- codex/skills codex/rules codex/hooks codex/bin scripts plugins .agents
./install.sh -n
codex features list
```
