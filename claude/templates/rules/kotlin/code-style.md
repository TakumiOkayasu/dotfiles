# コードスタイル (Kotlin)

## 概要

Kotlinコードのスタイルガイド。命名規則・フォーマット・言語固有の慣習を定める。

## 入力

- Kotlinソースコード (.kt, .kts)

## 出力

- スタイル準拠のKotlinコード

## 命名規則

| 対象 | スタイル | 例 |
|------|---------|-----|
| 変数・関数 | `camelCase` | `userName`, `fetchData()` |
| クラス・インターフェース | `PascalCase` | `UserRepository`, `Clickable` |
| 定数 | `UPPER_SNAKE_CASE` | `MAX_RETRY_COUNT` |
| パッケージ | `lowercase` (ドット区切り) | `com.example.app` |

## フォーマッタ

- ktlint または detekt を使用
- CIで自動チェックを実施すること

## 処理手順

1. 命名規則を上記テーブルに従い確認・修正する
2. フォーマッタ (ktlint / detekt) を実行し警告をゼロにする
3. 以下のKotlin固有慣習チェックリストを適用する

## Kotlin固有の慣習

### null安全

- `!!` は原則禁止
- 代わりに `?.`, `?:`, `let` を使用する

```kotlin
// ❌ 禁止
val name = user!!.name

// ✅ 推奨
val name = user?.name ?: "Unknown"
user?.let { doSomething(it.name) }
```

### data class

- 値オブジェクトには `data class` を使用する

```kotlin
// ✅ 推奨
data class UserId(val value: String)
```

### スコープ関数

| 関数 | 用途 |
|------|------|
| `let` | null チェック後の処理、一時変数のスコープ限定 |
| `run` | オブジェクト設定 + 結果返却 |
| `apply` | オブジェクト設定のみ (レシーバー返却) |
| `also` | ログ・デバッグなど副作用 |
| `with` | 同一オブジェクトへの複数操作 |

### 拡張関数

- 既存クラスに自然に馴染む操作のみに使用する
- 乱用しない（汎用的すぎる拡張はユーティリティクラスに移す）

## チェックリスト

- [ ] 命名規則に違反していない
- [ ] `!!` を使用していない
- [ ] スコープ関数の使い分けが適切
- [ ] フォーマッタがエラーなし
