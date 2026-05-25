#!/usr/bin/env bash
# PostToolUse (matcher: Bash) フック。
# Bash コマンドが失敗 (非ゼロ終了) した際、failure_log に自動で記録する。
# 「コマンドエラーの捕捉」を決定論的に担当し、判断を要する分析・原因記入・
# 解決マークは failure-logging スキルが行う。
set -euo pipefail

LOG_DIR="claude_tmp/failure_log"
LOG_FILE="${LOG_DIR}/auto-fail.log"

# PostToolUse のペイロードを stdin から受け取る。
payload="$(cat)"

# tool_response から終了コード・コマンド・エラー出力を取り出す。
# フィールド名は Claude Code のバージョンで異なる場合がある。
# 動かない場合は jq のパスを実環境のペイロードに合わせて調整すること。
exit_code="$(printf '%s' "$payload" | jq -r '.tool_response.exit_code // .tool_response.exitCode // empty' 2>/dev/null || true)"
command="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
stderr_tail="$(printf '%s' "$payload" | jq -r '.tool_response.stderr // .tool_response.output // empty' 2>/dev/null | tail -c 500 || true)"

# 終了コードが取得できない、または 0 の場合は何もしない。
[ -z "${exit_code}" ] && exit 0
[ "${exit_code}" = "0" ] && exit 0

mkdir -p "${LOG_DIR}"
{
  printf -- '---\n'
  printf 'time: %s\n' "$(date -Iseconds)"
  printf 'exit: %s\n' "${exit_code}"
  printf 'command: %s\n' "${command}"
  printf 'stderr_tail: %s\n' "${stderr_tail}"
} >> "${LOG_FILE}"

exit 0
