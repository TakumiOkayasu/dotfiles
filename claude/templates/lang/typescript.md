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

## 処理手順

1. **要件確認**: 実装対象の機能・変更範囲を明確にする
2. **既存コード調査**: 関連ファイル・コードスタイル・型定義を確認する
3. **テスト作成** (RED): 期待する動作を定義するテストを先に書く
4. **実装** (GREEN): テストが通る最小限のコードを書く
5. **リファクタリング** (REFACTOR): コード品質を保ちながら整理する
6. **動作確認**: `npm test` で全テストがパスすることを確認する
7. **型チェック**: `npx tsc --noEmit` でコンパイルエラーがないことを確認する

## 入出力

| 項目 | 内容 |
|------|------|
| 入力 | 実装する機能の仕様・変更内容の説明 |
| 出力 | TypeScriptソースファイル + テストファイル |

## 使用例

```
# 新規コンポーネント実装
「ユーザーアイコンを表示する Avatar コンポーネントを実装してください。
  props: src(string), alt(string), size(sm/md/lg)」

# 既存機能の修正
「useFetch フックで、エラー時に retryCount 回まで自動リトライする機能を追加してください」
```
