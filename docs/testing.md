# テストの実行と選び方

## 開発用 Python 環境

pytest とその依存は `tests/requirements.in` を入力、`tests/requirements.txt` を lock とする。Docker とローカルで同じ lock を使う。既存のグローバル Python 環境は変更しない。

```sh
uv venv --python 3.14 .venv
uv pip sync --python .venv/bin/python tests/requirements.txt
```

uv を使わない場合は Python 3.14 の `venv` と `pip install -r tests/requirements.txt` でもよい。Windows の実行ファイルは `.venv/Scripts/python.exe` を使う。`pyrightconfig.json` はプロジェクト内の `.venv` を参照する。エディタに別の Python toolchain を明示指定している場合は、この環境を選択する。

依存変更時は次で lock を更新し、差分と脆弱性検査を確認する。通常のテスト実行で依存更新は行わない。

```sh
uv pip compile --universal --python-version 3.14 tests/requirements.in --output-file tests/requirements.txt
uvx pip-audit --requirement tests/requirements.txt
```

## 変更に応じた最小の検証

| 変更 | 最初に実行する検証 |
| --- | --- |
| Bash/Zsh の起動・履歴・プロンプト・補完・locale | `docker compose -f tests/compose.yml run --build --rm shell-test` |
| Shell の構文・書き方 | `docker compose -f tests/compose.yml run --rm shell-lint-test` |
| installer の配置・削除・移行 | `docker compose -f tests/compose.yml run --build --rm install-test` |
| 共有 AI 資産・生成処理 | `python3 scripts/generate-ai-assets.py --repo .` と `python3 tests/test_generate_ai_assets.py` |

`Dockerfile.install` は source を build 時に取り込むため、変更後は `--build` を省略しない。`shell-test` はシェルのテストだけを実行し、無関係な AI 資産生成や全項目インストールを行わない。CI の `install-test` はシェルを含む全回帰 suite を引き続き実行する。

特定の回帰だけを検証する場合は、pytest のファイル名や node ID を指定する。

```sh
.venv/bin/python -m pytest tests/test_shell_startup.py tests/test_shell_completion.py tests/test_shell_harness.py -q

docker compose -f tests/compose.yml run --build --rm --entrypoint python install-test -m pytest tests/test_install.py::TestFreshInstallationReadback -q
```

ローカルに Zsh が無い場合、Zsh のテストは skip する。Bash と Zsh の両方を確認するには Docker を使う。`pytest.ini` は warning、未知の marker、不正な設定を失敗として扱う。

## テストで守る境界

- シェルの test harness は隔離 HOME と限定した PATH を使い、端末の追加ツールを誤って初期化しない。
- 各 `source` の終了状態を直後に確認する。後続の表示コマンドによる失敗の隠蔽を許さない。
- stderr は原則空でなければ失敗する。Bash の非 TTY 起動通知と、テストで明示した診断だけを許可する。
- 初期化テストは「失敗出力を実行しなかった」だけでなく、コマンドを期待する引数で実際に呼んだことも確認する。
- locale 単体テストは `common.sh` を直接読み、補完・プロンプトを初期化しない。
- 生成物を読むテストだけが session-scoped の生成 fixture を要求する。全テストに autouse しない。
- 配置済み HOME を読むだけのテストは 1 回の実インストールを共有する。移行・再実行・削除のテストは独立した HOME と実処理を使う。
- installer helper は全呼び出しの成功を検証する。削除確認は dangling symlink も残っていないことを検証する。
- 機能固有の検証を関数単位へ絞る場合も、実 CLI の再インストール・移行テストを残す。速度のために production の検証や承認経路を省略しない。

## 時間の計測

```sh
docker compose -f tests/compose.yml run --build --rm install-test --durations=25 -q
```

同じ環境・同じ選択で複数回比較する。件数を減らすこと自体を目的にせず、遅い setup の重複と、落とすべき不具合を見逃す assertion を先に見直す。全体検証の代わりに関連の薄い suite を毎回回すことと、最終的な全体検証を省くことは区別する。
