# テスト規約 (Dart)

## 入力

- `test/**/*` または `**/*_test.dart` に該当するファイル

## 出力

- 規約に準拠したDartテストコード

## 処理手順

1. テストフレームワークを選択する
   - 通常のDartコード → `dart test`
   - Flutterウィジェット → `flutter_test`
2. テスト構造を `group` / `test` で階層化する
3. テスト名を「何を」「どの条件で」「どうなるか」の形式で命名する
4. 各テストをArrange-Act-Assertパターンで実装する
   - Arrange: テスト対象の初期化・前提条件の設定
   - Act: テスト対象の処理を実行
   - Assert: 期待結果を検証
5. Widgetテストの場合は `testWidgets` + `WidgetTester` を使用する

## 使用例

```dart
group('MyWidget', () {
  testWidgets('タップ時にカウンターが増加する', (WidgetTester tester) async {
    // Arrange
    await tester.pumpWidget(const MyWidget());

    // Act
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    // Assert
    expect(find.text('1'), findsOneWidget);
  });
});

group('Calculator', () {
  test('正の整数2つを加算すると合計を返す', () {
    // Arrange
    final calc = Calculator();

    // Act
    final result = calc.add(2, 3);

    // Assert
    expect(result, equals(5));
  });
});
```
