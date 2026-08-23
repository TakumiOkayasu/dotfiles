---
name: knowledge-reuse
description: 過去案件や前回セッションで得た再利用可能な判断知識を探す、または現在の発見を将来のAIへ引き継ぐときに使用する。プロジェクト固有のraw logではなく `.ai/` のruntime-neutral knowledgeを扱う。
---

# Knowledge Reuse

過去に支払った調査・失敗・判断コストを再利用する。常時コンテキストを増やさず、必要な時だけ関連knowledgeを検索する。

## 読むとき

1. 現在の問題を表す具体的な語を2-5個選ぶ。
2. `ai-knowledge-search <語...> --json` が利用可能なら使う。current projectの `.ai/knowledge/` と、`AI_KNOWLEDGE_REPOSITORY` が設定されていれば集約済みの他project knowledgeを同時に検索する。
3. CLIが利用できない場合はcurrent projectの `.ai/knowledge/` を直接検索する。
4. verified knowledgeで十分な根拠がなければ、必要な場合だけ `--include-inbox` または `.ai/inbox/` を候補情報として検索する。
5. hitしたfile全体を読む前にpath/snippet/適用条件を確認し、必要なentryだけ読む。
6. 適用条件、反例、検証時点を確認する。
7. 現在の一次ソースや実コードと矛盾した場合は現在の証拠を優先する。

全knowledgeやcentral repository全体をコンテキストへ読み込まない。

## 残すとき

次のいずれかに該当する場合だけ `.ai/inbox/` へcandidateを残す。

- 別taskでも同じ失敗を避けられる。
- 再検索や再調査を大きく減らせる。
- 設計判断の適用条件や反例として再利用できる。
- tool/runtime固有の罠で、同じ環境なら再発しうる。

単なる作業履歴、raw log、生成物一覧、今のtaskでしか意味を持たないメモは残さない。

candidateには最低限、次を含める。

```markdown
# <finding>

## Finding

<将来の判断を変える内容>

## Applies when

- <適用条件>

## Evidence

- <再現手順、test、commit、一次ソース等>

## Counterexample / invalid when

- <適用しない条件>
```

## knowledgeへの昇格

次のいずれかを満たしたcandidateだけ `.ai/knowledge/` へ昇格する。

- 異なるtaskまたはprojectで再利用され、同じ判断が有効だった。
- 再現可能なtest/measurementで一般化可能性を確認できた。

一度の成功だけでは昇格しない。always-loaded ruleへの昇格はさらに厳しくし、ほぼ全taskで成立する不変条件に限定する。

## Runtime stateとの境界

- `.claude/` / `.codex/` は各runtimeが所有する。
- `claude_tmp/` / `codex_tmp/` はscratch sourceになり得るが、直接knowledgeとしてexportしない。
- runtime stateに価値ある発見があれば、要点だけを `.ai/inbox/` へharvestする。
