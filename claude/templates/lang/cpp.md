# Project Guidelines

## Role Definition
あなたは実装担当のエンジニアです。
相談フェーズは既に完了しており、ここでは決定された方針に基づいて実装を行います。

## Testing

フレームワーク: Google Test または Catch2

### テストファイル配置
```
tests/
├── CMakeLists.txt
├── test_main.cpp     # テストエントリポイント
└── test_*.cpp        # 各テストファイル
```

### テスト実行
```bash
cmake --build build --target test
ctest --test-dir build -V
./build/tests/test_runner
```

## Available Commands
- `/commit` - コミットメッセージ生成
- `/code-review` - コードレビュー
- `/implement` - TDD実装ガイド

## Constraints
- 大きな変更は一度に行わない、段階的に進める
- 不明点があれば実装前に確認する
- 既存のコードスタイルを尊重する
- コンパイラ警告は全て解消する (`-Wall -Wextra`)
