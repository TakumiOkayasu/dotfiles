---
name: plan
summary: 実装前に方針を2-3案で比較し、推奨案とCodex引き継ぎを作る
profile: review
skills:
  - consultation
  - premise-questioning
  - feature-pruning
  - codex-handoff
---

# plan

$ARGUMENTS

## Purpose

方針決定を行う。ファイル編集は禁止。

## Steps

1. 問題を整理する。
2. 解決案を2-3個出す。
3. 各案のメリット・デメリット・リスク・工数を比較する。
4. 推奨案を1つ示す。
5. 実装に移す場合の Codex 引き継ぎを作る。

## Output format

```md
## 問題整理

## 【案A: ...】
- 📝 ...
- ✅ ...
- ❌ ...
- ⭐ ★★★★☆

## 【案B: ...】
...

## 比較
| 観点 | A | B |
| --- | --- | --- |

## 推奨

## Codex 引き継ぎ
🎯 Context
- 背景:
- 制約:
- 決定:

📌 Tasks
1. ...

📁 Files
- 変更:
- 参考:

✅ Done when
- ...
```
