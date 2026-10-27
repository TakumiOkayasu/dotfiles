# PR #515 deep-review / refactoring

HUMAN_REVIEW_REQUIRED

対象: PR #515、基線 `464d82f0933c266339c2c820e6501281c5d34024`。親による差分レビューに加え、配布物・資源所有とスモーク証拠判定を独立に点検した。再レビューで下記4件の解消を確認した。

| Finding | 根拠と影響 | 修正と回帰確認 |
| --- | --- | --- |
| P2: cleanup失敗時のready残存 | 成功結果の保存後にcloseが失敗すると、失敗終了にもかかわらずreadyだけが残る | 所有資源をExitStackで回収してからreadyを公開。closeがOSErrorを返すとblockedかつreadyなし |
| P2: 低速bodyの期限確認遅延 | read(1MiB)内部で部分readが続くと、外側の期限判定へ戻らない | read1と読取前後の期限確認。制御時計による部分readで期限超過後の追加read/writeを拒否 |
| P3: 事前条件拒否時の資源所有 | factoryで一時領域を先に作り、views/outputの事前条件拒否ではcloseに到達しない | CodexWorkerへ責務を集約し、呼出し時まで資源確保を遅延。生成だけでは一時領域を作らない |
| P2: I/O準備失敗で既存証拠を破棄 | listenerのbind等が失敗すると、完了済み試験とruntime hashもpreflight未完了へ置換される | 隔離環境をsmoke_environmentへ、試験結果収集をcollect_live_checksへ分離。I/Oだけfailedにし既存結果を維持 |

## コメント対応

Python 3.14以降をrunner/スモークの開始条件にした。旧版は入力読込・出力作成・外部取得前に終了コード2とアップグレード案内を返す。`uv python install 3.14`、`uv run --python 3.14 python ...` または `python3.14` を案内し、検証Dockerも `python:3.14-slim` へ揃えた。

## 維持した契約

latestはrun内で1回解決、公式SHA照合、各phase前のbinary SHA再照合、独立process、段階開示、環境なし/MCP無効化確認、tool/承認要求で停止、旧版/providerへの自動代替なし。I/O拒否は実runtime出力だけを証拠にし、tool未試行を成功にしない。構造改善と上記4件・Python要件以外の仕様変更は加えていない。

## 検証

- passed: Python 3.14.8 + PYTHONWARNINGS=errorで関連126テスト。追加した6件は修正前の失敗を確認した。
- passed: 資産生成、py_compile、diff --check。旧Pythonで実際に副作用前のupgrade案内を確認。
- passed: Python 3.14.8で実latest取得・公式SHA照合・環境なしephemeral/read-only/network無効/承認never・MCP canary disabled/未起動・子process回収を再確認。記録は `tdd-codex-smoke-20261027.json`、adapter SHAは最終コードと一致。
- failed/baseline: installerを含む拡張実行は204 passed / 60 failed。変更前PRではinstaller単独78 passed / 同じ60 failure IDs。新規failure IDなし。GNU stow不在などの環境制約があり、installer成功とは報告しない。
- skipped: Dockerサービス、実モデルでの10 phaseと能動的I/O拒否・実turn中kill。認証を渡さずモデルturnは0。

## 人間ゲート

Merge recommendation: BLOCK (人間によるマージ判断待ち)。latest取得・外部実行・認証の一時コピー・guard変更を含むため、AIレビューや成功したテストで人間ゲートは解除しない。ユーザーは通常runnerへのlatest/SHA適用、今回のレビュー・リファクタリング・Python要件変更・コメント対応を指示済み。元設定は上書きせず、SHA不一致/実行境界不成立は停止する。rollbackは追加commitのrevert。固定版への代替やmergeは行わない。

一次ソース: [HTTPResponse](https://docs.python.org/3.14/library/http.client.html)、[ExitStack](https://docs.python.org/3.14/library/contextlib.html#contextlib.ExitStack)。ハッシュ一致は配布物の同一性確認であり、最新版の隔離安全性の証明ではない。
