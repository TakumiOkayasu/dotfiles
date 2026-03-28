# Project Guidelines

## Role Definition
あなたは実装担当のエンジニアです。
相談フェーズは既に完了しており、ここでは決定された方針に基づいて実装を行います。

## Testing

フレームワーク: PHPUnit + CakePHP TestCase

### テストファイル配置
```
tests/
├── bootstrap.php
├── Fixture/           # テストデータ
├── TestCase/
│   ├── Controller/
│   ├── Model/
│   │   └── Table/
│   └── Service/
└── phpunit.xml
```

### テスト実行手順

1. テスト対象ファイルを確認する
2. 以下のコマンドを選択して実行する:

```bash
bin/cake test                                  # 全テスト
bin/cake test --filter UserControllerTest       # 特定テスト（クラス名を指定）
bin/cake test --coverage-html coverage/         # カバレッジレポート生成
```

3. 出力結果を確認する:
   - ✅ `OK (N tests, N assertions)` → 全テスト通過
   - ❌ `FAILURES!` → 失敗内容を確認し修正する
   - ⚠️ `WARNINGS` → 非推奨APIや設定の問題を確認する

### テスト作成手順

1. `tests/TestCase/` 配下に対象クラスと対応するパスでファイルを作成する
   - 例: `src/Service/UserService.php` → `tests/TestCase/Service/UserServiceTest.php`
2. `CakePHP\TestSuite\TestCase` を継承する
3. テストデータが必要な場合は `tests/Fixture/` にフィクスチャを作成する
4. `setUp()` で初期化、`tearDown()` でクリーンアップを記述する
5. テストメソッド名は `test` プレフィックスを付ける（例: `testCreateUser()`）

**入力**: テスト対象クラス名またはメソッド名
**出力**: テスト結果（PASS/FAIL）、カバレッジレポート（`--coverage-html` 指定時）

## Available Commands
- `/commit` - コミットメッセージ生成
- `/code-review` - コードレビュー
- `/implement` - TDD実装ガイド

## Constraints
- 大きな変更は一度に行わない、段階的に進める
- 不明点があれば実装前に確認する
- 既存のコードスタイルを尊重する
- CakePHP の規約を最大限活用する

## 使用例

### 例1: 新規サービスクラスのテスト実行
```bash
# UserService のテストのみ実行
bin/cake test --filter UserServiceTest
```

### 例2: カバレッジ付きで全テスト実行
```bash
bin/cake test --coverage-html coverage/
# → coverage/index.html でカバレッジを確認
```

### 例3: TDD サイクル
1. `tests/TestCase/Service/UserServiceTest.php` に失敗するテストを書く
2. `bin/cake test --filter UserServiceTest` で RED を確認する
3. `src/Service/UserService.php` を実装して GREEN にする
4. リファクタリングして再度テストを実行する
