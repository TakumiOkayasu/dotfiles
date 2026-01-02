#!/bin/bash
# Session start reminder - CLAUDE.mdの重要ルールをリマインド

cat <<'EOF'
{
  "hookSpecificOutput": {
    "additionalContext": "[CLAUDE.md リマインド] セッション開始時チェック:\n- コード変更前にブランチ確認 (git-new-feature でブランチ作成)\n- 1ブランチ = 1機能 = 1PR (「ついでに」修正は禁止)\n- TDD原則を遵守 (RED-GREEN-REFACTOR)\n- マージ後は git-cleanup-branch で削除確認をユーザーに行う\n- git commit/push は禁止 (ユーザーのみ操作可能)"
  }
}
EOF
