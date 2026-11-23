# Codex 設定

Codex固有設定の正本を管理するディレクトリ。共有command/rule/skillの正本は `common/` に置き、install時にCodex形式へ生成する。

## 対応表

| Claude Code | Codex 配置 | 扱い |
| --- | --- | --- |
| - (Codex-native) | `codex/global_AGENTS.md` | 全project共通の個人default. `~/.codex/AGENTS.md` にリネームして配置 |
| `claude/SUBAGENTS.md` | `codex/SUBAGENTS.md` | `~/.codex/SUBAGENTS.md` に配置する subagent mechanics |
| `claude/agents/*.md` | `codex/agents/*.toml` | `~/.codex/agents/*.toml` に配置する Codex custom agent 定義 |
| `common/rules/` | `.generated/ai-assets/codex/rules/` | 共有正本から生成する設計と実装のルール |
| `common/skills/` | `.generated/ai-assets/codex/skills/` | 共有正本から生成するplugin配布用view |
| `common/commands/` | `.generated/ai-assets/codex/skills/*/references/claude-command.md` | Codex-native skillが必要時に読む詳細手順 |
| `claude/hooks/` | `codex/hooks/` | `config.toml.template` の inline hook から呼ばれる Codex hook 実体 |
| `claude/bin/` | `codex/bin/` | 補助スクリプト |
| `claude/settings.json` の hooks | `codex/config.toml.template` | `~/.codex/config.toml` 初回生成用 template。hook 定義は inline TOML |

## 使い方

### インストール

このリポジトリのルートで `install.sh` を実行する。

```bash
./install.sh -n
./install.sh
```

- 対話モードでは `Codex設定` を選ぶ。
- 全設定をまとめて入れる場合は `./install.sh -f` を使う。

インストール後は主に次のリンクが作成される。

| 配置先 | リンク元 |
| --- | --- |
| `~/.codex/AGENTS.md` | `.generated/ai-assets/codex/global_AGENTS.md` |
| `~/.codex/SUBAGENTS.md` | `.generated/ai-assets/codex/SUBAGENTS.md` |
| `~/.codex/config.toml` | `codex/config.toml.template` から初回生成 |
| `~/.codex/{balanced,fast,deep-review}.config.toml` | `.generated/ai-assets/codex/*.config.toml` |
| `~/.codex/agents/` | `.generated/ai-assets/codex/agents/` |
| `~/.codex/hooks/` | `.generated/ai-assets/codex/hooks/` |
| `~/.codex/rules/` | `.generated/ai-assets/codex/rules/` |
| `~/.codex/plugins/` | `.generated/ai-assets/plugins/` |
| `~/.agents/plugins/marketplace.json` | `.generated/ai-assets/.agents/plugins/marketplace.json` |

`codex/README.md` と `codex/config.toml.template` は `~/.codex/` へリンク配置しない。`~/.codex/config.toml` が存在しない場合のみ template から通常ファイルとして生成する。

`codex/*.config.toml` は選択可能なprofileであり、`~/.codex/*.config.toml` へsymlink配置する。

### モデルprofile

モデルIDの正本は [config.toml.template](config.toml.template)、用途別の `*.config.toml`、`agents/*.toml`、[QCDルーティング設定](../common/qcd/routes.json) に置く。
基準設定の推論強度は `xhigh` とし、用途別profileでモデルと推論強度を上書きする。

| profile | 設定ファイル | reasoning | 用途 |
| --- | --- | --- | --- |
| `balanced` | [balanced.config.toml](balanced.config.toml) | `high` | 品質と応答時間の均衡を取る通常作業 |
| `fast` | [fast.config.toml](fast.config.toml) | `medium` | 軽量で応答時間を優先する作業 |
| `deep-review` | [deep-review.config.toml](deep-review.config.toml) | `max` | 難しいレビューや品質優先の調査 |

```bash
codex --profile balanced
codex --profile fast
codex --profile deep-review
```

### Subagentのmodel/effort

全subagentの既定値は `config.toml.template` の `agents` tableで管理し、role定義で上書きする。

| role | モデル系列 | effort | 理由 |
| --- | --- | --- | --- |
| `code_reviewer` | Terra | `high` | 大量の読取とedge case検査を両立 |
| `debugger` | Sol | `high` | 仮説生成と根本原因追跡を優先 |
| `design_consultant` | Terra | `high` | 複数案の比較と反証を優先 |
| `impl_planner` | Terra | `medium` | 読取中心の定型的な計画作成 |
| `qa_nightmare` | Sol | `high` | 複雑な境界分析用。現状はdispatch禁止 |
| `test_writer` | Terra | `medium` | scope済みのテスト生成を低latencyで処理 |
| `test_analyst` | Terra | `high` | 独立したテスト設計と候補審査 |

