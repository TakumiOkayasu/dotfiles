# Claude Code 運用ルール

## 🎯 作業フロー

```text
git branch --show-current
[main の場合] git-new-feature <機能名>
view ~/.claude/skills/<該当スキル>/SKILL.md
# 実装開始
```

---

## 🚨 絶対禁止事項(CRITICAL)

**以下は例外なく禁止。違反は重大なエラー。**

詳細: `forbidden-actions` スキル

### 実行前の必須確認

**全てのGit操作前:**
```text
□ これはcommitまたはpushか? → YES なら中断
□ mainブランチで作業していないか? → YES なら中断
```

**全ての実装前:**
```text
□ 該当スキルを読んだか? → NO なら中断
□ テストを書いたか? → NO なら中断
□ 複数案を検討したか? → NO なら中断
```

---

## 🌍 多角的思考

**最初の案で実装禁止。必ず複数案(2-3)を検討。**

**スキル**: `brainstorming-design`, `pattern-thinking`, `problem-solving`

---

## 💬 コミュニケーション

**判断には根拠・メリデメ・代替案必須。**

**スキル**: `communication-guidelines`

---

## 📋 スキルマップ

### 🔥 頻出

```text
思考: brainstorming-design, pattern-thinking, problem-solving
実装: test-driven-development, code-generation, hallucination-prevention
Git: git-workflow, github, gitlab
バグ: systematic-debugging, failure-logging
```

### 📋 設計・品質

```text
設計: api-design, database-design, interface-composition-design
品質: code-review, security-review, security-checklist, refactoring
```

### 📚 特殊機能

```text
認証: authentication-authorization
Web: ui-ux-design, websocket-realtime
インフラ: docker, ci-cd
その他: ls ~/.claude/skills/
```

---

## 🎯 自動化

**スキル**: `quality-automation`, `daily-report`

---

## ⚙️ 環境

```text
文字: UTF-8, 半角記号
権限: $(whoami):$(whoami)

claude_tmp/
  ├── brainstorming/
  ├── failure_log/
  ├── analysis/
  ├── daily_reports/
  └── review_reports/
tests/
```

---

## 🔍 迷った時

1. 該当スキル再読
2. ローカルCLAUDE.md確認
3. `auto-consultation`
4. `/bounce`

---

## 💡 原則

**本質を突く最小限のレスポンス。スキルを積極活用。**
