# Codex 設定

Claude Code 用の `commands/`、`hooks/`、`rules/`、`skills/` を Codex 向けに移植したディレクトリ。

## 対応表

| Claude Code | Codex 配置 | 扱い |
| --- | --- | --- |
| `claude/global_CLAUDE.md` | `codex/global_AGENTS.md` | `~/.codex/AGENTS.md` にリネームして配置 |
| `claude/rules/` | `codex/rules/` | 常時参照する設計・実装ルール |
| `claude/skills/` | `codex/skills/` | Codex skill 互換の `SKILL.md` として使用 |
| `claude/commands/` | `codex/prompts/commands/` | slash command 代替のプロンプト集 |
| `claude/hooks/` | `codex/hooks/` | `codex/hooks.json` から呼ばれる Codex hook 実体 |
| `claude/bin/` | `codex/bin/` | 補助スクリプト |
| `claude/settings.json` | `codex/settings.json` | hook 対応表として保管。Codex が自動読込する設定ではない |
| `claude/settings.json` の hooks | `codex/hooks.json` | `~/.codex/hooks.json` に配置される Codex hook 定義 |

## 使い方

### インストール

このリポジトリのルートで `install.sh` を実行する。

```bash
./install.sh -n
./install.sh
```

対話モードでは `Codex設定` を選ぶ。全設定をまとめて入れる場合は `./install.sh -f` を使う。

インストール後は主に次のリンクが作成される。

| 配置先 | リンク元 |
| --- | --- |
| `~/.codex/AGENTS.md` | `codex/global_AGENTS.md` |
| `~/.codex/hooks.json` | `codex/hooks.json` |
| `~/.codex/hooks/` | `codex/hooks/` |
| `~/.codex/skills/` | `codex/skills/` |
| `~/.codex/rules/` | `codex/rules/` |
| `~/.codex/prompts/commands/` | `codex/prompts/commands/` |

### 初回確認

Codex 起動時に hook のレビュー警告が出た場合は、Codex 上で `/hooks` を開いて内容を確認し、許可する。

`codex/hooks.json` は Codex 側のレビュー対象を減らすため、個別 hook を直接19件登録せず、5件の `hook-dispatcher.sh` 呼び出しに集約している。

### プロジェクトローカルで使う場合

Codex に常時読ませる場合は、対象プロジェクトのルートに `codex/global_AGENTS.md` を `AGENTS.md` として配置する。

```bash
cp codex/global_AGENTS.md AGENTS.md
```

このリポジトリ内だけで参照する場合は、作業時に `codex/global_AGENTS.md`、必要な `codex/rules/*.md`、`codex/skills/*/SKILL.md` を読む。

## commands の代替

Codex には Claude Code の slash command と同じプロジェクトローカル command 機構がないため、`codex/prompts/commands/*.md` はプロンプト断片として使う。

- `feat.md`: 新機能実装
- `fix.md`: バグ修正
- `commit.md`: コミットメッセージ案作成
- `code-review.md`: 差分レビュー

## hooks

Codex は `~/.codex/hooks.json` から hook を読み込む。`install.sh` は `codex/hooks.json` と `codex/hooks/` を `~/.codex/` にシンボリックリンク配置する。

- `PreToolUse` / `PostToolUse`: 主に Bash ツールの安全ガード
- `UserPromptSubmit`: 一次ソース確認・方針検証リマインド
- `SessionStart`: ルール・スキル・環境状態の表示

現行 Codex では hook の届く範囲に制約があるため、`apply_patch` 等の編集系ガードは `codex/global_AGENTS.md` の指示とテスト・レビューで補完する。

`codex/settings.json` は Claude Code 形式の hook 定義を Codex パスに置き換えた参照用ファイル。Codex 本体がこの JSON を自動で解釈する前提にはしない。

## progress

`codex/progress.md` は必要になった時だけ作成する。形式は `codex/global_AGENTS.md` の「セッション継続」を参照。
