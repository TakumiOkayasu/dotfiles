# Claude Code 基本設定

## 🚨 絶対厳守(毎タスク確認)

1. **git commit/push 禁止** - ユーザーのみ操作可能
2. **mainブランチで作業禁止** - 必ず新ブランチを作成
3. **テストファースト** - RED → GREEN → REFACTOR
4. **1ブランチ1機能** - 「ついでに」修正は禁止
5. **不明点は相談** - 実装前にスマホ/PCクライアントへ
6. **複数案提示** - 単一解の押し付け禁止
7. **スキル活用** - `~/.claude/skills/` を必ず確認
8. **失敗を記録** - `claude_tmp/failure_log/` に書き出す

---

## 📋 タスク受領時の必須アクション

```
1. git branch --show-current で現在ブランチ確認
2. mainなら → git-new-feature で新ブランチ作成
3. 該当スキルを読み、「{スキル名}を確認しました」と宣言
4. ブランチ確認後、初めてコード変更開始
```

🛑 この手順を飛ばしてコード変更することは禁止

---

## 📁 スキル参照(必須)

**タスク開始前に該当スキルを読むこと。**

`~/.claude/skills/` 内のSKILL.mdを確認:

| タスク種別 | 読むべきスキル |
|-----------|---------------|
| Git操作 | git-workflow |
| 実装 | test-driven-development, code-generation |
| デバッグ | systematic-debugging |
| 設計 | api-design, database-design, interface-composition-design |
| リファクタ | refactoring |
| レビュー | code-review, security-review |
| 認証/認可 | authentication-authorization |
| CI/CD | ci-cd, docker |
| ドキュメント | documentation |
| コード検証 | hallucination-prevention |
| 失敗記録 | failure-logging |
| 相談 | consultation |

---

## ⚙️ 基本設定

- 日本語で応答(コードコメントは元言語)
- 半角記号優先(全角括弧禁止)
- UTF-8のみ
- ファイル作成は$(whoami)のユーザー/グループ

---

## 🗂️ ファイル管理

- プロジェクトルートを基準に作業
- 一時ファイルは `claude_tmp/` に配置
- テストファイルは `tests/` に配置
- `claude_tmp/` は `.gitignore` に追加推奨

---

## dotfiles管理ルール

**dotfile-work リポジトリは実質的な `$HOME` である。**

- 設定ファイルはすべて `dotfile-work/` 内で編集
- 本当の `$HOME` にはシンボリックリンクを貼る
- 直接 `$HOME` にファイルを作成・編集しない
