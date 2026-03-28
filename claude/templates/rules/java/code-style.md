# テスト規約 (Java)

## 適用条件

以下のファイルを作成・編集する場合に本規約を適用する:

- `src/test/**/*`
- `**/*Test.java`
- `**/*Tests.java`

---

## フレームワーク

| 用途 | ライブラリ |
|------|-----------|
| テストランナー | JUnit 5 (`@Test`, `@BeforeEach` 等) |
| モック | Mockito (`@Mock`, `@InjectMocks`) |

---

## 実装手順

### 1. テストクラス構造

```java
class UserServiceTest {

    @Nested
    class グループ名 {
        // 関連テストをまとめる
    }
}
```

- テストクラスは `@Nested` でグルーピングする
- グループ名はテスト対象の状態・条件を表す日本語または英語

### 2. テストメソッド命名

形式: `何を_どの条件で_どうなるか`

```java
@Test
void save_有効なユーザー_保存成功() { }

@Test
void save_メールアドレスが空_例外をスロー() { }
```

### 3. AAA パターン

```java
@Test
void メソッド名() {
    // Arrange: 前提条件・テストデータを準備
    var user = new User("alice@example.com");

    // Act: テスト対象を実行
    var result = userService.save(user);

    // Assert: 結果を検証
    assertThat(result.getId()).isNotNull();
}
```

- 各セクションを空行で区切る
- コメント (`// Arrange` 等) は省略可だが、セクション構造は維持する

### 4. モック使用ルール

- モックは **外部依存 (DB, API, ファイル) のみ** に使用する
- 内部クラスのモックは原則禁止
- 検証は `verify()` を最小限に留める（振る舞いではなく結果を検証する）

```java
// ✅ 外部依存のみモック
@Mock
private UserRepository repository;

// ❌ 内部ロジックをモック化しない
```

---

## 入出力

| 項目 | 内容 |
|------|------|
| 入力 | テスト対象クラス・メソッド、テストデータ |
| 出力 | `*Test.java` ファイル (src/test 配下) |

---

## 禁止事項

- `Thread.sleep()` によるタイミング制御
- テスト間の状態共有 (static フィールドへの書き込み)
- 本番コードへのテスト用分岐追加
