# テスト規約 (TypeScript)

## 入力
- TypeScriptのテストファイル (`*.test.ts`, `*.spec.ts`, `*.test.tsx`, `*.spec.tsx`, `tests/**/*`)

## 出力
- 規約に準拠したテストコード

## 規約

- vitest または jest を使用
- Arrange-Act-Assert パターンでテストを構造化
- テスト名は「何を」「どの条件で」「どうなるか」の形式で記述
- モックは最小限に留める
- React コンポーネントのテストは Testing Library を使用

## 手順

1. テストフレームワーク (vitest / jest) を確認する
2. テスト対象の責務を特定する
3. AAA パターンで各テストケースを記述する
   - **Arrange**: テストに必要な状態・データを準備
   - **Act**: テスト対象の処理を実行
   - **Assert**: 期待値と実際の値を検証
4. テスト名を「〇〇が〇〇のとき〇〇すること」の形式で命名する
5. モックが必要な場合は最小限のスコープに絞る

## 使用例

```typescript
// ✅ 良い例
describe('calculateTotal', () => {
  it('割引コードが有効なとき合計金額から10%を引くこと', () => {
    // Arrange
    const items = [{ price: 1000 }];
    const discountCode = 'SAVE10';

    // Act
    const result = calculateTotal(items, discountCode);

    // Assert
    expect(result).toBe(900);
  });
});

// ❌ 悪い例
it('動作する', () => {
  expect(calculateTotal([{ price: 1000 }], 'SAVE10')).toBe(900);
});
```
