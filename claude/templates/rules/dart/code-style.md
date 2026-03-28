# コードスタイル (Dart)

## 目的

Dartコードの命名・フォーマット・言語慣習を統一し、品質を維持する。

## 入力

- 対象: `.dart` ファイル

## 処理手順

1. **命名規則を確認・適用する**
   - 変数・関数: `camelCase`
   - クラス・enum・typedef: `PascalCase`
   - 定数: `lowerCamelCase`（Dart慣習）
   - ファイル名: `snake_case.dart`
   - プライベートメンバー: `_` プレフィックスを付与

2. **フォーマッタを実行する**
   ```bash
   dart format <対象ファイルまたはディレクトリ>
   dart analyze <対象ファイルまたはディレクトリ>
   ```
   - `dart analyze` の警告・エラーをすべて解消する

3. **Dart固有の慣習を適用する**
   - null safety を活用する（`?`, `!`, `late` を適切に使用）
   - 変数はデフォルト `final` を使用し、再代入が必要な場合のみ `var` を使用
   - `const` コンストラクタを可能な限り使用する（Flutterパフォーマンス向上）
   - 不変データクラスは `freezed` パッケージで生成する

## 出力

- フォーマット済み `.dart` ファイル
- `dart analyze` がエラー・警告ゼロの状態

## 使用例

```bash
# ファイル単体
dart format lib/models/user.dart
dart analyze lib/models/user.dart

# プロジェクト全体
dart format lib/
dart analyze lib/
```

## 完了条件

- `dart format` 適用済み
- `dart analyze` がクリーン（エラー・警告なし）
- 命名規則がすべて準拠している
