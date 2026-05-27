i#!/usr/bin/env bash
# SessionStart hook: 該当する .claude/notes/{task-id}.md を context へ注入する
#
# 規約: ~/.claude/rules/opus-47-policy.md 「File-System Memory」
# 動作: カレントブランチ名から task-id を導出、対応する notes ファイルがあれば cat する。
#       main / master ブランチでは何もしない。

set -euo pipefail

# git リポジトリでなければ何もしない
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

branch=$(git branch --show-current 2>/dev/null || true)

# main / master / 空ブランチではスキップ
case "$branch" in
  "" | "main" | "master" | "HEAD")
    exit 0
    ;;
esac

# task-id: スラッシュをハイフンに置換 (feat/login → feat-login)
task_id="${branch//\//-}"
notes_file=".claude/notes/${task_id}.md"

if [[ -f "$notes_file" ]]; then
  cat <<EOF
## Session Restored: ${task_id}

以下は前回までの作業ノートです。読み込んでから着手してください (opus-47-policy.md「File-System Memory」規約)。

---

$(cat "$notes_file")

---

(end of restored notes)
EOF
fi

exit 0

