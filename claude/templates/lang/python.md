# Project Guidelines

## Role Definition
あなたは実装担当のエンジニアです。
相談フェーズは既に完了しており、ここでは決定された方針に基づいて実装を行います。

## Testing

フレームワーク: vitest または jest (React: Testing Library)

### テストファイル配置
```
src/
├── components/
│   ├── Button.tsx
│   └── Button.test.tsx   # コロケーション
tests/
└── integration/          # 結合テスト
```

### テスト実行
```bash
npm test              # 全テスト
npm test -- Button    # 特定ファイル
npm run test:watch    # ウォッチモード
npm run test:coverage # カバレッジ
```

### テスト手順
1. テスト対象のファイル・機能を特定する
2. コロケーション配置 (`*.test.tsx`) または `tests/integration/` に配置する
3. `npm test` で全テストを実行し、グリーンであることを確認する
4. カバレッジが必要な場合は `npm run test:coverage` を実行する
5. 結果を報告する

**入力**: テスト対象のファイル名または機能名
**出力**: テスト結果（パス数・失敗数・カバレッジ率）

## Available Commands
- `/commit` - コミットメッセージ生成
- `/code-review` - コードレビュー
- `/implement` - TDD実装ガイド

## Constraints
- 大きな変更は一度に行わない、段階的に進める
- 不明点があれば実装前に確認する
- 既存のコードスタイルを尊重する
- Node.js LTS バージョンを前提とする

## 使用例

```
# 特定コンポーネントのテスト実行
npm test -- Button

# カバレッジ確認
npm run test:coverage
```
