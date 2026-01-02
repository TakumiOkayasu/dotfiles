#!/bin/bash
# Session start reminder - CLAUDE.mdの重要ルールをリマインド

cat <<'EOF'
{
  "hookSpecificOutput": {
    "additionalContext": "[CLAUDE.md リマインド] セッション開始時チェック:\n- コード変更前にブランチ確認 (git branch --show-current)\n- TDD原則を遵守 (RED-GREEN-REFACTOR)\n- マージ後はブランチ削除確認をユーザーに行う\n- git commit/push は禁止 (ユーザーのみ操作可能)"
  }
}
EOF
