# コードスタイル (C++)

## 概要

C++コードを記述・レビューする際に適用するスタイルガイド。
このファイルに定義されたルールに従ってコードを生成・修正すること。

## 入力

- C++ソースコード（新規作成 or 既存コードの修正依頼）

## 出力

- スタイルガイドに準拠したC++コード

## 処理手順

1. **命名規則を確認・適用する**
   - 変数・関数 → `snake_case`
   - クラス・構造体 → `PascalCase`
   - 定数・マクロ → `UPPER_SNAKE_CASE`
   - メンバ変数 → `snake_case_`（末尾アンダースコア必須）
   - 名前空間 → `lowercase`

2. **C++バージョンを確認する**
   - C++17以上を前提とする
   - `if constexpr`・構造化束縛・`std::optional` 等のモダン機能を積極的に使用する

3. **メモリ管理を確認・修正する**
   - `new`/`delete` の直接使用を禁止。`make_unique`/`make_shared` に置換する
   - 生ポインタは観測用途（所有権なし）のみ許可する
   - RAIIパターンを徹底する（リソース取得と解放をオブジェクトのライフサイクルに紐付ける）

4. **安全性を確認・修正する**
   - `NULL`/`0` を `nullptr` に置換する
   - 変更しない変数・引数・メソッドには `const` を付与する
   - ダングリングポインタ・バッファオーバーフロー等の未定義動作を排除する

## 使用例

**修正前:**
```cpp
class myClass {
public:
    int* getData() { return data; }
private:
    int* data;
};

myClass* obj = new myClass();
```

**修正後:**
```cpp
class MyClass {
public:
    const int* getData() const { return data_.get(); }
private:
    std::unique_ptr<int[]> data_;
};

auto obj = std::make_unique<MyClass>();
```

## 禁止事項

| 禁止 | 代替 |
|------|------|
| `new`/`delete` | `make_unique`/`make_shared` |
| `NULL` / `0`（ポインタ） | `nullptr` |
| 生ポインタによる所有権管理 | スマートポインタ |
| `const` なし（変更不要な箇所） | `const` を付与 |
