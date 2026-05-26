---
name: explain
summary: 指定コード・差分・設計を読み、編集せずに説明する
profile: read-only
skills:
  - codex-handoff
---

# explain

$ARGUMENTS

## Purpose

対象を読み、構造・依存・データフローを説明する。ファイル編集は禁止。

## Steps

1. 対象ファイル / ディレクトリ / 差分を特定する。
2. entry point と呼び出し経路を確認する。
3. 主要な型・データ構造・副作用を整理する。
4. 変更する場合に触るべき箇所を示す。

## Output

- 概要:
- entry point:
- 主要フロー:
- 依存関係:
- 副作用:
- 注意点:
- 変更するなら触る場所:
- 未確認:
