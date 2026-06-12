# Natural Japanese

<!-- codex-port: managed; source=claude/rules/natural-japanese.md; generated-by=scripts/port-claude-assets-to-codex.py -->

## Codex portability notes

- This file was ported from `claude/rules/natural-japanese.md`.
- Codex skills are packaged into `plugins/dotfile-work-codex` or `plugins/dotfile-work-codex-extra`; `install.sh` should not duplicate them into `${HOME}/.agents/skills` in plugin-only mode.
- Global and project rules live under `${HOME}/.codex/rules/*.md`; do not assume they are automatically loaded unless the rules-inject hook injected them into context.
- Claude slash-command references should be invoked through Codex plugin/local skills such as `@feat`, `@fix`, `@deep-review`, or `/skills`. Do not use custom `/prompt:*` commands.
- Subagent usage must follow `${HOME}/.codex/SUBAGENTS.md` and the current Codex tool contract.

- 基本的にあなた達の日本語はAIだと簡単にわかる、以下の点に注意しなさい。

## 人は本質的にそもそも怠惰である

- 人間は基本的に怠惰なのでできるだけ簡単な書き方、言い回し、変換を行うので、まずこれを念頭に置きなさい。

## 言い回しがおかしい

- 日本語は助詞が重要なため、助詞を**絶対**に省略するな

## いかに当てはまる文章は書くな

### 冗長な書き方

- 共通化（抽象化）
- 別の例（仮想ファイルシステム VFS）

こういう前の語彙に対してカッコで補足する書き方は基本的に冗長

### 余計な強調

** このような強調はまず使用するな

### 人間が使わない記号の使用

- `「」` （かぎかっこ）や `・`（てん/黒丸/中黒）などは人間はあまり使わない
    - かっこは `""` （ダブルクォーテーション）に置き換えることが多いがあまり使わない
- `・` は `/` （スラッシュ）に置き換えることが多い

### 段落番号を書くな

基本的に後からの編集によって順番や内容の増減が起きるため番号をハードコードしてはいけない、以下がダメな例

```text
1. 有線LANと無線LANについて、物理層の違いからデータリンク層の実現方法の違い、
    そしてネットワーク層から見た共通化までを順に検討する。
2. 下位層は違うのに、ある層から上では同じに見え、途中の層の実現が違う、
```

このように直接マークダウン内に数字を振るな。

```text
* 有線LANと無線LANについて、物理層の違いからデータリンク層の実現方法の違い、
    そしてネットワーク層から見た共通化までを順に検討する。
* 下位層は違うのに、ある層から上では同じに見え、途中の層の実現が違う、
```
書くなら標準のリスト形式でかけ。

又

```text
## 1. 課題1：有線LANと無線LANの比較

### 1.1 物理層の違い
```

このようなヘッダーに数字を振るのも禁止。

### 意味不明なアスキーでの表現

```text
+-------------------------------------------------------------+
|                         Kubernetes                          |
|                                                             |
|  +----------------------+      +--------------------------+  |
|  |  API Server Service  |----->|  Go + Gin Deployment     |  |
|  |  LoadBalancer/Ingress|      |  Pods: api-0, api-1      |  |
|  +----------------------+      +------------+-------------+  |
|                                           |                  |
|                  +------------------------+---------+        |
|                  |                                  |        |
|                  v                                  v        |
|        +-------------------+              +----------------+ |
|        | PostgreSQL        |              | MinIO          | |
|        | StatefulSet + PVC |              | StatefulSet/PVC| |
|        +-------------------+              +----------------+ |
|                                                             |
+-------------------------------------------------------------+
```

このようなアスキーアートでの表現は人間は書かない、特に複雑なものは書かない。もし必要ならばマーメイドといったコードで図を表記できるのを使用するべきであり、アスキーアートは使用しないこと。



## Codex rule loading

This rule must be treated as mandatory whenever it is injected by `rules-inject.sh` or explicitly read from `${HOME}/.codex/rules/*.md`. If this rule conflicts with a nearer project rule, follow the nearer project rule and report the conflict.
