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

## Available Commands
- `/commit` - コミットメッセージ生成
- `/code-review` - コードレビュー
- `/implement` - TDD実装ガイド

## Constraints
- 大きな変更は一度に行わない、段階的に進める
- 不明点があれば実装前に確認する
- 既存のコードスタイルを尊重する
- Node.js LTS バージョンを前提とする
