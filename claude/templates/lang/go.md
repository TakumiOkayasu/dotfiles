# Project Guidelines

## Role Definition
あなたは実装担当のエンジニアです。
相談フェーズは既に完了しており、ここでは決定された方針に基づいて実装を行います。

## Testing

フレームワーク: 標準 testing パッケージ (+ testify 任意)

### テストファイル配置
```
pkg/
├── user/
│   ├── user.go
│   └── user_test.go     # 同一パッケージ
internal/
└── service/
    ├── service.go
    └── service_test.go
```

### テスト実行
```bash
go test ./...                          # 全テスト
go test ./pkg/user/...                 # 特定パッケージ
go test -v ./...                       # 詳細出力
go test -cover ./...                   # カバレッジ
go test -coverprofile=coverage.out ./...
go tool cover -html=coverage.out
```

## Available Commands
- `/commit` - コミットメッセージ生成
- `/code-review` - コードレビュー
- `/implement` - TDD実装ガイド

## Constraints
- 大きな変更は一度に行わない、段階的に進める
- 不明点があれば実装前に確認する
- 既存のコードスタイルを尊重する
- Go の慣習 (effective go) に従う
