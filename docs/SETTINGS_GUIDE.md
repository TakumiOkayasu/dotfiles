# settings.json ガイド

Claude Code の `settings.json` 設定リファレンス。

公式ドキュメント: <https://code.claude.com/docs/en/settings>

---

## 1. 配置場所と優先順位

| スコープ | パス | 用途 |
| --------- | ------ | ------ |
| グローバル | `~/.claude/settings.json` | 全プロジェクト共通 |
| プロジェクト | `.claude/settings.json` | リポジトリ固有 |
| ローカル | `.claude/settings.local.json` | 個人用（Git管理外） |
| マネージド | 組織管理者が配布 | 組織ポリシー強制 |

**評価順**: deny → ask → allow（先にマッチしたルールが優先）

---

## 2. スキーマ一覧（主要キー）

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "permissions": {},
  "hooks": {},
  "model": "string",
  "language": "string",
  "includeCoAuthoredBy": false,
  "autoUpdatesChannel": "string",
  "env": {},
  "sandbox": {},
  "outputStyle": "string",
  "additionalDirectories": []
}
```

| キー | 型 | 説明 |
| ------ | --- | ------ |
| `permissions` | object | ツール実行の許可/拒否ルール |
| `hooks` | object | ライフサイクルイベントのフック |
| `model` | string | デフォルトモデル (`opus`, `sonnet`, `haiku`) |
| `language` | string | 応答言語 (`japanese` 等) |
| `includeCoAuthoredBy` | boolean | コミットにCo-Authored-By追加 |
| `autoUpdatesChannel` | string | 自動更新チャンネル (`latest`, `stable`) |
| `env` | object | 環境変数の注入 |
| `sandbox` | object | サンドボックス設定 |
| `outputStyle` | string | 出力スタイル指示 |

---

## 3. permissions 詳細

```json
{
  "permissions": {
    "allow": ["パターン..."],
    "ask": ["パターン..."],
    "deny": ["パターン..."],
    "defaultMode": "plan"
  }
}
```

### パターン構文

| パターン | 効果 |
| --------- | ------ |
| `Bash(cmd:*)` | cmdで始まるコマンドを許可 |
| `Bash(cmd arg)` | 完全一致で許可 |
| `Read(path)` | 特定パスの読み取り許可 |
| `Edit(path)` | 特定パスの編集許可 |
| `WebFetch(domain:example.com)` | ドメイン指定のfetch許可 |
| `mcp__server__tool` | MCP ツール許可 |
| `Skill(name)` | スキル許可 |

### defaultMode

| 値 | 動作 |
| --- | ------ |
| `plan` | デフォルトでPlanモード |
| `acceptEdits` | 編集は自動許可、Bashは確認 |
| `bypassPermissions` | 全許可（非推奨） |

---

## 4. hooks 詳細

```json
{
  "hooks": {
    "イベント名": [
      {
        "matcher": "ツール名",
        "hooks": [
          {
            "type": "command",
            "command": "スクリプトパス"
          }
        ]
      }
    ]
  }
}
```

### イベント種別

| イベント | タイミング | matcher |
| --------- | ---------- | --------- |
| `PreToolUse` | ツール実行前 | Bash, Read, Edit, Write 等 |
| `PostToolUse` | ツール実行後 | 同上 |
| `SessionStart` | セッション開始時 | なし |
| `UserPromptSubmit` | ユーザー入力時 | なし |
| `PreCompact` | コンテキスト圧縮前 | なし |

### Exit code による制御

| Exit code | 効果 |
| ---------- | ------ |
| `0` | 許可（stdoutをフィードバック） |
| `2` | ブロック（stderrを理由表示） |
| その他 | 無視 |

### async オプション

```json
{ "type": "command", "command": "...", "async": true }
```

`async: true` で非同期実行（ブロッキングしない）。

---

## 5. 本リポジトリの設計方針

### allow の方針

| 方針 | 理由 |
| ------ | ------ |
| `git commit/push` を allow に入れない | hookでブロックするが、allowに入れると許可プロンプトをスキップしてしまう |
| `node/php/python` を allow に入れない | local-command-block.sh でdocker使用を強制 |
| `bash:*` を allow に入れない | `bash -c "node ..."` でhook迂回可能 |
| `docker:*` で集約 | 個別サブコマンド列挙は冗長 |
| プロジェクト固有スクリプト除外 | `./dbash.sh` 等はプロジェクト側で許可 |

### hookとallowの役割分担

```text
allow: 許可プロンプトのスキップ（利便性）
hook:  実行の強制ブロック（セキュリティ）

allowに入っていても、hookがexit 2を返せばブロックされる。
ただし、allowに不要なエントリがあると防御の多層性が下がる。
```

### allowのグルーピング（配置順）

```text
1. ファイル操作    (ls, mkdir, rm, mv, ln, chmod, du, unzip)
2. テキスト処理    (cat, echo, sed, awk, grep, find, xargs, xxd)
3. シェル制御      (source, for, set -a, set +a, timeout)
4. システム情報    (env, getconf, ip, ping)
5. ネットワーク    (curl, ssh, ssh-add, scp)
6. DB             (mysql)
7. Git            (commit/push除外、アルファベット順)
8. Docker         (docker:*, docker-compose:*)
9. パッケージ管理  (brew install)
10. Linter/テスト  (eslint, phpunit, phpcs)
11. CLI           (gh, glab, git-new-feature)
12. その他        (Read, WebFetch, MCP, Skill)
```

---

## 6. JSONバリデーション

```bash
# docker経由でJSON構文チェック
docker run --rm -v "$(pwd)/claude/settings.json:/data/s.json" \
  python:3-slim python3 -c "import json; json.load(open('/data/s.json')); print('OK')"

# jqが使える環境
jq . ~/.claude/settings.json > /dev/null && echo "OK"
```

---

## 7. よくある問題

### allowに入れたのに許可プロンプトが出る

パターンが不一致の可能性。`Bash(git add:*)` と `Bash(git add *)` は異なる。コロン付きが推奨。

### hookが動かない

- パスが正しいか確認（`~` 展開は有効）
- 実行権限があるか: `chmod +x hook.sh`
- exit codeが正しいか: ブロックは `exit 2`

### 設定変更が反映されない

新しいセッションを開始する。settings.json はセッション開始時に読み込まれる。