`max_concurrent_threads_per_session` はworker数の要求ではなく、open thread数の上限である。
端末、WSL、CI、ChatGPT Workなど実行環境ごとのcapacityに追従させるため未設定とし、Codexのdefaultへ委ねる。

### モデル更新の定期確認

[Codex model updates](../.github/workflows/codex-model-updates.yml) は毎週月曜11:23 JSTに実行し、Actions画面から手動でも起動できる。
Dependabotの対応ecosystemにはモデルIDがないため、Python標準ライブラリとGitHub Actionsで更新を提案する。

公式Codexの最新安定版releaseに含まれるカタログを読み、同じ系列で最も新しいモデルIDを選ぶ。
表示対象、契約プラン、最低CLIバージョン、設定済みの推論強度を確認する。
推論強度が非対応なら失敗として停止し、設定は書き換えない。
プランの既定値は `prolite` で、repository variable `CODEX_CHATGPT_PLAN` で変更できる。
端末が古い場合は、先にCLIを更新する必要がある。

```bash
# 差分の候補を表示する。端末のCLIバージョンで候補を絞る場合は --cli-version を指定する。
python3 scripts/update-codex-models.py --plan prolite
# 変更内容を確認してからリポジトリの正本へ適用する。
python3 scripts/update-codex-models.py --plan prolite --write
```

変更があれば、資産生成とinstallerの回帰テストを通してから専用ブランチにドラフトPRを作成する。
更新PRが開いている間は次のPRを作らず、既存PRへ追加の変更もしない。
自動マージは行わない。
GitHubのSettings > Actions > GeneralでworkflowによるPR作成を許可しておく必要がある。

`GITHUB_TOKEN` で作成したPRのCIは承認待ちになるため、PR画面で `Approve workflows to run` を選択する。
公開カタログはrelease時点の情報であり、契約アカウントやworkspaceでの利用可否は `/model` でも確認する。
更新処理は推論APIを呼ばず、ChatGPTの認証情報も使用しない。
既存の `~/.codex/config.toml` は初回生成後に上書きされないため、変更したモデルIDは別途反映する。
profileとagentのリンク先は、通常の `install.sh` による生成と配置で反映する。

一次ソース:

