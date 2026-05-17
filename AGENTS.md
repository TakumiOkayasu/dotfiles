# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## Overview

個人用dotfilesリポジトリ。Shell/Git/Vim設定とCodex設定（skills, hooks, prompts, rules）を管理し、`install.sh` でシンボリックリンクを配置する。

## Commands

```bash
# インストール
./install.sh              # 対話モード
./install.sh -f           # 全ファイル強制インストール
./install.sh -n           # ドライラン
./install.sh -u           # アンインストール

# テスト (Docker)
docker compose -f tests/compose.yml run --rm hooks-test    # hook テスト
docker compose -f tests/compose.yml run --rm bin-test      # bin/ テスト
docker compose -f tests/compose.yml run --rm install-test  # install.sh テスト

# CLI (bin/ → ~/.local/bin/)
git-new-feature <name>    # ブランチ作成 (-f fix/ -d docs/ -r refactor/ -c chore/)
git-cleanup-branch        # マージ済みブランチ削除
gh-setup-repo             # GitHub リポジトリ設定
codex-cmd list            # Codex prompt command 一覧
codex-feat <description>  # 機能実装ガイド (TDD)
codex-fix <description>   # バグ修正ガイド
codex-deep-review [target] # 並列観点レビュー
```

## Architecture

```text
dotfile-work/
├── install.sh           # メインインストーラー (POSIX sh)
├── config/              # ドットファイル本体
│   ├── shell/           # bash/zsh/fish + common.sh, aliases.sh
│   ├── git/             # .gitconfig.{common,work,private}, .gitignore.*
│   └── vim/             # .vimrc
├── codex/              # Codex設定 → ~/.codex/ にリンク
│   ├── global_AGENTS.md # → ~/.codex/AGENTS.md (リネームしてリンク)
│   ├── hooks.json      # Codex hook定義
│   ├── settings.json   # 参照用設定
│   ├── prompts/        # prompt command 断片
│   ├── hooks/           # 自動処理 (セキュリティ, セッション管理)
│   ├── rules/           # 常時適用ルール (hallucination-prevention, hierarchical-architecture, coding-conventions, implementation-policy)
│   └── skills/          # オンデマンド手順 (TDD, debugging, consultation, failure-logging)
├── bin/                 # CLI ツール → ~/.local/bin/
├── tests/               # Docker テスト
└── docs/                # ドキュメント
```

Codex vendor skill は自動 clone しない。`codex/vendor/` がある場合のみ SessionStart hook が更新を試みる。

## Install Flow

1. `git ls-files` で `config/` と `codex/` のファイルを列挙
2. `config/` → `$HOME` に、`codex/` → `~/.codex/` にシンボリックリンク作成
3. `global_AGENTS.md` は `AGENTS.md` にリネームしてリンク
4. プラットフォーム自動検出: macOS → `.gitconfig.private` / Linux・WSL → `.gitconfig.work`
5. `bin/` は `~/.local/bin/` にリンクし、Codex 用ショートカット (`codex-feat` など) も配置する

## Development Notes

- シェルスクリプトは原則 POSIX sh。bash依存スクリプトは `#!/bin/sh` + bash再実行パターン
- ドキュメントに具体的な数値（件数・行数）を書かない（ドリフト防止）

## Subagents

Codex では、品質や速度が上がる場面で subagent を積極利用する。

- 多角レビュー、複数案の妥当性検証、影響範囲調査、客観評価、並列検証は subagent 候補
- 親セッションの直近判断をブロックする作業は親が行う
- worker には担当範囲・編集可能ファイル・他者の変更を戻さないことを明示する
- subagent の結果は親が統合し、根拠・差分・テストで検証してから採用する

## [自動] セッション継続プロトコル

以下はCodex自身が自律的に実行する。

### PROGRESS.md 自動更新

ファイル: `.codex/progress.md`

更新タイミング:

1. **タスク着手時** → 「現在のタスク」更新
2. **設計判断時** → 「判断ログ」に理由(Why)追記
3. **Planモード結論時** → 実装前に書き出し
4. **タスク完了時** → 完了マーク + 次のタスク

### コンテキスト警告対応

- **⚠️ 70%**: PROGRESS.md が最新か確認
- **🚨 85%**: 即座に更新（現状・判断理由・次のステップ）

### セッション開始時

`.codex/progress.md` の内容を確認し、未完了タスクがあればそこから再開。

### PROGRESS.md フォーマット

```markdown
# PROGRESS

## 現在のタスク
- [ ] タスク名 - 目的: xxx

## 判断ログ
- YYYY-MM-DD: 判断内容。理由: ...

## 完了
- [x] 完了したタスク
```
