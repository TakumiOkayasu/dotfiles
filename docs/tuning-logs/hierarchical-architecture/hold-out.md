# hold-out: 単一 CLI (100行) への過剰発動回避

## 評価軸

| 項目 | 値 |
|---|---|
| [critical] 全 ○ | ○ (1,2) |
| 精度 | 100 (5/5) |
| tool_uses | 2 |
| duration_ms | 39,189 |
| 再試行 | 0 |
| 判定 | ○ |

## 成果物サマリ

- 関数分割のみ (main / parse_args / load_csv / transform / save_csv)、`*Manager`/`*Provider`/`*Accessor` クラス階層を**導入せず**
- `argparse.Namespace` を直接使用、Intent 変換層を導入せず
- 将来「再利用要求」「複数ソース」「Web API 化」等のトリガーごとに段階的に操作層→提供層→管理層へ切り出す YAGNI 方針を提示
- 「横参照禁止」等はクラス階層前提の原則で、関数のみのスクリプトでは対象外と明示

## 要件達成詳細

全 5 項目 ○。iter 2 追加節 (L13 / L117) による overfit なし、規模感の判断は適切。

## 収束判定

- iter 1: 3/3 ○
- iter 2: 3/3 ○ (連続 2/2)
- hold-out: 5/5 ○
- **rule 2 (hierarchical-architecture) 収束完了** ✅
