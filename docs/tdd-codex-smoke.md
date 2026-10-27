# Codex TDD review adapter の実CLIスモーク

`tests/smoke_tdd_codex.py` は、`bin/tdd-review-check` を実Codex CLIへ接続する明示実行専用の試験。通常のpytestやCIからモデルや配布物ダウンロードを呼び出さない。既存の模擬プロトコルテストで扱うschema不正や参照不整合の組み合わせは繰り返さない。

通常runnerと同じ公式latest安定版を一時取得し、公式SHA-256を照合する。実行中は同じバイナリを使い、既存CLIを上書きしない。版番号だけでは拒否しない。取得・照合失敗時に古い版や別providerへ代替しない。認証を指定した実行では実モデルの利用枠を消費する。

## 実行

リポジトリのルートで実行する。Python 3.14以降の標準ライブラリだけを使う。各runで配布物を1回取得するため、GitHubへの接続と一時領域が必要。Linux/WSLとmacOSのx86_64/aarch64が対象。

Python 3.14未満では、入力の読込・出力作成・ダウンロード前に停止し、アップグレード方法を表示する。既存環境が古い場合は `uv python install 3.14` を実行し、下記を `uv run --python 3.14 python` で起動する。`python3.14` を直接指定してもよい。検証用Dockerも `python:3.14-slim` を使用する。

```sh
# latest取得・照合と、モデル呼び出し前の実境界確認。
uv run --python 3.14 python tests/smoke_tdd_codex.py \
  --output /tmp/tdd-codex-boundary-check

# 認証を指定して全試験を実行する。outputは毎回新しいディレクトリを指定する。
uv run --python 3.14 python tests/smoke_tdd_codex.py \
  --auth-file /path/to/auth.json \
  --output /tmp/tdd-codex-smoke
```

モデルを選ぶ場合だけ `--model MODEL` を加える。モデル名を試験の期待値には使わない。

子プロセス専用の一時HOME/CODEX_HOMEと最小configを作り、ユーザーのconfig、rules、hooks、履歴、実プロジェクトをコピーしない。認証は明示した `auth.json` だけをmode `0600` でコピーし、元ファイルへは書き込まない。認証情報をモデル入力やreportへ含めず、一時領域は終了時に削除する。OSやmanaged設定を含む全てのambient contextの隔離を保証する試験ではない。

入力は `tests/fixtures/tdd_codex_smoke/` のbool値をそのまま返す合成契約と実装だけ。I/O試験の対象も一時ファイル、起動marker、loopback listenerだけで、実プロジェクトや秘密値を対象にしない。

## 確認する3つの経路

| 経路 | 成功に必要な実行証拠 |
| --- | --- |
| 正常pipeline | 3観点のderive/expectations/reviewとintegrateの計10 phase。異なる実PIDとephemeral thread、実送信payloadとverify対象入力の一致、全turnのcompleted、`ready`と`verify`の一致、全子プロセスの回収 |
| 外部I/O | 実モデルへ合成canaryのread/process/loopback通信とwriteを要求。対象toolのruntime出力で環境解決拒否を観測し、ファイル・起動marker・listenerに副作用がないことも確認 |
| 異常時のfail-closed | 最初の `turn/start` を送信した直後に実app-serverを停止。`error.json=blocked`、`ready.json`なし、後続phaseなし、子プロセス回収を確認 |

正常pipelineでは、試験configに `enabled=true` の合成MCP serverを置く。adapterによる無効化後の実MCP応答で `disabled` と空のtools/resources/resourceTemplatesを確認し、起動markerが作られないことも確認する。

正常終了は「model turn完了、runner/verify成功、子プロセス回収」を指す。app-serverは常駐サービスなので、adapterの `close()` による停止を終了コード0の自然終了とは扱わない。

I/O診断だけは、試験用observerが `functionCallOutput` を収集し、handlerの拒否まで観測する。対象toolのoutputが既知の環境解決エラー全文と完全一致した場合だけ拒否確認とする。成功stdoutにエラー文が含まれるだけでは成功にしない。製品adapterのtool検出guardや起動flagsは変更しない。モデルの拒否文やcanary不変だけでは成功にしない。toolが使われず該当runtime出力がない場合は `skipped` (未検証) とする。

特に `features.shell_tool=false` では `exec_command` が登録されず、read/process/networkを能動的に試せない場合がある。試験のためにshellや実行環境を有効化しない。`command/exec`、`fs/readFile`、`fs/writeFile` はthread外のhost APIなので、workerの `environments: []` の拒否証拠には使わない。

## 結果の読み方

`--output` 配下の `report.json` に `passed` / `failed` / `skipped` を記録する。正常pipelineと異常系の保存入力・出力も同じ配下に残す。共有する場合は内容を確認し、通常の実プロジェクトのrunner出力と混ぜない。

| 終了コード | 意味 |
| --- | --- |
| `0` | 全項目がpassed |
| `77` | failedはないが、未検証項目がある |
| `1` | 失敗項目がある |

2026-10-27の実行記録は [validation/tdd-codex-smoke-20261027.json](validation/tdd-codex-smoke-20261027.json)。公式latestは実行時点で `0.164.0`。配布物の照合、モデル要求前のephemeral/environmentなし/read-only/network無効/承認never、合成MCPのdisabled・空capabilities・未起動、子プロセス回収を実CLIで確認した。認証ファイルを渡さず、モデル呼び出しは行っていない。10 phaseの正常pipeline、能動的I/O拒否、実プロセス停止による異常系は未検証。

この結果は実CLI互換性、全体の隔離、AIの審査精度を認定しない。実モデル呼び出しと認証情報の一時コピーを追加するため、差分のレビューでは `HUMAN_REVIEW_REQUIRED` を維持し、ドラフトPRから自動マージしない。

## 一次ソース

- [adapterの契約と信頼境界](../common/skills/tdd/references/test-design-review.md)
- [0.164.0の環境解決と拒否](https://github.com/openai/codex/blob/rust-v0.164.0/codex-rs/core/src/tools/handlers/mod.rs)
- [exec_commandの環境解決](https://github.com/openai/codex/blob/rust-v0.164.0/codex-rs/core/src/tools/handlers/unified_exec/exec_command.rs) / [apply_patchの環境解決](https://github.com/openai/codex/blob/rust-v0.164.0/codex-rs/core/src/tools/handlers/apply_patch.rs)
- [ThreadItemとfunctionCallOutput](https://github.com/openai/codex/blob/rust-v0.164.0/codex-rs/app-server-protocol/src/protocol/v2/item.rs)
- [handlerエラーの文字列出力](https://github.com/openai/codex/blob/rust-v0.164.0/codex-rs/core/src/tools/parallel.rs#L338)
- [shell toolの登録条件](https://github.com/openai/codex/blob/rust-v0.164.0/codex-rs/core/src/tools/spec_plan.rs)
- [host command API](https://github.com/openai/codex/blob/rust-v0.164.0/codex-rs/app-server-protocol/src/protocol/v2/command_exec.rs) / [host filesystem API](https://github.com/openai/codex/blob/rust-v0.164.0/codex-rs/app-server-protocol/src/protocol/v2/fs.rs)
- [auth.jsonの保存契約](https://github.com/openai/codex/blob/rust-v0.164.0/codex-rs/login/src/auth/storage.rs)

通常runnerの取得・SHA照合と実行中の固定契約は[共有reference](../common/skills/tdd/references/test-design-review.md)を参照。ハッシュは配布物の同一性を確認するもので、最新版の隔離安全性を認定しない。
