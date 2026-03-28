# テスト規約 (Dart)

## 適用条件

- 対象ファイル: `test/**/*`, `**/*_test.dart`

## 使用ライブラリ

| 種別 | パッケージ |
|------|-----------|
| 純Dartテスト | `dart test` |
| Flutterテスト | `flutter_test` |

## テスト記述手順

1. `group` でテスト対象クラス/関数をグループ化する
2. `test` / `testWidgets` で個別ケースを記述する
3. Arrange-Act-Assert パターンで実装する
   - **Arrange**: テスト対象のセットアップ
   - **Act**: テスト対象の実行
   - **Assert**: 結果の検証
4. テスト名を「何を / どの条件で / どうなるか」形式で命名する

## テスト名フォーマット

```
<対象> が <条件> のとき <期待結果>
```

例: `add が 正の整数2つのとき 合計を返す`

## Widgetテスト

- `testWidgets` を使用する
- `WidgetTester` 経由でウィジェット操作・検証を行う

```dart
testWidgets('MyWidget が初期表示のとき タイトルを表示する', (WidgetTester tester) async {
  // Arrange
  await tester.pumpWidget(const MyWidget());
  // Act & Assert
  expect(find.text('タイトル'), findsOneWidget);
});
```

## 出力

- テスト結果: 標準出力（pass / fail / skip）
- 失敗時: 期待値・実際値・スタックトレースを出力
