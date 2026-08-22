---
name: interface-first-design
description: 個人開発・greenfield・設計裁量のある変更で使用。現在の1ユースケースから最小の理想契約と協調だけを定義し、具象データ・インスタンスの生成と選択をFactory境界へ隠し、必要になった時だけ設計を成長させる。既存プロジェクトでは既存の設計思想・framework・規約を優先し、この手法を理由に全面改修しない。「スモールデベロップメント」「契約先行」「interface設計」「Factoryで生成を隠す」「分類しすぎ」もトリガー。
---

# Interface-First Small Development

**完成形を先に設計するな。現在の1ユースケースを成立させる最小の理想契約だけを作り、必要になった時だけ育てよ。**

常時守る不変条件は `contract-driven-object-collaboration` rule を正本とする。本スキルは、その原則を個人開発・greenfield・設計裁量のある変更へ適用するための設計手順を扱う。

## 適用範囲

全面適用する:

- 個人開発
- greenfield
- 独立した新規component
- 設計裁量が明示的に与えられた変更

既存の業務・チーム開発では、既存architecture、frameworkの定石、公開contract、命名規則、テスト方針を優先する。この手法との違いだけを理由に既存構造を全面改修しない。変更範囲内で新たな結合や表現漏洩を増やさず、既存方針と両立する最小境界を選ぶ。

## 中核原則

### 1. Current Use Case First

将来の完成形、想定device、想定provider、想定formatを先に列挙しない。設計対象は、現在実装する1ユースケースだけとする。

```text
現在の1ユースケース
  -> 今必要な協調
  -> 今必要な最小契約
```

### 2. Ideal Contract Before Implementation

契約は既存class、API response、DB schema、protocol、framework callbackから抜き出さない。

```text
利用目的
  -> 理想的な役割と操作
  -> 契約
  -> 契約に追随する実装
```

### 3. Collaborate Without Knowing State

各オブジェクトは、協調相手が内部に何を保持し、何で識別し、どの具象型で実装されているかを知らないし、知る必要もない。

相手から値を取得して呼び出し側が解釈・分岐するより、現在必要な操作を契約として依頼する。

### 4. Do Not Model Unused Differences

現実世界や実装に種類が存在しても、現在の利用側が区別しないなら契約上も区別しない。

```text
実装上は A / B / C
利用側は同じ操作しか行わない
  -> 1つの契約

その1つの契約も協調に不要
  -> 契約自体を作らない
```

物理分類、vendor分類、data format分類を、そのまま継承階層や能力契約へ写さない。

### 5. Hide Representation

ドメイン契約は原則として別のドメイン契約を受け取り、別のドメイン契約を返す。内部表現が文字列、数値、日時、path、URI、byte列等であっても、利用側がその表現を知る必要がなければ公開しない。

`Value`、`Raw`、`Kind`、`Type`、`Code`、`Index`等を公開し、利用側へ解釈・分岐を押し付ける抜け道を作らない。

### 6. Hide Creation

具象データ・具象インスタンスの選択と生成を、ユースケースを実行する利用側へ漏らさない。

- 単純な生成・選択には最小のFactoryまたはcomposition境界を使う
- 関連する実装群を整合した組み合わせで生成する必要が生じた時だけAbstract Factoryへ成長させる
- constructor、Factory、DI containerの形式を先に固定しない
- 利用側が具象型を選び、生成し、分岐する構造を避ける

composition rootだけが一度生成し、選択ロジックも再利用もない場合は、そこでの直接生成を新しいFactory classへ包む必要はない。重要なのは、ユースケース側へ具象選択と生成手順を漏らさないことである。

### 7. Grow Only From Evidence

新しい要求が来たら、最初に既存契約の新実装だけで満たせるか確認する。

```text
既存契約の新実装で満たせる
  -> 契約を変更しない

既存契約では現在の要求を表現できない
  -> 今必要になった役割・操作だけを追加
```

DIは、この契約へ実装を割り当てて構成した結果であり、設計の起点ではない。

## 設計手順

### Step 1: 1ユースケースを固定する

言語非依存で記述する。

```text
Given:
  必要な前提

When:
  利用者または上位の意図

Then:
  期待する結果

Failure:
  想定内の失敗・未解決状態
```

同時に複数の将来ユースケースを混ぜない。不明点は `[要確認: ...]` とし、想像で補わない。

### Step 2: 最小の協調を書く

class一覧や分類表を先に作らず、ユースケースを成立させる作用だけを書く。

