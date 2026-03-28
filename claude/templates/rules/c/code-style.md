# コードスタイル (C)

## 目的

C言語コードのスタイル規則を定義し、AIが一貫したコードを生成・レビューできるようにする。

## 入力

- Cソースファイル (`.c`) またはヘッダーファイル (`.h`)
- レビュー対象のコードスニペット

## 出力

- スタイル規則に準拠したコード
- 違反箇所の指摘と修正案

## 処理手順

1. **命名規則を確認・適用する**
   - 変数・関数: `snake_case`
   - 型 (typedef): `snake_case_t` または `PascalCase`
   - 定数・マクロ: `UPPER_SNAKE_CASE`
   - ヘッダーガード: `PROJECT_MODULE_H`

2. **フォーマットを適用する**
   - clang-format に準拠したインデント・スペース配置を使用する
   - [要確認] clang-format の設定ファイル (`.clang-format`) が存在する場合はその設定を優先する

3. **C固有の安全規則を遵守する**
   - ヘッダーファイルにはインクルードガードを必ず記述する
   - `malloc` の戻り値は必ず `NULL` チェックを行う
   - `malloc` と `free` は対で管理し、メモリリークを防止する
   - バッファサイズは定数または `#define` で定義し、マジックナンバーを禁止する
   - 配列アクセス前に必ず境界チェックを行う

4. **違反を検出した場合**
   - 違反箇所をファイル名・行番号とともに列挙する
   - 修正前・修正後のコードを併記する

## 使用例

```
# ヘッダーガードの正しい形式
#ifndef PROJECT_MODULE_H
#define PROJECT_MODULE_H
// ...
#endif /* PROJECT_MODULE_H */

# mallocのNULLチェック
void *ptr = malloc(sizeof(int) * count);
if (ptr == NULL) {
    return ERROR_OUT_OF_MEMORY;
}

# バッファサイズ定数化
#define MAX_BUFFER_SIZE 256
char buf[MAX_BUFFER_SIZE];
```
