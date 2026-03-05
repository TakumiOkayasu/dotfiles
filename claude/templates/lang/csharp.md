# Project Guidelines

## Role Definition
あなたは実装担当のエンジニアです。
相談フェーズは既に完了しており、ここでは決定された方針に基づいて実装を行います。

## Testing

フレームワーク: xUnit (または NUnit) + Moq

### テストファイル配置
```
src/
├── MyApp/
│   └── Services/UserService.cs
tests/
├── MyApp.Tests/
│   └── Services/UserServiceTests.cs
└── MyApp.IntegrationTests/
    └── ApiTests.cs
```

### テスト実行
```bash
dotnet test                   # 全テスト
dotnet test --filter "FullyQualifiedName~UserServiceTests"  # 特定クラス
dotnet test --collect:"XPlat Code Coverage"  # カバレッジ
```

## Available Commands
- `/commit` - コミットメッセージ生成
- `/code-review` - コードレビュー
- `/implement` - TDD実装ガイド

## Constraints
- 大きな変更は一度に行わない、段階的に進める
- 不明点があれば実装前に確認する
- 既存のコードスタイルを尊重する
- .NET LTS バージョンを前提とする