```text
Role A
  -> Role B
  -> Result
```

役割を1つ削除してもユースケースが成立するなら、その役割はまだ作らない。

### Step 3: 必要な契約だけを定義する

現在の協調で呼ばれる操作だけを契約へ置く。

- 現在呼ばれないmethodを追加しない
- 現在区別しない対象を派生契約へ分けない
- 現在使わない能力契約を追加しない
- marker contractだけで成立するなら、値や操作を推測して追加しない
- 具象実装を想像してproperty一覧を作らない

### Step 4: Contract-only Walkthrough

具象型を一切仮定せず、正常系と失敗系を契約だけで最後まで追跡する。

```text
[ ] 具象型へのcastなしで成立する
[ ] primitiveの意味を利用側で解釈しなくても成立する
[ ] 相手の内部状態を取得して分岐しなくても成立する
[ ] 実装上の種類を利用側が選択しなくても成立する
[ ] framework、storage、protocol、file formatを知らなくても成立する
[ ] 現在のユースケースに使わない契約・methodがない
```

### Step 5: Creation Boundaryを決める

次のいずれかが利用側へ現れた場合だけ、Factory境界を追加する。

- 具象実装の選択
- 複雑な生成手順
- 生成時のvalidation・normalization
- 関連する複数objectの整合性
- 環境による生成差分

最初は最小のFactoryでよい。関連object familyの整合性が現在必要になった場合だけAbstract Factoryを採用する。

### Step 6: 実装して検証する

ここで初めて具体実装、framework、外部仕様、保存形式を割り当てる。外部との差を埋めるAdapter、Translator等も、実際の差異を確認した後に必要なものだけ追加する。

設計完了後はTDDまたは既存projectの検証workflowへ移行する。

### Step 7: 次の要求で再評価する

新しい要求ごとにStep 1へ戻る。既存契約を維持できるなら実装だけ追加する。契約を育てる場合も、今回必要になった差分だけを追加する。

## 参照資料

- interface・method・Factoryを追加する判断は `references/decision-guide.md`
- 既存設計の診断と最小修正は `references/troubleshooting.md`

## 禁止事項

| 禁止 | 理由 |
| --- | --- |
| 完成形のclass図・継承階層を先に作る | 将来予測が現在の設計を支配する |
| 現実の種類ごとに契約を作る | 利用側が使わない差異をモデル化する |
| 能力がありそうという理由で能力契約を作る | capability explosionを招く |
| 既存実装・DB・API・frameworkから契約を写す | 実装が理想契約を支配する |
| 契約を状態一覧のDTOにする | 利用側が内部状態を解釈する |
| 具象型の選択・生成をユースケース側へ置く | 実装差分と生成手順が漏れる |
| Abstract Factoryを将来のために先行導入する | YAGNI違反 |
| DI方式を先に決める | DIが設計目的になる |
| この手法を理由に既存projectを全面改修する | projectの既存契約と変更scopeを破壊する |

## 出力形式

設計結果は、まず言語非依存で出力する。

```text
## [機能名] Small Development

### 現在のユースケース
Given / When / Then / Failure

### 最小の協調
Role A -> Role B -> Result

### 今必要な契約
Contract A
  accepts: Contract B
  provides: Contract C

### 今はモデル化しない差異
- ...
- ...

### Creation Boundary
- 利用側が知らない生成・選択
- Factoryが必要か
- Abstract Factoryが必要か

### Contract-only Walkthrough
- 正常系
- 失敗系

### 次の要求まで決めないこと
- ...
```

具体言語のコードは、ユーザーが明示要求した場合または実装フェーズまで出さない。

## 完了チェックリスト

```text
[ ] 現在の1ユースケースだけを対象にした
[ ] 不要な役割・分類・能力を削った
[ ] 利用側が使わない実装上の差異をモデル化していない
[ ] 各オブジェクトが協調相手の内部状態・表現を知らない
[ ] 契約からprimitiveや外部型が漏れていない
[ ] 契約だけで正常系・失敗系を追跡できる
[ ] 具象型へのcastや種別switchがない
[ ] 具象データ・インスタンスの生成と選択を利用側へ漏らしていない
[ ] Factoryの粒度は現在の生成要件に必要な最小限である
[ ] 既存契約の新実装だけで対応できないか確認した
[ ] 既存projectでは既存方針を優先した
[ ] 次の要求まで決めなくてよいことを残した
```
