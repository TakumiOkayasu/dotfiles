# Codex Prompt Commands

repo-local な custom prompt command 集。

## 呼び出し

Codex session 内では、UserPromptSubmit hook が有効な場合に次の形式を展開する。

```text
prompt:feat ユーザー検索機能を追加
prompt:fix 特定入力で500になる
prompt:deep-review HEADとの差分
prompt:list
```

補助 CLI からも使える。

```sh
codex-prompt list
codex-prompt expand prompt:feat "ユーザー検索機能を追加"
codex-cmd feat "ユーザー検索機能を追加"
```

## 注意

- `prompt:*` は Codex 公式の built-in slash command ではない。`prompt-command-expand.sh` hook と `codex-prompt` wrapper で実現する repo-local 互換レイヤー。
- prompt は薄い router に留め、詳細手順は skills に寄せる。
- `$ARGUMENTS` は hook / wrapper 側でユーザー引数に置換される。

## Commands

| Command | Purpose |
| --- | --- |
| `prompt:feat` | 新機能実装。risk gate → skill chain → TDD |
| `prompt:fix` | バグ修正。再現 → 原因特定 → regression test |
| `prompt:deep-review` | 多角レビュー。security / performance / maintainability |
| `prompt:review` | deep-review alias |
| `prompt:security-review` | セキュリティ限定レビュー |
| `prompt:commit-msg` | staged diff から commit message 案を作る。commit はしない |
| `prompt:commit` | commit-msg alias |
| `prompt:plan` | 方針相談。ファイル編集なし |
| `prompt:explain` | コード理解。ファイル編集なし |
| `prompt:test` | テスト追加・テスト設計 |
| `prompt:refactor` | 振る舞いを変えない構造改善 |
| `prompt:prompt-tune` | prompt / skill の empirical tuning |
| `prompt:handoff` | Codex 引き継ぎ文を生成 |
