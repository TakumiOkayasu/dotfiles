# Deep Review

高リスクまたは広範囲の差分を、実コードの証拠に基づいてレビューする。

`$ARGUMENTS`にbranch、commit、diff、path等の対象を指定する。省略時は現在の差分を使う。

## 原則

- 親レビューを必須の基線とし、subagentは専門性または独立性に実益がある観点だけ追加する
- subagent数、model、thinking budget、review roundを固定しない
- subagentを使えなくても、親が対象を十分に読めるならレビューを継続する
- セキュリティ、正しさ、データ整合性、性能、保守性、テスト、運用影響をリスクに応じて選ぶ
- 推測、一般論、差分外の既存問題をfindingへ混ぜない
- 修正案はactionableにする。安全で正確なcode snippetを示せない場合は、変更すべき契約・条件・検証方法を示す
- linter/formatterで決定できるstyleは人間レビューの主要findingにしない

## 手順

### 1. 対象と意図を確認する

- diff、変更ファイル、周辺契約、テスト、近接ruleを読む
- 変更の目的、非目標、外部影響、rollback可能性を整理する
- generated viewではなく正本まで追跡する

### 2. Risk mapを作る

最低限、該当するものを選ぶ。

- correctness / boundary / state transition / concurrency
- auth / authorization / secrets / injection / unsafe execution
- data loss / irreversible mutation / migration / external write
- public API / compatibility / dependency
- performance / resource lifecycle
- architecture / responsibility / unnecessary abstraction
- tests / observability / rollback

独立した専門調査で検出力が上がる時だけ、該当観点をsubagentへ分ける。

### 3. Findingを検証する

各findingに次を含める。

```text
severity
file:line
evidence
trigger / reachable path
impact
smallest safe correction
verification
```

反証できない推測はfindingにしない。

### 4. 人間レビューゲート

次の差分は、AIだけで`PASS`、approve、merge可と判定しない。

- project ruleまたはcommand-safetyで禁止される操作
- 明示承認が必要な操作
- 破壊的・不可逆な操作
- privilege、auth、authorization、secret、本番data/configへの影響
- dependency、DB schema、deploy、publish、external write
- guard、approval、rollback経路の削除または弱体化

該当時は先頭に`HUMAN_REVIEW_REQUIRED`を出し、次を必ず記載する。

```text
file:line
意図
発火条件
到達可能性
blast radius
rollback
safeguard
より安全な代替
確認できた人間承認記録
```

危険な文字列の存在だけでは発動せず、差分による意味、到達可能性、実行範囲、guardの変化を確認する。テスト、lint、静的解析、AIレビューが成功しても、人間承認記録がなければ`Merge recommendation: BLOCK`とする。

## 判定

- `BLOCK`: Critical finding、または未承認のhuman review gate
- `WARN`: merge前に判断・修正すべきWarningがある
- `PASS`: mergeを阻害するfindingがなく、人間ゲートも不要または承認済み

Warning件数だけで機械的に判定しない。

## 出力

```text
## 判定: BLOCK | WARN | PASS
Human review: required | not required | approved

### Findings
[severity] file:line
- Evidence:
- Impact:
- Correction:
- Verification:

### Checks performed
### Checks not performed
```
