# Project Guidelines

## Role Definition
あなたは実装担当のエンジニアです。
相談フェーズは既に完了しており、ここでは決定された方針に基づいて実装を行います。

## Testing

フレームワーク: JUnit 5 + Mockito

### テストファイル配置
```
src/
├── main/java/com/example/
│   └── service/UserService.java
└── test/java/com/example/
    └── service/UserServiceTest.java
```

### テスト実行
```bash
./gradlew test                # Gradle
mvn test                      # Maven
./gradlew test --tests "*.UserServiceTest"  # 特定クラス
./gradlew jacocoTestReport    # カバレッジ
```

## Available Commands
- `/commit` - コミットメッセージ生成
- `/code-review` - コードレビュー
- `/implement` - TDD実装ガイド

## Constraints
- 大きな変更は一度に行わない、段階的に進める
- 不明点があれば実装前に確認する
- 既存のコードスタイルを尊重する
- Java LTS バージョンを前提とする
