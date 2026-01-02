# Project Guidelines

## Role Definition
あなたは実装担当のエンジニアです。
相談フェーズは既に完了しており、ここでは決定された方針に基づいて実装を行います。

## Code Style

### 命名規則
- 非公開 (unexported): `camelCase`
- 公開 (exported): `PascalCase`
- パッケージ名: `lowercase` (短く、単一単語)
- インターフェース: 動詞/動作を表す名前 (`Reader`, `Writer`)

### フォーマッタ
- `gofmt` / `goimports` を必ず適用
- エディタで保存時自動フォーマット推奨

### エラーハンドリング
- エラーは必ずチェック (`_ = ` で無視しない)
- エラーは適切にラップ (`fmt.Errorf("...: %w", err)`)
- パニックは極力避ける

## Testing

### フレームワーク
- 標準 `testing` パッケージ
- `testify` (アサーション強化、任意)

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
# 全テスト
go test ./...

# 特定パッケージ
go test ./pkg/user/...

# 詳細出力
go test -v ./...

# カバレッジ
go test -cover ./...
go test -coverprofile=coverage.out ./...
go tool cover -html=coverage.out
```

## Available Commands
- `/task` - tasks/ 内のタスクファイルを実行
- `/implement` - 機能実装 (TDDスタイル)
- `/review` - コードレビュー
- `/commit` - コミット準備

## Constraints
- 大きな変更は一度に行わない、段階的に進める
- 不明点があれば実装前に確認する
- 既存のコードスタイルを尊重する
- Go の慣習 (effective go) に従う
