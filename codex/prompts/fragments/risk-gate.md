# Risk Gate Fragment

## low-risk

- 50行未満の局所変更
- DB / public API / auth / secrets / dependency 変更なし
- 既存設計内で完結
- rollback 容易

Action: 実装まで進めてよい。完了報告で検証を明示する。

## normal-risk

- 50-150行程度
- 既存 module をまたぐ
- テスト追加が必要
- 仕様は明確

Action: 短い計画を出し、必要最小限で実装する。

## high-risk

以下のいずれかに該当する場合:

- DB schema / migration
- public API / SDK / CLI contract
- auth / authorization / payment / secrets
- dependency add / remove / update
- 100行超または5ファイル超
- 既存データ破壊の可能性
- 仕様が曖昧
- production / external service への書き込み

Action: 計画提示と明示承認が必要。`premise-questioning` を検討する。
