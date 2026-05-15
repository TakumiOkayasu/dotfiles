# Agent Templates

Claude Code の subagent (`.claude/agents/*.md`) を **個別プロジェクト** に導入するためのテンプレート置き場。

このディレクトリのファイルは `.template.md` 拡張子を持ち、Claude Code が**自動認識しない** (`.claude/agents/` 配下ではない) ことを意図して配置されている。

---

## 配置方針 (なぜここに置くか)

| 配置先 | 採否 | 理由 |
|--------|------|------|
| `~/.claude/agents/` | ❌ | Claude Code がユーザー subagent として自動認識してしまう。プロジェクト固有値が未設定の状態で誤起動するリスク |
| プロジェクトの `.claude/agents/` 直配置 | ❌ (テンプレ段階では) | 上記同様。プロジェクト固有値を埋めずに置くと壊れた subagent が認識される |
| dotfile-work `templates/agents/` (ここ) | ✅ | Claude Code から不可視。git 管理されるため履歴追跡可。コピー基点として明示的 |

---

## 利用可能なテンプレート

| ファイル | 概要 |
|----------|------|
| `coverage-guard.template.md` | カバレッジ監査用 read-only subagent。`tools: Read, Grep, Glob, Bash`、`model: haiku` |

---

## 適用手順 (任意プロジェクトへの導入)

### 1. テンプレートをコピー

```bash
# プロジェクトルートで実行
mkdir -p .claude/agents
cp ~/prog/dotfile-work/templates/agents/coverage-guard.template.md .claude/agents/coverage-guard.md
```

`.template.md` 拡張子を **`.md` に変更**してコピーすること (Claude Code は `.md` のみ subagent として認識)。

### 2. Project Setup 4 項目を編集

`.claude/agents/coverage-guard.md` の `## Project Setup` セクションを開き、以下 4 項目をプロジェクト固有値で埋める:

| 項目 | 例 (PHP / PHPUnit) | 例 (Node / Vitest) | 例 (Go) |
|------|--------------------|--------------------|---------|
| カバレッジコマンド | `vendor/bin/phpunit --coverage-text` | `npm run test:coverage` | `go test ./... -coverprofile=coverage.out && go tool cover -func=coverage.out` |
| 閾値 | `80` | `80` | `80` |
| 対象 glob | `src/Controller/**, src/Service/**` | `src/**` | `./...` |
| 除外パターン | `**/Migration/**, **/Tests/**` | `**/__tests__/**` | `vendor/**` |

未記入のまま起動すると subagent はエラー報告して中断する設計。

### 3. 動作確認

```bash
# Claude Code セッションを再起動 (filesystem 編集の反映)
# その後セッション内で:
/agents
```

`/agents` コマンドで `coverage-guard` が「Project agent」として一覧表示されていれば導入成功。

呼出例:

```text
coverage-guard を使って今回の変更のカバレッジを監査して
```

### 4. (任意) `.gitignore` 確認

プロジェクトポリシーによっては `.claude/agents/` を gitignore で除外する場合がある。チーム共有なら commit、個人専用なら ignore を選択。

---

## 同名衝突時の優先順位

Claude Code の subagent は以下の優先順位で解決される (上位が勝つ):

1. session-defined (セッション内で動的定義)
2. **project agents** (`<project>/.claude/agents/`) ← 本テンプレ適用先
3. user agents (`~/.claude/agents/`)
4. plugin agents

プロジェクトで `coverage-guard` を導入すると、user agent 同名は project 側で上書きされる。

---

## テンプレート追加時の作法 (本ディレクトリへの貢献ルール)

1. ファイル名は `<name>.template.md` (`.template` サフィックス必須)
2. frontmatter `name:` フィールドは `.template` を含めない (`name: coverage-guard` の形)
3. プロジェクト固有値の差し込み口は `## Project Setup` セクションに集約し、`<!-- ここを記入 -->` プレースホルダーで明示
4. read-only / write-許可 等の制約は `tools:` フィールドで物理的に強制 (本文の自己制約だけに頼らない)
5. 本 README の「利用可能なテンプレート」表に行を追加
