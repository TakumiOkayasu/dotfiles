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
```bash
make test                     # Makefile 経由
./build/test_module            # 直接実行
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
- メモリ管理: malloc/free の対応を常に確認
