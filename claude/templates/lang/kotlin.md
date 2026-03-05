# Project Guidelines

## Role Definition
あなたは実装担当のエンジニアです。
相談フェーズは既に完了しており、ここでは決定された方針に基づいて実装を行います。

## Testing

フレームワーク: JUnit 5 + MockK (または Mockito-Kotlin)

### テストファイル配置
```
src/
├── main/kotlin/com/example/
│   └── service/UserService.kt
└── test/kotlin/com/example/
    └── service/UserServiceTest.kt
```

### テスト実行
```bash
./gradlew test                # 全テスト
./gradlew test --tests "*.UserServiceTest"  # 特定クラス
./gradlew koverReport         # カバレッジ (Kover)
```

## Available Commands
- `/commit` - コミットメッセージ生成
- `/code-review` - コードレビュー
- `/implement` - TDD実装ガイド

## Constraints
- 大きな変更は一度に行わない、段階的に進める
- 不明点があれば実装前に確認する
- 既存のコードスタイルを尊重する
- Kotlin の慣用的な書き方を優先する
