# Decision Guide

<!-- codex-port: managed; source=common/skills/interface-first-design/references/decision-guide.md; generated-by=scripts/port-claude-assets-to-codex.py -->

## Codex portability notes

- This file was ported from `common/skills/interface-first-design/references/decision-guide.md`.
- Codex skills are packaged into `plugins/dotfile-work-codex` or `plugins/dotfile-work-codex-extra`; `install.sh` should not duplicate them into `${HOME}/.agents/skills` in plugin-only mode.
- Rules are not automatically loaded. Read `RULES_CORE.md`, `RULES_INDEX.md`, and only the detailed rules applicable to the task.
- Claude slash-command references should be invoked through Codex plugin skills such as `$feat`, `$fix`, `$deep-review`, `$rules-required`, or `/skills`. Do not use custom `/prompt:*` commands.
- Subagent usage must follow `${HOME}/.codex/SUBAGENTS.md` and the current Codex tool contract.

この資料は、新しいinterface、method、Factoryを追加する前の判断に使う。

## 最初の4問

1. 現在のユースケースに必要か
2. 利用側はその違いを知る必要があるか
3. 既存契約の新実装だけでは満たせないか
4. 理想上の役割・操作か、実装上の分類・表現か

4問のどれかに答えられない場合は追加しない。

## interfaceを追加する

追加する条件:

- 現在の利用側が新しい役割へ依頼する必要がある
- 既存契約へ追加すると責務が混ざる
- 複数の実装を想定したからではなく、現在の協調境界として必要である
- 契約だけでユースケースを追跡するために必要である

追加しない例:

- 現実に種類が複数ある
- 将来差し替えるかもしれない
- class図を対称にしたい
- framework上の型が分かれている
- 実装が保持している値を公開したい

## methodを追加する

追加する条件:

- 現在のユースケースで実際に呼ぶ
- 協調相手の状態を取得して判断する代わりに、目的を直接依頼できる
- 契約の責務内に収まる

追加しない例:

- 将来使いそう
- debugしやすい
- 具象型へcastすれば呼べるmethodを表面化したい
- `Value`、`Raw`、`Type`、`Kind`等を取り出したい

## 対象を分ける

分ける前に確認する:

```text
利用側はAとBへ異なる依頼をするか
  No -> 分けない

AとBの違いを利用側が判断する必要があるか
  No -> 分けない

1つの契約で現在の協調が成立するか
  Yes -> 1つに保つ

その契約自体がなくても成立するか
  Yes -> 契約を削る
```

実装上のButton、Encoder、Touch Surface等が存在しても、利用側が同じ操作しか行わないなら1つのControl契約でよい。入力の発生だけを扱えばよいなら、Control契約自体が不要な場合もある。

## Factoryを追加する

Factory境界が必要な兆候:

- 利用側が具象実装を選択している
- `if` / `switch`で生成対象を変えている
- 生成前後にvalidation・normalizationが必要
- 環境や設定で生成方法が変わる
- 同じ生成手順が複数箇所へ散る
- 生成されるobject同士に整合性が必要

Factory classを追加しなくてよい場合:

- composition rootで1回だけ生成する
- 具象選択が利用側へ漏れない
- 生成手順が単純で再利用されない
- family整合性がない

この場合、composition root自体が生成境界として機能する。

## Abstract Factoryへ成長させる

次をすべて満たす場合だけ採用する:

- 現在、複数の関連objectを一組として生成する
- 組み合わせを誤るとユースケースの不変条件を破る
- 実装familyを切り替える必要がある
- 単純Factoryの組み合わせでは整合性を十分に隠せない

「将来複数providerへ対応するかもしれない」だけでは採用しない。

## 新要求を受けた時

```text
1. 既存契約の別実装で対応できるか
   -> Yes: 実装だけ追加

2. 既存契約の既存methodの組み合わせで対応できるか
   -> Yes: 契約変更なし

3. 現在の利用側が新しい役割・操作を必要とするか
   -> Yes: 最小の契約差分を追加

4. 実装上の都合だけか
   -> Yes: 実装内部またはFactory境界へ閉じる
```

## 判断結果の記録

```text
Current use case:
Required collaboration:
Existing contract sufficient:
Difference the caller must know:
Contract change:
Creation boundary:
Deferred decisions:
```
