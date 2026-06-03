# Codex 設定

Claude Code 用の `agents/`、`commands/`、`hooks/`、`rules/`、`skills/` を Codex 向けに移植したディレクトリ。

## 対応表

| Claude Code | Codex 配置 | 扱い |
| --- | --- | --- |
| `claude/global_CLAUDE.md` | `codex/global_AGENTS.md` | `~/.codex/AGENTS.md` にリネームして配置 |
| `claude/SUBAGENTS.md` | `codex/SUBAGENTS.md` | `~/.codex/SUBAGENTS.md` に配置する subagent mechanics |
| `claude/agents/*.md` | `codex/agents/*.toml` | `~/.codex/agents/*.toml` に配置する Codex custom agent 定義 |
| `claude/rules/` | `codex/rules/` | 参照用の設計・実装ルール |
| `claude/skills/` | `codex/skills/` | plugin 配布用 source。plugin-only mode では `install.sh` の配置対象外 |
| `claude/commands/` | `codex/prompts/commands/` | slash command 代替のプロンプト集 |
| `claude/hooks/` | `codex/hooks/` | `codex/hooks.json` から呼ばれる Codex hook 実体 |
| `claude/bin/` | `codex/bin/` | 補助スクリプト |
| `claude/settings.json` | `codex/reference/claude-settings.reference.json` | 参照用。install対象外 |
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
| `~/.codex/SUBAGENTS.md` | `codex/SUBAGENTS.md` |
| `~/.codex/agents/` | `codex/agents/` |
| `~/.codex/hooks.json` | `codex/hooks.json` |
| `~/.codex/hooks/` | `codex/hooks/` |
| `~/.codex/rules/` | `codex/rules/` |
| `~/.codex/prompts/commands/` | `codex/prompts/commands/` |

`codex/README.md` と `codex/reference/` はリポジトリ内の参照資料であり、`~/.codex/` には配置しない。

### 初回確認

Codex 起動時に hook のレビュー警告が出た場合は、Codex 上で `/hooks` を開いて内容を確認し、許可する。

`codex/hooks.json` は Codex 側のレビュー対象を減らすため、個別 hook を直接登録せず、イベントごとの `hook-dispatcher.sh` 呼び出しに集約している。

Codex の実仕様は CLI と現在の設定を一次ソースにする。確認コマンド:

```bash
codex --version
codex features list
codex doctor --all
readlink ~/.codex/AGENTS.md
codex debug prompt-input ping
```

確認観点:

- `~/.codex/AGENTS.md` が `codex/global_AGENTS.md` を指していること
- `hooks` / `multi_agent` の feature flag が有効なこと
- `codex debug prompt-input ping` の出力に AGENTS 指示が含まれること
- `codex/reference/claude-settings.reference.json` ではなく `~/.codex/config.toml` が Codex の実行時設定であること
- skill は plugin から利用可能で、`install.sh` が `~/.agents/skills/` に重複配置しないこと

### プロジェクトローカルで使う場合

Codex に常時読ませる場合は、対象プロジェクトのルートに `codex/global_AGENTS.md` を `AGENTS.md` として配置する。

```bash
cp codex/global_AGENTS.md AGENTS.md
```

このリポジトリ内だけで参照する場合は、作業時に `codex/global_AGENTS.md`、必要な `codex/rules/*.md`、`codex/skills/*/SKILL.md` を読む。

## skills / rules

- `codex/skills/` は plugin 配布用 source。plugin-only mode では `install.sh` で `~/.agents/skills/` に重複配置しない。
- `codex/rules/` は参照資料。Codex が自動的に常時ロードする前提にはしない。
- 常時必要な運用ルールは `codex/global_AGENTS.md` に直接集約する。
- vendor skill の更新は自動実行しない。必要な場合のみ `~/.codex/bin/vendor-skills-update-manual.sh` を手動実行する。

## subagents

`codex/SUBAGENTS.md` は Claude Code の `SUBAGENTS.md` に相当する mechanics 文書として配置する。

- `install.sh` で `~/.codex/SUBAGENTS.md` にリンクされる
- Codex の `child_agents_md` などの自動読込は有効と仮定しない
- subagent の起動可否は、現在の tool contract と feature flag を優先する
- 起動できない場合は、親セッション内で同じ観点分解を行う

Codex custom agent 定義は `codex/agents/*.toml` として管理し、`install.sh` で `~/.codex/agents/*.toml` にリンクされる。Codex の custom agent 仕様は standalone TOML を前提にしているため、Claude Code の `claude/agents/*.md` は本文を `developer_instructions` に移植する。

## commands の代替

Codex には Claude Code の slash command と同じプロジェクトローカル command 機構がないため、`codex/prompts/commands/*.md` はプロンプト断片として使う。

- `feat.md`: 新機能実装
- `fix.md`: バグ修正
- `commit.md`: コミットメッセージ案作成
- `deep-review.md`: 並列観点の差分レビュー。`code-review` は alias として扱う

インストール後は `~/.codex/prompts/commands/` から参照できる。

Claude Code の `/feat` や `/fix` に近い操作感で起動する場合は、`bin/` もインストールして `~/.local/bin` を PATH に入れる。

```bash
codex-feat "ユーザー検索機能を追加"
codex-fix "ログイン時に500になる問題を修正"
codex-code-review HEAD
codex-deep-review HEAD
codex-commit

# 汎用形式
codex-cmd feat "ユーザー検索機能を追加"
codex-cmd --exec code-review HEAD
codex-cmd --print fix "再現手順だけ確認したい"
```

既存の Codex セッションで使う場合は、該当ファイルの内容を入力欄に貼り付け、続けて依頼内容を書く。

```text
<~/.codex/prompts/commands/fix.md の内容>

対象: ログイン時に500になる問題を修正して
```

新しい Codex セッションをコマンドラインから開始する場合は、プロンプトファイルを初期入力として渡す。

```bash
codex "$(cat ~/.codex/prompts/commands/feat.md)"
codex "$(cat ~/.codex/prompts/commands/fix.md)"
codex "$(cat ~/.codex/prompts/commands/deep-review.md)"
```

非対話で実行する場合は `codex exec` に渡す。

```bash
codex exec "$(cat ~/.codex/prompts/commands/deep-review.md)"
```

Codex 本体が `/feat` や `/fix` をプロジェクトローカル command として自動展開するわけではない。対話起動は `codex-feat` / `codex-code-review` などの補助コマンド、既存セッションではプロンプト本文の貼り付けで代替する。

## hooks

Codex は `~/.codex/hooks.json` から hook を読み込む。`install.sh` は `codex/hooks.json` と `codex/hooks/` を `~/.codex/` にシンボリックリンク配置する。

- `PreToolUse` / `PostToolUse`: 主に Bash ツールの安全ガード
- `UserPromptSubmit`: 一次ソース確認・方針検証リマインド
- `SessionStart`: ルール・スキル・環境状態の表示

hook は補助的な安全機構であり、完全な enforcement 境界ではない。`apply_patch` など一部編集系は hook 側でも検知するが、最終的には `codex/global_AGENTS.md` の指示とテスト・レビューで補完する。

`codex/reference/claude-settings.reference.json` は Claude Code 形式の hook 定義を Codex パスに置き換えた参照用ファイル。Codex 本体がこの JSON を自動で解釈する前提にはしない。

## progress

`.codex/progress.md` は必要になった時だけ作成する。checkpoint は `.codex/checkpoints/latest.md` に置く。形式は `codex/global_AGENTS.md` の「進捗管理」を参照。
