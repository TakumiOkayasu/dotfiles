# Claude Code 運用ルール

## ⚡ 出力制限 (最優先)

**レートリミット対策: 全応答に適用**

| ルール | 内容 |
|--------|------|
| 上限 | 1000トークン/応答 |
| 前置き | 禁止 (了解/ありがとう等) |
| 締め | 禁止 (以上です/何かあれば等) |
| 形式 | テーブル > 箇条書き > 文章 |
| 状態 | 記号で表示 (✅❌⚠️) |

**違反時**: 即座に短縮して再出力

---

## 🎯 作業フロー

```text
git branch --show-current
[main の場合] git-new-feature <機能名>
view ~/.claude/skills/<該当スキル>/SKILL.md
```

---

## 🚨 禁止事項

詳細: `forbidden-actions` スキル

| 操作 | 条件 | 判定 |
|------|------|------|
| git commit/push | 常に | 🚫 |
| mainブランチ編集 | 常に | 🚫 |
| 単一案で実装 | 常に | 🚫 |
| スキル未読で実装 | 常に | 🚫 |

---

## 📋 スキルマップ

| 分類 | スキル |
|------|--------|
| 思考 | brainstorming-design, pattern-thinking, problem-solving |
| 実装 | test-driven-development, code-generation |
| Git | git-workflow, github |
| デバッグ | systematic-debugging, failure-logging |

その他: `ls ~/.claude/skills/`

---

## ⚙️ 環境

```text
文字: UTF-8, 半角記号
権限: $(whoami):$(whoami)
```

---

## 💡 原則

**最小出力。本質のみ。スキル活用。**
