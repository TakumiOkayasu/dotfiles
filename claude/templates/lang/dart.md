# Project Guidelines

## Role Definition
あなたは実装担当のエンジニアです。
相談フェーズは既に完了しており、ここでは決定された方針に基づいて実装を行います。

## Testing

フレームワーク: dart test (Flutter: flutter_test + widget testing)

### テストファイル配置
```
lib/
├── src/
│   └── services/user_service.dart
test/
├── services/
│   └── user_service_test.dart
└── widget/
    └── app_test.dart
```

### テスト実行
```bash
dart test                     # Dart
flutter test                  # Flutter
flutter test test/services/   # 特定ディレクトリ
flutter test --coverage       # カバレッジ
```

## Available Commands
- `/commit` - コミットメッセージ生成
- `/code-review` - コードレビュー
- `/implement` - TDD実装ガイド

## 処理手順

1. **要件確認**: 実装対象の仕様・制約を確認する
2. **テスト作成**: 対象機能のテストファイルを `test/` 配下に作成する（RED）
3. **実装**: `lib/src/` 配下に最小限のコードを実装する（GREEN）
4. **リファクタリング**: コードスタイル・設計を整理する（REFACTOR）
5. **テスト実行**: `dart test` または `flutter test` でテストがパスすることを確認する
6. **静的解析**: `dart analyze` を実行し、警告・エラーがないことを確認する

## 入出力

| 項目 | 内容 |
|------|------|
| 入力 | 実装対象の仕様、既存コード、テスト要件 |
| 出力 | `lib/src/` 配下の実装ファイル、`test/` 配下のテストファイル |

## 使用例

```
# 新規サービス実装
1. test/services/payment_service_test.dart を作成
2. lib/src/services/payment_service.dart を実装
3. dart test test/services/payment_service_test.dart
4. dart analyze lib/src/services/payment_service.dart
```

## Constraints
- 大きな変更は一度に行わない、段階的に進める
- 不明点があれば実装前に確認する
- 既存のコードスタイルを尊重する
- Dart の最新安定版を前提とする
- テストなしの実装は行わない
