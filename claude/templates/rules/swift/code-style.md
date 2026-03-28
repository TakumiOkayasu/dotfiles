# コードスタイル (Swift)

## トリガー条件

Swiftコードのスタイル・命名規則・フォーマットに関する質問・レビュー・実装時に参照する。

## 処理手順

1. 命名規則セクションを参照し、対象識別子の種類を判定する
2. 該当する命名規則を適用する
3. Swift固有の慣習セクションを参照し、コードパターンを確認する
4. フォーマッタセクションを参照し、自動整形対象を特定する

## 命名規則

| 対象 | 規則 | 例 |
|------|------|----|
| 変数・関数 | `camelCase` | `userName`, `fetchData()` |
| 型・プロトコル | `PascalCase` | `UserProfile`, `Fetchable` |
| 定数 | `camelCase` | `maxRetryCount` |
| 列挙値 | `camelCase` | `.notFound`, `.success` |

## フォーマッタ

- SwiftFormat または swift-format を使用
- SwiftLint でリンティング

**実行例:**
```bash
swiftformat .
swiftlint lint --path Sources/
```

## Swift固有の慣習

| パターン | 方針 | 理由 |
|----------|------|------|
| 早期リターン | `guard` を使用 | ネストを減らし可読性向上 |
| Optional展開 | `if let` / `guard let` を使用 | `!` (force unwrap) は原則禁止 |
| 値型 vs 参照型 | `struct` をデフォルト | `class` は参照セマンティクスが必要な場合のみ |
| 設計パターン | Protocol-Oriented Programming を活用 | — |

**force unwrap禁止の例外:** テストコード・`IBOutlet`等で意図が明確な場合は `[要確認]` として都度判断する。

## 入力

- レビュー対象のSwiftコード、または命名・実装パターンの相談内容

## 出力

- 規則に準拠した命名・コードパターンの提案
- 違反箇所の指摘と修正案
