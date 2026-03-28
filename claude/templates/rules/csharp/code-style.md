# コードスタイル (C#)

## 目的

C# コードの命名・フォーマット・言語機能使用に関するスタイル規約を定義する。

## 入力

- C# ソースコード (.cs ファイル)
- `.editorconfig`（プロジェクト共有設定）

## 出力

- 規約に準拠したコード
- `dotnet format` 適用済みのファイル

## 処理手順

1. **命名規則を適用する**
   - 変数・パラメータ → `camelCase`
   - メソッド・プロパティ・クラス → `PascalCase`
   - 定数 → `PascalCase`（C# 慣習）
   - プライベートフィールド → `_camelCase`
   - インターフェース → `IPascalCase`（`I` プレフィックス必須）

2. **フォーマッタを実行する**
   ```bash
   dotnet format
   ```
   - `.editorconfig` の設定に従い自動整形する
   - CI/CD パイプラインでも実行すること

3. **C# 固有の言語機能を正しく使用する**
   - nullable 参照型を有効化する
     ```xml
     <Nullable>enable</Nullable>
     ```
   - `async/await` パターンを使用する（`async void` は**禁止**、`async Task` を使用）
   - パターンマッチングを活用する（`is` 式、`switch` 式）
   - 不変データには `record` 型を使用する

4. **違反箇所を修正する**
   - `dotnet format --verify-no-changes` でチェックのみ実行可能
   - 違反があれば手動修正後、再度 `dotnet format` を実行する

## 使用例

```csharp
// ✅ 正しい例
public interface IUserRepository { }
public class UserService
{
    private readonly IUserRepository _repository;

    public async Task<User?> GetUserAsync(int userId)
    {
        return await _repository.FindAsync(userId);
    }
}

public record UserDto(int Id, string Name);

// ❌ 禁止例
public async void LoadData() { }  // async void 禁止
private IUserRepository Repository; // フィールドは _camelCase
```

## 禁止事項

| 禁止 | 理由 |
|------|------|
| `async void` | 例外がキャッチできない |
| nullable 無効のまま運用 | null 安全性が保証されない |
| フォーマッタ未適用のコミット | コードスタイル不統一 |
