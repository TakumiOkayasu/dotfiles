# Claude skills/rules to Codex port

## 目的

`claude/skills/*/SKILL.md` と `claude/rules/*.md` を Codex の運用方式へ移植する。
Codex 側では skills は `codex/skills/*/SKILL.md` を正本にし、plugin bundle 生成時に `plugins/dotfile-work-codex*` へ配置する。
rules は `codex/rules/*.md` を正本にし、`install.sh` では `~/.codex/rules/*.md` へリンクされる。

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
- `codex/skills/rules-required/SKILL.md`
  - rules 読了・遵守の運用 skill

## 適用

```sh
cd /path/to/dotfile-work
/path/to/claude-to-codex-skill-port/apply.sh
```

## 注意

- 既存 `codex/skills/*/SKILL.md` は上書きされる。初回上書き時は `.pre-claude-port.bak` を作る。
- 既存 `codex/rules/*.md` も上書きされる。初回上書き時は `.pre-claude-port.bak` を作る。
- Codex が rules を自動 import するとは仮定しない。hook で必要時に rules 契約を注入する。
- `CODEX_RULES_MAX_BYTES` を超える場合、full injection は止まり、`rules-guard.sh` が mutating tool を block する。
- `plugins/dotfile-work-codex*` は生成物。`python3 scripts/sync-codex-plugin.py --repo . --clean` で作成し、Git 管理しない。

## 推奨確認

```sh
git diff -- codex/skills codex/rules codex/hooks codex/bin scripts plugins .agents
python3 scripts/sync-codex-plugin.py --repo . --clean
python3 scripts/verify-codex-plugin.py --repo .
./install.sh -n
codex features list
```
