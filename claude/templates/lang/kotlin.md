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

## 処理手順

1. **要件確認**: 実装対象の仕様・インターフェースを確認する
2. **テスト作成**: 対象クラスのテストファイルを `test/kotlin/` 配下に作成する
3. **実装**: `main/kotlin/` 配下に実装ファイルを作成・編集する
4. **テスト実行**: `./gradlew test` でテストがパスすることを確認する
5. **スタイル確認**: Kotlin 慣用的な書き方に沿っているか確認する
6. **段階的コミット**: 論理的な単位で変更をコミットする

## 入出力

| 項目 | 内容 |
|------|------|
| 入力 | 実装対象の仕様・要件、既存コードのコンテキスト |
| 出力 | Kotlin 実装ファイル、対応するテストファイル |

## 使用例

```
ユーザー: UserService に findByEmail メソッドを追加してください。
→ 1. UserServiceTest に findByEmail のテストを追加
→ 2. UserService に実装を追加
→ 3. ./gradlew test で確認
→ 4. /commit でコミットメッセージ生成
```

## Constraints
- 大きな変更は一度に行わない、段階的に進める
- 不明点があれば実装前に確認する
- 既存のコードスタイルを尊重する
- Kotlin の慣用的な書き方を優先する
