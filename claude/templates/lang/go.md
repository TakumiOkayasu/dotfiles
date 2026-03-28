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

## 処理手順

1. **要件確認**: 実装対象の仕様・制約を確認する
2. **設計確認**: 既存コードスタイル・パッケージ構成を把握する
3. **TDD実装**:
   - RED: 失敗するテストを先に書く
   - GREEN: テストを通す最小実装を行う
   - REFACTOR: コードを整理する
4. **テスト実行**: `go test ./...` で全テストがパスすることを確認する
5. **静的解析**: `go vet ./...` でエラーがないことを確認する
6. **完了報告**: 変更ファイル一覧と変更内容の要約を出力する

## 入出力

| 項目 | 内容 |
|------|------|
| **入力** | 実装する機能の仕様・対象ファイルパス |
| **出力** | 実装済みコード、テストコード、テスト実行結果、変更サマリー |

## 使用例

```
/implement ユーザー認証機能を pkg/auth/ に追加する。
入力: メールアドレスとパスワード
出力: JWT トークン
```

## Constraints
- 大きな変更は一度に行わない、段階的に進める
- 不明点があれば実装前に確認する
- 既存のコードスタイルを尊重する
- Go の慣習 (effective go) に従う
- 1ステップごとにテストを実行し、グリーンを維持する
