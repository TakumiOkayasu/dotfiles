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

### スタック防止 (Claude側ルール)

| ルール | 内容 |
|------|------|
| 即時出力 | 思考完了を待たず、まず1行出力する |
| 分割出力 | 長い応答は段階的に出力（溜め込まない） |
| 処理報告 | 重い処理前に「確認中...」等を出力 |
| ツール前宣言 | ツール実行前に何をするか1行書く |

**禁止**: 長時間の無言思考、大量出力の一括送信

### 応答スタック時 (ユーザー側対応)

| 状態 | 対応 |
|------|------|
| `0 tokens` が30秒継続 | Escで中断→再送 |
| 中断後も `0 tokens` | 短文で生存確認（例: "続けて"） |

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
| git commit/push | 常に | 🚫 (hook) |
| mainブランチ編集 | 常に | 🚫 (hook) |
| ローカルコマンド直接実行 | 常に | 🚫 (hook) |
| コマンド難読化・間接実行 | 常に | 🚫 (hook) |
| 管理者権限 (sudo等) | 常に | 🚫 (hook) |
| 単一案で実装 | 常に | 🚫 |
| スキル未読で実装 | 常に | 🚫 |

### 🔒 コマンド難読化の禁止

hookを迂回するための難読化・間接実行は**絶対禁止**。

| 手法 | 例 | 判定 |
|------|---|------|
| 文字列分割 | `eval "pyt""hon3"` | 🚫 |
| 変数構築 | `P=pytho; "${P}n3"` | 🚫 |
| base64デコード実行 | `echo ... \| base64 -d \| sh` | 🚫 |
| hex/octalエスケープ | `$'\x70\x79...'` | 🚫 |
| Write+Execute | Write→bash実行 | 🚫 |
| curl/wgetパイプ | `curl ... \| sh` | 🚫 |
| printf実行 | `printf '\x70...' \| sh` | 🚫 |

---

## ⚠️ 静的解析 (必須)

**ruff, mypy, Pylance のすべてをパスすること**

| ツール | 確認タイミング |
|--------|---------------|
| ruff | コード変更後 |
| mypy | コード変更後 |
| Pylance | 修正完了報告前 |

**報告前に必ず全ツールでエラーゼロを確認。未確認での完了報告は禁止。**

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

## 🔄 Bash実行ルール

**hookで自動警告**: ビルド・テスト系は `run_in_background=true` 推奨

---

## 🔧 リソース活用 (必須)

**skills/commands/hooksを最大限活用すること。自前実装禁止。**

| リソース | 場所 | 用途 |
|----------|------|------|
| skills | `~/.claude/skills/` | 作業手順・ルール |
| commands | `~/.claude/commands/` | トリガーワード対応 |
| hooks | `~/.claude/hooks/` | 自動処理 |

```bash
ls ~/.claude/skills/
ls ~/.claude/commands/
```

---

## 💡 原則

**最小出力。本質のみ。リソース活用。**
**言語のバージョンは最新版のLTSを使用。**
