# コードスタイル (Java)

## 概要

Javaコードのスタイルルールを定義するリファレンスコマンド。コードレビュー・実装時に参照する。

## 入力

- レビュー対象のJavaコード（任意）

## 出力

- スタイルルールに準拠したJavaコード

## 処理手順

1. 命名規則を確認し、違反箇所を特定する
2. フォーマッタを適用してコードを整形する
3. Java固有の慣習に沿っているか検証する
4. 問題があれば修正し、問題なければそのまま返す

## 命名規則

| 対象 | 規則 | 例 |
|------|------|----|
| 変数・メソッド | `camelCase` | `userName`, `getUserName()` |
| クラス・インターフェース | `PascalCase` | `UserService`, `Readable` |
| 定数 | `UPPER_SNAKE_CASE` | `MAX_RETRY_COUNT` |
| パッケージ | `lowercase`（ドット区切り） | `com.example.service` |

## フォーマッタ

- **Google Java Format** または **Spotless** を使用して自動整形する
- **Checkstyle** でスタイルチェックを実行する

```bash
# Spotless適用例
./gradlew spotlessApply

# Checkstyle実行例
./gradlew checkstyleMain
```

## Java固有の慣習

- `Optional` は戻り値にのみ使用する（フィールド・引数への使用は禁止）
- Stream API は可読性を損なわない範囲で活用する（複雑になる場合はforループを優先）
- 不変データには `record` クラスを使用する（Java 16以上）

## 使用例

```java
// ✅ 正しい例
public record UserProfile(String userName, int age) {}

public Optional<UserProfile> findUser(String id) {
    return users.stream()
        .filter(u -> u.userName().equals(id))
        .findFirst();
}

// ❌ 誤った例
private Optional<String> name; // フィールドへのOptional使用は禁止
public void process(Optional<String> input) {} // 引数へのOptional使用は禁止
```

## 禁止事項

- フィールドや引数への `Optional` の使用
- 可読性を著しく低下させる複雑なStream APIのチェーン
- 命名規則に違反した識別子の使用
