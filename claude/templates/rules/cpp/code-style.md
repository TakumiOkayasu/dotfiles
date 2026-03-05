# コードスタイル (C++)

## 命名規則

- 変数・関数: `snake_case`
- クラス・構造体: `PascalCase`
- 定数・マクロ: `UPPER_SNAKE_CASE`
- メンバ変数: `snake_case_` (末尾アンダースコア)
- 名前空間: `lowercase`

## C++バージョン

- C++17 以上を推奨
- モダンC++機能を活用

## メモリ管理

- RAII パターンを遵守
- スマートポインタを使用 (`unique_ptr`, `shared_ptr`)
- 生ポインタは観測用途のみ
- `new`/`delete` の直接使用禁止 (`make_unique`/`make_shared` を使用)

## 安全性

- 未定義動作を避ける (ダングリングポインタ, バッファオーバーフロー)
- const correctness を徹底 (変更しないものは `const`)
- `nullptr` を使用 (`NULL`/`0` 禁止)
