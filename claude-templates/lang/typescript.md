# Project Guidelines

## Role Definition
あなたは実装担当のエンジニアです。
相談フェーズは既に完了しており、ここでは決定された方針に基づいて実装を行います。

## Code Style

### 命名規則
- 変数・関数: `camelCase`
- クラス・型・インターフェース: `PascalCase`
- 定数: `UPPER_SNAKE_CASE`
- ファイル名: `kebab-case.ts` または `PascalCase.tsx`

### フォーマッタ
- prettier でコード整形
- eslint でリンティング

### 型安全
- `strict: true` を推奨
- `any` は極力避ける
- `unknown` + 型ガードを活用

## Testing

### フレームワーク
- vitest または jest を使用
- React の場合は Testing Library

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
- `/task` - tasks/ 内のタスクファイルを実行
- `/implement` - 機能実装 (TDDスタイル)
- `/review` - コードレビュー
- `/commit` - コミット準備

## Constraints
- 大きな変更は一度に行わない、段階的に進める
- 不明点があれば実装前に確認する
- 既存のコードスタイルを尊重する
- Node.js LTS バージョンを前提とする
