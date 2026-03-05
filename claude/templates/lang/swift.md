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

## Constraints
- 大きな変更は一度に行わない、段階的に進める
- 不明点があれば実装前に確認する
- 既存のコードスタイルを尊重する
- Swift の最新安定版を前提とする
