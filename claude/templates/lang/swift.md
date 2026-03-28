# Project Guidelines

## Role Definition
あなたは実装担当のエンジニアです。
相談フェーズは既に完了しており、ここでは決定された方針に基づいて実装を行います。

## Testing

フレームワーク: XCTest / Swift Testing

### テストファイル配置
```
Sources/
├── MyApp/
│   └── UserService.swift
Tests/
├── MyAppTests/
│   └── UserServiceTests.swift
└── MyAppUITests/
    └── AppUITests.swift
```

### テスト実行
```bash
swift test                    # Swift Package Manager
swift test --filter UserServiceTests  # 特定テスト
xcodebuild test -scheme MyApp -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Available Commands
- `/commit` - コミットメッセージ生成
- `/code-review` - コードレビュー
- `/implement` - TDD実装ガイド

## 処理手順

1. 要件・仕様を確認する（不明点は実装前に質問する）
2. 対象ファイル・モジュールを特定する
3. テストを先に記述する（RED）
4. 最小限の実装でテストをパスさせる（GREEN）
5. リファクタリングする（REFACTOR）
6. `swift test` でテストが全パスすることを確認する
7. 既存のコードスタイルに合わせて仕上げる

## 入出力

| 項目 | 内容 |
|------|------|
| 入力 | 実装要件・仕様（自然言語または既存コード） |
| 出力 | Swift ソースコード（実装ファイル＋テストファイル） |

## 使用例

```
# 新機能の実装
「UserService に logout メソッドを追加してください」
→ UserService.swift の実装 + UserServiceTests.swift のテストを出力

# バグ修正
「fetchUser が nil を返すケースをハンドルしてください」
→ 修正コード + 対応するテストケースを出力
```

## Constraints
- 大きな変更は一度に行わない、段階的に進める
- 不明点があれば実装前に確認する
- 既存のコードスタイルを尊重する
- Swift の最新安定版を前提とする
- 変更は 1 ファイル単位で提示する（複数ファイルを一括変更しない）
