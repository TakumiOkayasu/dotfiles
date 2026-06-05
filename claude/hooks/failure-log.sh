#!/usr/bin/env bash
# Stop フック。ターン終了時に transcript JSONL を読み、失敗した Bash コマンド
# (tool_result.is_error == true) を failure_log に自動記録する。
#
# WHY Stop か: PostToolUse[Bash] は失敗コマンドで発火せず、tool_response にも
# 終了コードが無い (2026-06-05 実証)。失敗は transcript の is_error にのみ残る。
#
# WHY 増分読み: Stop は毎ターン発火する。transcript はセッション中に単調増加
# するため、毎回全読みすると累積 O(ターン数^2) になる。前回処理済みのバイト位置
# (offset) を保存し新規追記分だけ読むことで、各ターン O(Δ)・累積 O(N) に抑える。
#
# 捕捉のみを担当。分析・原因記入・解決マークは failure-logging スキルが行う。
set -euo pipefail

LOG_DIR="claude_tmp/failure_log"
LOG_FILE="${LOG_DIR}/auto-fail.log"
OFFSET_FILE="${LOG_DIR}/.transcript-offset"
RESULT_TAIL_CHARS=300

transcript_path="$(jq -r '.transcript_path // empty')" \
  || { printf '[failure-log] payload parse failed\n' >&2; exit 0; }
[ -n "${transcript_path}" ] || exit 0

# realpath はシンボリックリンク攻撃 (TOCTOU) 緩和の best-effort。未導入環境では
# 生パスにフォールバックし、hook 自体は止めない。
resolved="$(realpath -- "${transcript_path}" 2>/dev/null || true)"
[ -n "${resolved}" ] && transcript_path="${resolved}"
[ -f "${transcript_path}" ] || exit 0

mkdir -p "${LOG_DIR}"
touch "${LOG_FILE}"

# 前回処理済みバイト位置を読む。破損値・transcript 縮小 (別セッション) は先頭から。
current_size="$(wc -c < "${transcript_path}")"
offset=0
if [ -f "${OFFSET_FILE}" ]; then
  offset="$(cat "${OFFSET_FILE}")"
  case "${offset}" in *[!0-9]*) offset=0 ;; esac
fi
[ "${current_size}" -lt "${offset}" ] && offset=0
[ "${current_size}" -eq "${offset}" ] && exit 0   # 新規追記なし

new_data="$(tail -c "+$((offset + 1))" "${transcript_path}")"
[ -n "${new_data}" ] || { printf '%s' "${current_size}" > "${OFFSET_FILE}"; exit 0; }

# 新規分から失敗 Bash を抽出 (jq 1 回・TSV 出力)。tool_use(Bash) の id->command と
# tool_result(is_error) を tool_use_id で突き合わせ、command と結果を 1 行に整形する。
# 秘密混入時の二重露出を防ぐため key/token 類を <redacted> にマスクする (best-effort)。
# jq 失敗 (末尾の不完全行等) は offset を進めず次ターンで再試行する。
failures="$(printf '%s' "${new_data}" | jq -rs --argjson limit "${RESULT_TAIL_CHARS}" '
  def mask: gsub("(?i)(api[_-]?key|secret|token|password|passwd|bearer|authorization)\\s*[=:]?\\s*\\S+"; "<redacted>");
  (map(select(.type == "assistant") | .message.content[]?
       | select(.type == "tool_use" and .name == "Bash") | {(.id): .input.command})
   | add // {}) as $cmds
  | map(select(.type == "user")
        | .toolUseResult as $tur
        | (.message.content[]? | select(.type == "tool_result" and (.is_error == true))) as $tr
        | select($cmds | has($tr.tool_use_id))
        | [ $tr.tool_use_id,
            ($cmds[$tr.tool_use_id] // "" | mask | gsub("[\t\n]+"; " ")),
            ($tur | tostring | mask | gsub("[\t\n]+"; " ") | .[0:$limit]) ]
        | @tsv)
  | .[]
')" || { printf '[failure-log] transcript parse failed (incomplete line?); retry next turn\n' >&2; exit 0; }

now="$(date -Iseconds)"
# LOG_FILE への append はループ末尾で 1 回だけ open する (失敗 1 件ごとの再 open を避ける)。
while IFS=$'\t' read -r id command result_tail; do
  [ -n "${id}" ] || continue
  printf -- '---\n'
  printf 'time: %s\n' "${now}"
  printf 'id: %s\n' "${id}"
  printf 'command: %s\n' "${command}"
  printf 'result_tail: %s\n' "${result_tail}"
done <<< "${failures}" >> "${LOG_FILE}"

# このバイト範囲は処理済み。次ターンはここから読む (重複記録を offset で防ぐ)。
printf '%s' "${current_size}" > "${OFFSET_FILE}"
exit 0
