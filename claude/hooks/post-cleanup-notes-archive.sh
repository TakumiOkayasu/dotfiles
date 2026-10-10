#!/usr/bin/env bash
# PostToolUse hook: git-cleanup-branch / git branch -D 実行後、
# 既に存在しないブランチに対応する notes ファイルを notes/archive/ へ移動する。
#
# 規約: ~/.claude/rules/opus-47-policy.md 「File-System Memory」「削除・整理」

set -euo pipefail

# Claude Code の PostToolUse hook は stdin に JSON を渡してくる
input=$(cat)

# bash tool で git-cleanup-branch / git branch -D / git branch -d 系のみ反応
command=$(echo "$input" | jq -r '.tool_input.command // empty' 2>/dev/null || true)

if [[ -z "$command" ]]; then
  exit 0
fi

if ! echo "$command" | grep -qE 'git-cleanup-branch|git[[:space:]]+branch[[:space:]]+-[Dd]'; then
  exit 0
fi

# git リポジトリでなければ何もしない
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

notes_dir=".claude/notes"
[[ -d "$notes_dir" ]] || exit 0

mkdir -p "$notes_dir/archive"

archived=0
for note in "$notes_dir"/*.md; do
  [[ -f "$note" ]] || continue
  base=$(basename "$note" .md)
  [[ "$base" == "_template" ]] && continue
  [[ "$base" == "README" ]] && continue

  # task-id → ブランチ名候補 (ハイフン → スラッシュは曖昧なので 2 パターン試す)
  candidate1="$base"
  candidate2="${base/-//}"

  if ! git show-ref --verify --quiet "refs/heads/$candidate1" && \
     ! git show-ref --verify --quiet "refs/heads/$candidate2"; then
    mv "$note" "$notes_dir/archive/${base}.md"
    echo "[notes-archive] moved: $note → $notes_dir/archive/${base}.md" >&2
    archived=$((archived + 1))
  fi
done

if [[ "$archived" -gt 0 ]]; then
  echo "[notes-archive] archived $archived note(s)" >&2
fi

exit 0

