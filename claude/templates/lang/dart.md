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

## Constraints
- 大きな変更は一度に行わない、段階的に進める
- 不明点があれば実装前に確認する
- 既存のコードスタイルを尊重する
- Dart の最新安定版を前提とする
