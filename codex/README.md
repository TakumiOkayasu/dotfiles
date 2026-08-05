# Codex 設定

Codex-native設定と,Claude Code由来の `agents/`,`commands`,`hooks`,`rules`,`skills` の移植資産を管理するディレクトリ.

## 対応表

| Claude Code | Codex 配置 | 扱い |
| --- | --- | --- |
| - (Codex-native) | `codex/global_AGENTS.md` | 全project共通の個人default. `~/.codex/AGENTS.md` にリネームして配置 |
| `claude/SUBAGENTS.md` | `codex/SUBAGENTS.md` | `~/.codex/SUBAGENTS.md` に配置する subagent mechanics |
| `claude/agents/*.md` | `codex/agents/*.toml` | `~/.codex/agents/*.toml` に配置する Codex custom agent 定義 |
| `claude/rules/` | `codex/rules/` | 参照用の設計・実装ルール |
| `claude/skills/` | `codex/skills/` | plugin 配布用 source。plugin-only mode では `install.sh` の配置対象外 |
| `claude/commands/` | `codex/skills/*/references/claude-command.md` | Codex-native skill が必要時に読む詳細手順 |
| `claude/hooks/` | `codex/hooks/` | `config.toml.template` の inline hook から呼ばれる Codex hook 実体 |
| `claude/bin/` | `codex/bin/` | 補助スクリプト |
| `claude/settings.json` | `codex/reference/claude-settings.reference.json` | 参照用。install対象外 |
| `claude/settings.json` の hooks | `codex/config.toml.template` | `~/.codex/config.toml` 初回生成用 template。hook 定義は inline TOML |

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
| `~/.codex/config.toml` | `codex/config.toml.template` から初回生成 |
| `~/.codex/{balanced,fast,deep-review}.config.toml` | `codex/*.config.toml` |
| `~/.codex/agents/` | `codex/agents/` |
| `~/.codex/hooks/` | `codex/hooks/` |
| `~/.codex/rules/` | `codex/rules/` |
| `~/.codex/prompts/commands/` | `codex/prompts/commands/` |

`codex/README.md`、`codex/reference/`、`codex/config.toml.template` はリポジトリ内の参照資料であり、`~/.codex/` にはリンク配置しない。`~/.codex/config.toml` が存在しない場合のみ template から通常ファイルとして生成する。

`codex/*.config.toml` は選択可能なprofileであり、`~/.codex/*.config.toml` へsymlink配置する。

### モデルprofile

基準設定は `gpt-5.6-sol` と `xhigh` を使う。

用途に応じて次のprofileを選択できる。

| profile | model | reasoning | 用途 |
| --- | --- | --- | --- |
| `balanced` | `gpt-5.6-terra` | `high` | 品質と応答時間の均衡を取る通常作業 |
| `fast` | `gpt-5.6-luna` | `medium` | 軽量で応答時間を優先する作業 |
| `deep-review` | `gpt-5.6-sol` | `max` | 難しいレビューや品質優先の調査 |

profileは基準設定へモデルと推論強度だけを上書きする。

```bash
codex --profile balanced
codex --profile fast
codex --profile deep-review
```

### 補助スクリプト

`codex/bin/model-context.sh` は model 名から context window を推定し、`maxTokens` と `usableTokens` を JSON で返す。`install.sh` で `~/.codex/bin/model-context.sh` にリンクされる。

```bash
~/.codex/bin/model-context.sh "gpt-test (1.5m)"
~/.codex/bin/model-context.sh --context-window-size 128000 "unknown"
~/.codex/bin/model-context.sh --id model-id --display-name "Model [300k]"
```

### 初回確認

Codex 起動時に hook のレビュー警告が出た場合は、Codex 上で `/hooks` を開いて内容を確認し、許可する。

hook 定義は `codex/config.toml.template` の inline TOML に集約し、イベントごとの `hook-dispatcher.sh` 呼び出しにしている。Codex CLI が `~/.codex/config.toml` に生成する `[hooks.state.*]` や `trusted_hash` は環境固有 state のため template には含めない。

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
- `codex/config.toml.template` ではなく `~/.codex/config.toml` が Codex の実行時設定であること
- skill は plugin から利用可能で、`install.sh` が `~/.agents/skills/` に重複配置しないこと

### プロジェクトローカルで使う場合

Install済みなら`codex/global_AGENTS.md`はglobal defaultとして自動的に適用されるため,projectへcopyしない.
各projectのrootには,そのrepo固有のlayout,command,convention,constraint,done conditionだけを記述した`AGENTS.md`を置く.
Subdirectory固有の指示が必要な場合は,対象に近い階層へ追加する.

## skills / rules

