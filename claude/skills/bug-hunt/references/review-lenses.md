# Review Lenses

差分に対して、最低1回ずつ異なる観点を適用する。全項目を機械的に埋める必要はないが、最初の観点で見つからなければ次へ進む。

## 1. 値と境界

- null / undefined / nil
- 空文字、空配列、空map、空結果
- 0、負数、符号反転、最大/最小値
- off-by-one、inclusive/exclusive
- overflow、丸め、浮動小数、通貨
- Unicode、結合文字、改行、NUL、絵文字
- timezone、DST、月末、うるう年、秒精度
- 重複、順序不同、ソート安定性

## 2. 制御フロー

- return/continue/break位置の変化
- 条件式の否定、AND/OR、優先順位
- early returnで後処理を飛ばす
- await/return漏れ、非同期例外
- catchが握り潰す、finally未実行
- switch/matchのdefault、fallthrough
- lazy evaluationによる副作用欠落

## 3. 状態とライフサイクル

- 初回と2回目で挙動が違う
- 再試行が二重副作用を生む
- 部分成功後の再実行
- stale cache、初期化順、破棄後利用
- 共有mutable state、singleton汚染
- transaction境界、commit/rollback漏れ
- UIのloading/error/success遷移

## 4. 並行性

- check-then-act競合
- lost update、二重登録、重複送信
- lock順序、transaction isolation
- cancellation、timeout、late response
- Promise/taskの未回収
- worker/process間の共有前提

## 5. 契約と互換性

- interface実装漏れ、型の狭窄/拡張
- 戻り値、例外型、status codeの変化
- required/optional、default値の変化
- JSON field名、nullability、enum追加
- DB schemaとORM/entityの不一致
- API version、後方互換性
- public methodの呼び出し規約

## 6. データ永続化

- WHERE条件不足、全件更新/削除
- JOIN増幅、重複行、N+1
- INSERT/UPDATEの列対応ずれ
- migrationの既存データ処理
- unique/FK/check制約違反
- timezone/encoding/collation差
- read-after-write整合性

## 7. セキュリティ

- 認証済みと認可済みの混同
- tenant/user/resource境界漏れ
- SQL/command/template injection
- path traversal、SSRF、open redirect
- secret/token/log漏えい
- input validationの順序とcanonicalization
- fail-open、default allow

## 8. 接続と環境

- 設定キー名、env既定値
- OS path、case sensitivity、改行
- locale、encoding、timezone
- dependency version/API差
- dev/test/prodで異なる分岐
- feature flagのon/off
- 外部APIのtimeout/retry/rate limit

## 9. テストの死角

- happy pathしかない
- mockが実装契約と異なる
- assertionが弱い/実行されていない
- snapshotが誤りを承認している
- test order依存、共有fixture汚染
- エラー経路、境界値、2回実行がない
- テスト対象と本番配線が異なる

## 10. 差分特有の逆向き確認

追加行だけでなく、削除・移動・置換で失われた保証を探す。

- validationを削除していないか
- transaction/lock/awaitを外していないか
- cleanup/finallyを失っていないか
- default/elseを消していないか
- clone/copyが参照共有へ変わっていないか
- filter条件が緩んでいないか
- 例外変換、ログ、監査記録を失っていないか
