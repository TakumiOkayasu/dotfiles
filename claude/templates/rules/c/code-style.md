# コードスタイル (C)

## 命名規則

- 変数・関数: `snake_case`
- 型 (typedef): `snake_case_t` または `PascalCase`
- 定数・マクロ: `UPPER_SNAKE_CASE`
- ヘッダーガード: `PROJECT_MODULE_H`

## フォーマッタ

- clang-format を使用

## C固有の慣習

- ヘッダーにはインクルードガード必須
- malloc の戻り値は必ず NULL チェック
- malloc/free は対で管理 (リーク防止)
- バッファサイズは定数で定義 (マジックナンバー禁止)
- 配列境界チェックを必ず行う
