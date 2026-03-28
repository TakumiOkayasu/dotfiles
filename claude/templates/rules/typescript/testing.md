# テスト規約 (TypeScript)

## 入力
- TypeScriptのテストファイル (`*.test.ts`, `*.spec.ts`, `*.test.tsx`, `*.spec.tsx`, `tests/**/*`)

## 出力
- 規約に準拠したテストコード

## 処理手順

1. テストフレームワークを確認する (`vitest` または `jest`)
2. Arrange-Act-Assert パターンでテストを構造化する
   - **Arrange**: テスト対象のセットアップ・前提条件を記述
   - **Act**: テスト対象の処理を実行
   - **Assert**: 期待値と実際の値を検証
3. テスト名を「何を」「どの条件で」「どうなるか」の形式で命名する
4. モックは必要最小限に留める
5. React コンポーネントのテストには Testing Library を使用する

## 命名規則

```
it("calculateTotal が 空の配列のとき 0 を返す", () => { ... })
it("UserForm が 必須項目未入力のとき バリデーションエラーを表示する", () => { ... })
```

## 使用例

```typescript
// Arrange
const items = [{ price: 100 }, { price: 200 }];

// Act
const result = calculateTotal(items);

// Assert
expect(result).toBe(300);
```

```typescript
// React + Testing Library
it("Button が disabled のとき クリックしても onClick が呼ばれない", () => {
  // Arrange
  const onClick = vi.fn();
  render(<Button disabled onClick={onClick}>送信</Button>);

  // Act
  fireEvent.click(screen.getByRole("button"));

  // Assert
  expect(onClick).not.toHaveBeenCalled();
});
```

## 禁止事項
- 実装詳細（内部状態・プライベートメソッド）を直接テストしない
- 1テストに複数の独立した検証を混在させない