- `codex/skills/` は plugin 配布用 source。plugin-only mode では `install.sh` で `~/.agents/skills/` に重複配置しない。
- `plugins/dotfile-work-codex*` は `codex/skills` / `codex/rules` / `codex/hooks` / `codex/bin` から生成するローカル bundle。Git 管理しない。
- Claude由来skillは `port-claude-assets-to-codex.py` でCodexのruntime contractへ変換してから配布する。
- `verify-codex-plugin.py` はsourceとpluginのskill集合、重複、ファイル内容を検証する。
- core pluginのrule hookはinline dispatcherを検出した場合に処理を譲り、plugin未導入時はinline hookをfallbackとして使う。
- `codex/rules/` は参照資料。Codex が自動的に常時ロードする前提にはしない。
- `codex/global_AGENTS.md` は全projectで長期的に安定する個人defaultだけを保持する. Project固有の規約はproject-local `AGENTS.md`,task固有のworkflowはskillへ置く.
- `scripts/apply-codex-performance-profile.py` を含む生成scriptは `codex/global_AGENTS.md` を変更しない. このfile自体を唯一の正本とする.
- vendor skill の更新は自動実行しない。必要な場合のみ `~/.codex/bin/vendor-skills-update-manual.sh` を手動実行する。

plugin bundle を更新する場合は次を実行する。

```bash
python3 scripts/generate-standard-workflow-skills.py --repo . --overwrite
python3 scripts/port-claude-assets-to-codex.py --repo . --overwrite --no-backup --prune
python3 scripts/apply-codex-performance-profile.py --repo .
python3 scripts/sync-codex-plugin.py --repo . --clean
python3 scripts/verify-codex-plugin.py --repo .
```

既存の `codex/skills/` を bundle に反映するだけなら、`generate-standard-workflow-skills.py` は省略してよい。

Claude側のskill/command/ruleを再移植する場合は次を実行する。

```bash
python3 scripts/generate-standard-workflow-skills.py --repo . --overwrite
python3 scripts/port-claude-assets-to-codex.py --repo . --overwrite --no-backup --prune
python3 scripts/apply-codex-performance-profile.py --repo .
python3 scripts/sync-codex-plugin.py --repo . --clean
python3 scripts/verify-codex-plugin.py --repo .
```

個人環境の `~/.codex/plugins/` と `~/.agents/plugins/marketplace.json` に配置する場合は次を実行する。

```bash
python3 scripts/install-codex-plugin-personal.py --repo .
```

配置後は Codex を再起動し、`/plugins` で `dotfile-work-codex` を有効化する。`dotfile-work-codex-extra` は必要な時だけ有効化する。

## subagents

`codex/SUBAGENTS.md` は Claude Code の `SUBAGENTS.md` に相当する mechanics 文書として配置する。

- `install.sh` で `~/.codex/SUBAGENTS.md` にリンクされる
- Codex の `child_agents_md` などの自動読込は有効と仮定しない
- subagent の起動可否は、現在の tool contract と feature flag を優先する
- 起動できない場合は、親セッション内で同じ観点分解を行う

Codex custom agent 定義は `codex/agents/*.toml` として管理し、`install.sh` で `~/.codex/agents/*.toml` にリンクされる。Codex の custom agent 仕様は standalone TOML を前提にしているため、Claude Code の `claude/agents/*.md` は本文を `developer_instructions` に移植する。

## commands の変換

Claude command は独立した Codex skill にせず、対応する Codex-native skill の `references/claude-command.md` へ変換する。
これにより、Codex の入口と共通契約を `SKILL.md` に保ち、Claude 側の詳細手順を必要時だけ読み込める。

| Claude command | Codex skill |
| --- | --- |
| `/commit` | `$commit-msg` |
| `/deep-review` | `$deep-review` |
| `/feat` | `$feat` |
| `/fix` | `$fix` |

対応関係の正本は `scripts/claude-command-map.json` とする。
command の追加/削除時は manifest を更新し、`$plugin-sync` の手順で変換/生成/plugin 同期/検証を続けて実行する。

## hooks

Codex hook は `~/.codex/config.toml` の inline TOML から読み込む。`install.sh` は `codex/config.toml.template` から `~/.codex/config.toml` を初回生成し、`codex/hooks/` を `~/.codex/hooks/` にシンボリックリンク配置する。既存の `~/.codex/config.toml` は上書きしない。

- `PreToolUse` / `PostToolUse`: 主に Bash ツールの安全ガード
- `UserPromptSubmit`: 一次ソース確認・方針検証リマインド
- `SessionStart`: ルール・スキル・環境状態の表示

hook は補助的な安全機構であり、完全な enforcement 境界ではない。`apply_patch` など一部編集系は hook 側でも検知するが、最終的には `codex/global_AGENTS.md` の指示とテスト・レビューで補完する。

`codex/reference/claude-settings.reference.json` は Claude Code 形式の hook 定義を Codex パスに置き換えた参照用ファイル。Codex 本体がこの JSON を自動で解釈する前提にはしない。

既存の `~/.codex/hooks.json` がある場合、`install.sh` は自動削除しない。inline hooks へ移行済みで不要なら手動で退避する。

## progress

`.codex/progress.md` はprojectまたは長時間taskで必要になった時だけ作成する. Checkpointは `.codex/checkpoints/latest.md` に置き,形式はproject-local instructionまたは利用するworkflowで定める.
