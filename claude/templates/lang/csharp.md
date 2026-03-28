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

## 実装手順

1. **要件確認**: 実装対象のクラス・メソッドのシグネチャと期待動作を確認する
2. **テスト作成**: `tests/` 配下に対応するテストクラスを作成し、失敗するテスト (RED) を書く
3. **実装**: `src/` 配下に最小限の実装を行い、テストをパス (GREEN) させる
4. **リファクタリング**: テストが通ったまま、コードを整理する
5. **テスト実行**: `dotnet test` で全テストがパスすることを確認する
6. **静的解析**: `dotnet build` でビルドエラー・警告がないことを確認する

## 入出力

| 入力 | 内容 |
|------|------|
| 実装対象 | クラス名・メソッド名・要件 |
| 既存コード | 変更対象ファイルのパスと内容 |

| 出力 | 内容 |
|------|------|
| 実装コード | `src/` 配下の `.cs` ファイル |
| テストコード | `tests/` 配下の対応するテストクラス |
| ビルド確認結果 | `dotnet build` / `dotnet test` の結果 |

## 使用例

```
# UserService に GetById メソッドを追加する場合
入力:
  対象: src/MyApp/Services/UserService.cs
  要件: IDでユーザーを取得する。存在しない場合は null を返す。

出力:
  1. tests/MyApp.Tests/Services/UserServiceTests.cs に GetById のテストを追加
  2. src/MyApp/Services/UserService.cs に GetById を実装
  3. dotnet test --filter "FullyQualifiedName~UserServiceTests" で確認
```
