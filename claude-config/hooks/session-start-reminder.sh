#!/bin/bash
# Session start reminder - CLAUDE.mdの重要ルールをリマインド
#
# 使い方 (手動実行):
#   ./session-start-reminder.sh
#
# Claude Code hook として SessionStart 時に自動実行される
# (stdin は不要)

# 手動実行時のヘルプ
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    cat <<'HELP'
session-start-reminder.sh - セッション開始時のCLAUDE.mdリマインド

使い方:
  ./session-start-reminder.sh

説明:
  Claude Code の SessionStart hook として動作し、
  セッション開始時にCLAUDE.mdの重要ルールをリマインドします。
HELP
    exit 0
fi

cat <<'EOF'
{
  "hookSpecificOutput": {
    "additionalContext": "[CLAUDE.md リマインド] セッション開始時チェック:\n- コード変更前にブランチ確認 (git-new-feature でブランチ作成)\n- 1ブランチ = 1機能 = 1PR (「ついでに」修正は禁止)\n- TDD原則を遵守 (RED-GREEN-REFACTOR)\n- マージ後は git-cleanup-branch で削除確認をユーザーに行う\n- git commit/push は禁止 (ユーザーのみ操作可能)"
  }
}
EOF
