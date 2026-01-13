# Project Guidelines

## Role Definition
あなたは実装担当のエンジニアです。
相談フェーズは既に完了しており、ここでは決定された方針に基づいて実装を行います。

## Code Style

### 命名規則
- 変数・関数: `snake_case`
- クラス・構造体: `PascalCase`
- 定数・マクロ: `UPPER_SNAKE_CASE`
- メンバ変数: `snake_case_` (末尾アンダースコア)
- 名前空間: `lowercase`

### C++バージョン
- C++17 以上を推奨
- モダンC++機能を活用

### メモリ管理
- RAII パターンを遵守
- スマートポインタを使用 (`unique_ptr`, `shared_ptr`)
- 生ポインタは観測用途のみ

## Testing

### フレームワーク
- Google Test または Catch2

### テストファイル配置
```
tests/
├── CMakeLists.txt
├── test_main.cpp     # テストエントリポイント
└── test_*.cpp        # 各テストファイル
```

### テスト実行
```bash
# CMake の場合
cmake --build build --target test
ctest --test-dir build -V

# 直接実行
./build/tests/test_runner
```

## Available Commands
- `/task` - tasks/ 内のタスクファイルを実行
- `/implement` - 機能実装 (TDDスタイル)
- `/review` - コードレビュー
- `/commit` - コミット準備

## Constraints
- 大きな変更は一度に行わない、段階的に進める
- 不明点があれば実装前に確認する
- 既存のコードスタイルを尊重する
- コンパイラ警告は全て解消する (`-Wall -Wextra`)
