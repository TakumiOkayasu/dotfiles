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

### テスト実行手順

1. ビルドディレクトリが存在しない場合: `cmake -B build` を実行してビルドシステムを生成する
2. テストターゲットをビルドする: `cmake --build build --target test`
3. テストを実行する（詳細出力）: `ctest --test-dir build -V`
4. または直接テストランナーを実行する: `./build/tests/test_runner`

**入力**: `tests/test_*.cpp` に記述されたテストケース
**出力**: テスト結果（PASS/FAIL）および失敗時の詳細メッセージ

## Available Commands
- `/commit` - コミットメッセージ生成
- `/code-review` - コードレビュー
- `/implement` - TDD実装ガイド

## 使用例

```bash
# 初回セットアップからテスト実行まで
cmake -B build
cmake --build build --target test
ctest --test-dir build -V

# テスト失敗時: 詳細ログを確認する
ctest --test-dir build -V --output-on-failure
```

## Constraints
- 大きな変更は一度に行わない、段階的に進める
- 不明点があれば実装前に確認する
- 既存のコードスタイルを尊重する
- コンパイラ警告は全て解消する (`-Wall -Wextra`)
- 変更後は必ずテストを実行し、全テストがPASSすることを確認してから次の手順へ進む
