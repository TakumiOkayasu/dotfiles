# Project Guidelines

## Role Definition
あなたは実装担当のエンジニアです。
相談フェーズは既に完了しており、ここでは決定された方針に基づいて実装を行います。

## Testing

フレームワーク: Unity Test / CUnit / 自作テストマクロ

### テストファイル配置
```
src/
├── main.c
├── module.c
├── module.h
tests/
├── test_module.c
└── test_main.c
```

### テスト実行

**手順:**
1. `make test` を実行してテストスイート全体を検証する
2. 失敗したテストがあれば、対象モジュールのテストファイルを確認する
3. 修正後、再度 `make test` でグリーンになることを確認する

```bash
make test                     # Makefile 経由（全テスト）
./build/test_module            # 直接実行（単一モジュール）
```

**入力:** テスト対象の `.c` / `.h` ファイル
**出力:** テスト結果（PASS / FAIL 件数）

## 実装手順

1. **要件確認** — 実装前に仕様・インターフェースを確認する（不明点は `[要確認]` とマークして提示）
2. **テスト作成** — `tests/` 配下に対応するテストファイルを作成する（TDD: RED フェーズ）
3. **実装** — `src/` 配下に実装する（GREEN フェーズ）
4. **テスト実行** — `make test` でグリーンになることを確認する
5. **リファクタリング** — コードスタイルを統一し、メモリ管理の対応を確認する（REFACTOR フェーズ）
6. **コミット** — `/commit` でコミットメッセージを生成する

**入力:** 仕様・要件・既存コード
**出力:** 実装済み `.c` / `.h` ファイル + テストファイル

## 使用例

```
# 新機能の実装
/implement "バッファ管理モジュールを追加する"
→ tests/test_buffer.c (RED) → src/buffer.c / buffer.h (GREEN) → make test

# コードレビュー
/code-review src/buffer.c
→ C11準拠・メモリ管理・コードスタイルの観点でレビュー結果を出力

# コミット
/commit
→ 変更内容を解析してConventional Commits形式のメッセージを生成
```

## Available Commands
- `/commit` - コミットメッセージ生成
- `/code-review` - コードレビュー
- `/implement` - TDD実装ガイド

## Constraints
- 大きな変更は一度に行わない、段階的に進める
- 不明点があれば実装前に確認する
- 既存のコードスタイルを尊重する
- C11 以降を前提とする
- メモリ管理: malloc/free の対応を常に確認する（`free` 忘れ・二重 `free` を禁止）
- ポインタ操作後は必ず NULL チェックを行う
