# Claude Code 設定セットアップガイド

dotfile-work リポジトリの Claude Code 設定を `~/.claude` にシンボリックリンクとして配置する方法を説明します。

## 概要

`install.sh` が `claude/` ディレクトリ内のファイルを `~/.claude/` にシンボリックリンクとして配置します。

配置されるファイル:

| ソース | 配置先 | 説明 |
| -------- | -------- | ------ |
| `claude/global_CLAUDE.md` | `~/.claude/CLAUDE.md` | グローバル指示ファイル |
| `claude/settings.json` | `~/.claude/settings.json` | 権限・hooks設定 |
| `claude/rules/*.md` | `~/.claude/rules/*.md` | 常時適用の制約・規約 |
| `claude/skills/*/SKILL.md` | `~/.claude/skills/*/SKILL.md` | オンデマンドの作業手順 |
| `claude/hooks/*.sh` | `~/.claude/hooks/*.sh` | 自動リマインドhooks |
| `claude/commands/*.md` | `~/.claude/commands/*.md` | スラッシュコマンド |
| (自動clone) | `~/.claude/vendor/agent-skills/` | vercel-labs/agent-skills |
| (自動symlink) | `~/.claude/skills/{composition-patterns,react-best-practices,web-design-guidelines}` | vendor スキル |

シンボリックリンクにより、リポジトリの更新が `~/.claude` に即座に反映されます。
vendor スキルは `install.sh` 実行時に自動 clone され、SessionStart hook (`vendor-skills-update.sh`) で1日1回 `git pull` で更新されます。

---

## セットアップ方法

```bash
cd /path/to/dotfile-work
./install.sh        # 対話モード
./install.sh -f     # 全自動インストール
./install.sh -n     # ドライラン (プレビュー)
```

---

## セットアップ後の確認

```bash
ls -la ~/.claude
```

シンボリックリンクが `->` で表示されます:

```sh
lrwxrwxrwx 1 user user   42 Jan  6 12:00 CLAUDE.md -> /path/to/dotfile-work/claude/global_CLAUDE.md
lrwxrwxrwx 1 user user   48 Jan  6 12:00 settings.json -> /path/to/dotfile-work/claude/settings.json
lrwxrwxrwx 1 user user   43 Jan  6 12:00 rules/hallucination-prevention.md -> ...
```

---

## アンインストール

```bash
./install.sh -u     # シンボリックリンクを削除
```

元のファイル (`claude/` 内) は削除されません。

---

## 設定の変更

`claude/` ディレクトリ内のファイルを編集してください:

```bash
cd /path/to/dotfile-work/claude
vim global_CLAUDE.md
```

編集内容はシンボリックリンクを通じて `~/.claude` に即座に反映されます。
