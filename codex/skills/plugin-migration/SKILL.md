---
name: plugin-migration
description: dotfile-work Codex workflowをlocal skills/hooksからplugin bundleへ同期・検証・配布準備する時に使用。後方互換なしのplugin-only運用。
---

# Plugin Migration

## 目的

plugin-only 運用を維持する。

- 開発中: `codex/` を source of truth として編集する
- 配布時: `plugins/dotfile-work-codex/` へ同期する
- 導線: `@feat`, `@fix`, `@deep-review`, `@rules-required` を主導線にする
- 後方互換: `prompt:*`, `/prompt:*`, `codex-prompt`, `codex-cmd` は使わない

## 手順

1. plugin bundle を同期する

```sh
python3 scripts/sync-codex-plugin.py --repo . --clean
```

2. plugin を検証する

```sh
python3 scripts/verify-codex-plugin.py --repo .
```

3. 必要なら個人 marketplace へインストールする

```sh
python3 scripts/install-codex-plugin-personal.py --repo .
```

4. Codex を再起動し、`/plugins` から `dotfile-work Codex` を install / enable する。plugin hooks は hook review で信頼する。

## 注意

- Codex CLI TUI では `/prompt:*` は使わない。
- `prompt:*` 互換も削除済み。
- plugin の安定導線は `@skill`。
- local plugin は install 後に cache copy から読まれる。更新後は plugin の再installまたはupgrade/restartが必要。
