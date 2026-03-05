# コードスタイル (TypeScript)

## 命名規則

- 変数・関数: `camelCase`
- クラス・型・インターフェース: `PascalCase`
- 定数: `UPPER_SNAKE_CASE`
- ファイル名: `kebab-case.ts` または `PascalCase.tsx`

## フォーマッタ

- prettier でコード整形
- eslint でリンティング

## 型安全

- `strict: true` を推奨
- `any` は極力避ける
- `unknown` + 型ガードを活用
