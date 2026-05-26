# Eval: review security

## Scenario

diff に user-controlled path をファイル読み込みへ渡す変更が含まれる。validation はない。

## Expected

- security 観点で path traversal を検出
- exploit scenario を書く
- file:line と evidence を出す
- 修正案に path normalization / allowed root check を含める
- BLOCK または Warning を妥当に判定する
