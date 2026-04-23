# Trigger 重なり語表

全11スキルの `description`（frontmatter）から **複数スキルに登場する語** を抽出。各スキル iter 0 の「直前スキルとの重なり語チェック」の補助データとして使用する。

## 抽出元

`claude/skills/<name>/SKILL.md` の frontmatter `description:` フィールドのみ（body は対象外）。

## 重なり語一覧

| 語 | 登場スキル | 危険度 | 境界の整理方針 |
|---|---|:---:|---|
| **テスト** | tdd / test-coverage-guard / e2e-browser / qa-nightmare / systematic-debugging | 🔴 高 | tdd=作成、test-coverage-guard=GREEN後検証、e2e-browser=ブラウザ実行基盤、qa-nightmare=悪夢ケース生成、systematic-debugging=テスト失敗の診断。**各 description に「この skill がカバーしない隣接領域」を明示する候補** |
| **実装** | consultation / interface-first-design / tdd | 🟡 中 | consultation=判断相談、iface-first=設計→実装接続、tdd=テスト駆動実装 |
| **設計** | consultation / interface-first-design | 🟡 中 | consultation=技術選定・判断相談、iface-first=interface/クラス設計（実装直前） |
| **機能** | interface-first-design / tdd | 🟡 中 | iface-first=機能追加の設計段階、tdd=機能実装の RED-GREEN-REFACTOR |
| **修正 / バグ** | systematic-debugging / tdd | 🟡 中 | systematic-debugging=原因分析、tdd=修正実装（境界はある程度明確） |
| **失敗** | failure-logging / systematic-debugging | 🟢 低 | failure-logging=記録、systematic-debugging=分析 |
| **改善** | refactoring / empirical-prompt-tuning | 🟢 低 | refactoring=コード構造改善、empirical=プロンプト改善。対象ドメインが別 |
| **構造** | refactoring / consultation | 🟢 低 | refactoring=コード構造、consultation=問題構造化（異義） |

## 🔴 高リスク: 「テスト」の扱い

**subagent 視点で「テストを書いて」と言われたときに迷う最大の要因。**

現状 description からは以下の判別が困難:

| シナリオ | 選ぶべき skill | 現 description からの読み取りやすさ |
|---|---|:---:|
| 新機能のユニットテストを RED から書く | tdd | ○ |
| 既存の GREEN テストが本当にバグを検出できるか確認したい | test-coverage-guard | △（「信頼性を検証」は分かるが他と被る） |
| ブラウザで DB 更新まで含めて動作確認したい | e2e-browser | ○（E2E が明確） |
| このフォームの QA が嫌がりそうな edge を列挙したい | qa-nightmare | ○（悪夢ケースが明確） |
| テストが落ちた原因を知りたい | systematic-debugging | △（「テスト失敗に遭遇」は分かるが tdd と被る） |

**推奨アクション（各スキル iter 0 の整合チェック時）**:
- test-coverage-guard: description に「tdd がテスト作成、本 skill は作成済テストの検証」を明示
- systematic-debugging: description に「tdd が修正実装、本 skill は修正**前**の原因分析」を明示
- tdd: description に「既存テストの検証は test-coverage-guard」の一言を足す候補

## 🟡 中リスク: 「実装 / 設計 / 機能」

consultation / interface-first-design / tdd の **phase** 関係で整理できる:

```
consultation（迷い/相談）  →  interface-first-design（設計）  →  tdd（テスト駆動実装）
```

各 description に phase 位置を明示する余地あり。interface-first-design には既に「TDDスキルの前段」の記載があり好例。

## 🟢 低リスク: 「失敗 / 改善 / 構造」

対象ドメイン（エラー vs プロンプト / コード vs 問題）が異なるため subagent の判断は容易。iter 1 の baseline 評価で問題が出た場合のみ対応。

## 運用

- 本ファイルは **Phase 0 時点のスナップショット**。各スキルの description を改訂したら本ファイルも更新する（該当スキルの PR に含める）
- 各スキル iter 0 で「本表の該当行を確認 → 重なりが body 側で整合しているか」をチェック
