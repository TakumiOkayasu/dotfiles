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

## 処理手順

1. 要件・仕様を確認する（不明点は実装前に質問する）
2. テストファイルを先に作成する（TDD: Red→Green→Refactor）
3. 最小限の実装でテストをパスさせる
4. リファクタリングしてコードを整理する
5. `./gradlew test` または `mvn test` でテストが全件パスすることを確認する

## 入出力

| 項目 | 内容 |
|------|------|
| 入力 | 実装対象の要件・仕様、既存コードのコンテキスト |
| 出力 | Javaソースコード（`src/main/`）、対応するテストコード（`src/test/`） |

## 使用例

```
# 新しいサービスクラスを実装する場合
1. UserServiceTest.java を作成 → 失敗するテストを書く
2. UserService.java を作成 → テストをパスする最小実装
3. ./gradlew test で確認
4. リファクタリング → 再度テスト確認
```