- [Codexのカタログ](https://github.com/openai/codex/blob/main/codex-rs/models-manager/models.json)
- [モデルカタログの仕様](https://learn.chatgpt.com/docs/enterprise/roll-out-a-gateway)
- [ChatGPT WorkとCodexのモデル利用条件](https://help.openai.com/en/articles/20001275-chatgpt-work-and-codex)
- [Dependabotの対応ecosystem](https://docs.github.com/en/code-security/reference/supply-chain-security/supported-ecosystems-and-repositories)
- [GITHUB_TOKENが作成するイベントの制限](https://docs.github.com/en/actions/how-tos/writing-workflows/choosing-when-your-workflow-runs/triggering-a-workflow)

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

- `~/.codex/AGENTS.md` が `.generated/ai-assets/codex/global_AGENTS.md` を指していること
- `hooks` / `multi_agent` の feature flag が有効なこと
- `codex debug prompt-input ping` の出力に AGENTS 指示が含まれること
- `codex/config.toml.template` ではなく `~/.codex/config.toml` が Codex の実行時設定であること
- skill は plugin から利用可能で、`install.sh` が `~/.agents/skills/` に重複配置しないこと

### 使用量ステータスライン

`bin/statusline-provider.py` は [Codex CLI 0.171.0 の公式サンプル](https://github.com/openai/codex/blob/ccf9be8cc458bd6b8336fe84d68d8893f2691a5e/codex-rs/skills/src/assets/samples/create-statusline/assets/statusline.py)を基にした MCP provider。Python 3.10 以上が必要で、標準ライブラリだけを使う。

`ctx 42% | 5h 18% | week 27%` の順で使用率を表示し、欠損は `–`、0は `0%` とする。80%以上は黄と `!`、95%以上は赤と `!!`。この閾値は本 provider の表示方針。

ctx は受信した使用率を使う。5h と week は `codex` の使用枠から `window_minutes` が300と10080の枠を選ぶ。表示時は小数部分を切り捨て、100%を超える値もそのまま表示する。

ctx と使用枠を別々に取得し、表示文字列と警告段階を3枠分持つ `StatuslineDisplay` に変換する。描画関数はこの契約を受け取り、MCP の UI tree を組み立てる。

読み取る使用率とオブジェクトの型が不正なら、MCP の入力エラーを返す。描画中に想定外の例外が発生した場合は伝播させ、入力エラーへ変換しない。

テストはリポジトリのルートから実行する。取得・変換・描画を個別に確認し、MCP の契約テストでは fake が同じプロセスへ逐次要求して stdin を開いたまま応答を確認する。各ケースの目的・期待結果・観測対象はテストのコメントを参照。

```sh
python3 -m unittest discover -s tests -p test_codex_statusline_provider.py -v
```

登録する場合は app-server の動くホストで次を実行し、`/experimental` の `Custom status line` を有効にして TUI を再起動する。新しい会話の `/statusline` で `Dotfiles usage statusline` を選ぶ。

```sh
codex mcp add dotfiles-statusline -- python3 -u /absolute/path/to/dotfiles/codex/bin/statusline-provider.py
```

実 Codex CLI、macOS、WSL、ネイティブ Windows では未検証。TUI の1秒の読み取り期限、狭い端末の表示、エラーからの復帰は fake の検証範囲に含まない。

### プロジェクトローカルで使う場合

Install済みなら`codex/global_AGENTS.md`はglobal defaultとして自動的に適用されるため,projectへcopyしない.
各projectのrootには,そのrepo固有のlayout,command,convention,constraint,done conditionだけを記述した`AGENTS.md`を置く.
Subdirectory固有の指示が必要な場合は,対象に近い階層へ追加する.

## skills / rules

- `common/skills/` は共有skillの正本。`codex/skills/` はCodex固有skillの正本だけを保持する。
- `.generated/ai-assets/codex/skills/` はinstall時の生成viewであり、直接編集もGit管理もしない。
- `.generated/ai-assets/plugins/dotfile-work-codex*` は生成viewのskill/ruleとCodex固有hook/binから作るローカルbundle。
- 共有skillは `port-claude-assets-to-codex.py` でCodexのruntime contractへ変換してから配布する。
- `common/skills/*/SKILL.md` の `effort` はClaude Code用metadataとして保持する。Codex生成viewではClaude固有frontmatterを除去し、session/profileまたはcustom agentの `model_reasoning_effort` を使う。
- `disable-model-invocation` はCodex生成viewのfrontmatterへ残さず、`agents/openai.yaml` の `allow_implicit_invocation` へ意味を変換する。
- `generate-ai-assets.py` はtracked sourceだけを一時treeへ移し、全変換と `verify-codex-plugin.py` を完走した結果だけを公開する。
- core pluginのrule hookはinline dispatcherを検出した場合に処理を譲り、plugin未導入時はinline hookをfallbackとして使う。
- `.generated/ai-assets/codex/rules/` は参照資料。Codex が自動的に常時ロードする前提にはしない。
- `codex/global_AGENTS.md` は全projectで長期的に安定する個人defaultだけを保持する. Project固有の規約はproject-local `AGENTS.md`,task固有のworkflowはskillへ置く.
- `scripts/apply-codex-performance-profile.py` を含む生成scriptは `codex/global_AGENTS.md` を変更しない. このfile自体を唯一の正本とする.
- vendor skill の更新は自動実行しない。必要な場合のみ `~/.codex/bin/vendor-skills-update-manual.sh` を手動実行する。

生成viewとplugin bundleを確認する場合は次を実行する:

```bash
python3 scripts/generate-ai-assets.py --repo .
```

通常は `install.sh` が生成から配置まで行う。`/plugins` で `dotfile-work-codex` を有効化し、`dotfile-work-codex-extra` は必要な時だけ有効化する。

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

対応関係の正本は `scripts/ai-assets-manifest.json` とする。
command の追加/削除時は manifest を更新し、`$plugin-sync` の手順で変換/生成/plugin 同期/検証を続けて実行する。

## hooks

Codex hook は `~/.codex/config.toml` の inline TOML から読み込む。`install.sh` は `codex/config.toml.template` から `~/.codex/config.toml` を初回生成し、`codex/hooks/` を `~/.codex/hooks/` にシンボリックリンク配置する。既存の `~/.codex/config.toml` は上書きしない。

- `PreToolUse` / `PostToolUse`: 主に Bash ツールの安全ガード
- `UserPromptSubmit`: 一次ソース確認・方針検証リマインド
- `SessionStart`: ルール・スキル・環境状態の表示

hook は補助的な安全機構であり、完全な enforcement 境界ではない。`apply_patch` など一部編集系は hook 側でも検知するが、最終的には `codex/global_AGENTS.md` の指示とテスト・レビューで補完する。

既存の `~/.codex/hooks.json` がある場合、`install.sh` は自動削除しない。inline hooks へ移行済みで不要なら手動で退避する。

## progress

`.codex/progress.md` はprojectまたは長時間taskで必要になった時だけ作成する. Checkpointは `.codex/checkpoints/latest.md` に置き,形式はproject-local instructionまたは利用するworkflowで定める.
