# Composable Contracts and Context Boundaries

ISLe氏がdixq.net上の設計議論で示した考え方を、特定言語から切り離して本skillの判断材料として整理する。

これは完成形のpattern catalogではない。現在のユースケースで拡張軸またはdata access境界が必要になった時だけ参照する。

## 同じ最小契約で組み合わせる

読み出し元、展開、復号等がすべて同じ「次の要素を提供する」契約を満たすなら、利用側は最外周の契約だけを使える。

```text
Source
  -> Transform
  -> Transform
  -> Consumer
```

各Transformは受け取った契約にだけ依存し、自身も同じ契約を提供する。

この構成では次が成立する。

- Sourceの種類をConsumerが知らない
- Transformの順序をcompositionで変更できる
- 新しいTransformを追加してもConsumerを変更しない
- buffering、prefetch、async、cache等の内部状態を外部へ漏らさない

拡張性は派生型の数ではなく、**既存利用側を変更せずに新しい組み合わせを構成できること**で評価する。

## 利用側が使わない違いを公開しない

実装がfile、network、memory等で異なっても、利用側が必要とする操作が同じなら、その差をpublic contractへ出さない。

ただし「将来組み合わせるかもしれない」だけで共通契約を作らない。現在のユースケースに同じ協調が現れた時点で最小契約を導入する。

## Contextをカテゴリ境界として使う

大きなdata graphが1つであっても、利用側へ全体を直接公開しない。

```text
Root context
  -> Category context
      -> Domain contract
```

- Rootはカテゴリ別の契約を提供する
- 必要であればcontextを入れ子にする
- 利用側は必要なカテゴリだけを知る
- dataの物理配置、共有、重複、lifetimeをcontextが隠す
- Rootが毎回同じinstanceを返すと利用側が仮定しない

関連するcontract familyを整合した状態で提供する必要がある場合、生成境界はAbstract Factoryとして扱える。pattern名を先に適用するのではなく、現在必要な生成責務から判断する。

## Review questions

```text
[ ] 拡張されるべき箇所は現在のユースケースから特定できるか
[ ] その箇所は最小の共通契約で表現できるか
[ ] wrapper/compositionの各要素は隣の具象型を知らないか
[ ] 並べ替えまたは差し替えで利用側の変更が発生しないか
[ ] internal buffer/state/async方式を外部が知る必要がないか
[ ] data accessは必要なカテゴリ契約だけへ限定されているか
[ ] instance identityやsingleton実装を利用側が仮定していないか
```
