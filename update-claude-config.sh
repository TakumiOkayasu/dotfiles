#!/bin/bash
# update-claude-config.sh
# Version: 2.0.0
# 
# 使用方法:
#   初回: ./update-claude-config.sh --install
#   実行: update-claude-config [OPTIONS] [DIR]
#   削除: update-claude-config --uninstall

set -euo pipefail
IFS=$'\n\t'

# ========================================
# 色定義
# ========================================
if [[ -t 1 ]]; then
  readonly RED='\033[0;31m'
  readonly YELLOW='\033[1;33m'
  readonly GREEN='\033[0;32m'
  readonly BLUE='\033[0;34m'
  readonly CYAN='\033[0;36m'
  readonly BOLD='\033[1m'
  readonly RESET='\033[0m'
else
  readonly RED=''
  readonly YELLOW=''
  readonly GREEN=''
  readonly BLUE=''
  readonly CYAN=''
  readonly BOLD=''
  readonly RESET=''
fi

# ========================================
# 定数
# ========================================
readonly VERSION="2.0.0"
readonly SCRIPT_NAME="update-claude-config"
readonly INSTALL_DIR="${HOME}/bin"
readonly CONFIG_DIR="${HOME}/.config/claude-update"
readonly CONFIG_FILE="${CONFIG_DIR}/config"
readonly LOG_DIR="${HOME}/.local/share/claude-update"
readonly PID_FILE="${LOG_DIR}/${SCRIPT_NAME}.pid"
readonly LOCK_FILE="${LOG_DIR}/${SCRIPT_NAME}.lock"

# デフォルト設定
readonly DEFAULT_PROJECTS_ROOT="${HOME}/projects"
readonly DEFAULT_LOG_LEVEL="INFO"
readonly DEFAULT_INTERVAL="3600"

# マーカー
readonly MARKER_START="## ⚠️ グローバル設定の読み込み (自動追加)"

# 追加するヘッダー
readonly HEADER="${MARKER_START}

**このプロジェクトで作業を開始する前に、必ず以下を実行してください:**

\`\`\`bash
view ~/.claude/CLAUDE.md
\`\`\`

グローバル設定を読み込んでから、以下のプロジェクト固有設定を参照してください。

---

"

# ========================================
# ロギング
# ========================================
log_level_value() {
  case "$1" in
    ERROR) echo 0 ;;
    WARN)  echo 1 ;;
    INFO)  echo 2 ;;
    DEBUG) echo 3 ;;
    *) echo 2 ;;
  esac
}

log() {
  local level="$1"
  shift
  local message="$*"
  local timestamp
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  
  local current_level="${LOG_LEVEL:-INFO}"
  local level_value
  level_value=$(log_level_value "${level}")
  local current_value
  current_value=$(log_level_value "${current_level}")
  
  if [[ ${level_value} -le ${current_value} ]]; then
    local color="${RESET}"
    case "${level}" in
      ERROR) color="${RED}${BOLD}" ;;
      WARN)  color="${YELLOW}" ;;
      INFO)  color="${GREEN}" ;;
      DEBUG) color="${CYAN}" ;;
    esac
    
    printf "${color}[%s] [%-5s]${RESET} %s\n" "${timestamp}" "${level}" "${message}"
  fi
}

log_error() { log ERROR "$@" >&2; }
log_warn()  { log WARN "$@"; }
log_info()  { log INFO "$@"; }
log_debug() { log DEBUG "$@"; }

# ========================================
# クリーンアップ
# ========================================
cleanup() {
  local exit_code=$?
  
  if [[ -f "${LOCK_FILE}" ]]; then
    rm -f "${LOCK_FILE}" 2>/dev/null || true
  fi
  
  if [[ -f "${PID_FILE}" ]]; then
    local saved_pid
    saved_pid=$(cat "${PID_FILE}" 2>/dev/null || echo "")
    if [[ "${saved_pid}" == "$$" ]]; then
      rm -f "${PID_FILE}" 2>/dev/null || true
    fi
  fi
  
  exit "${exit_code}"
}

error_handler() {
  log_error "予期しないエラーが発生しました (行: $1)"
}

trap cleanup EXIT
trap 'error_handler ${LINENO}' ERR

# ========================================
# 設定管理
# ========================================
load_config() {
  if [[ -f "${CONFIG_FILE}" ]]; then
    # shellcheck source=/dev/null
    source "${CONFIG_FILE}"
  fi
  
  # デフォルト値の設定
  PROJECTS_DIRS=("${PROJECTS_DIRS[@]:-${DEFAULT_PROJECTS_ROOT}}")
  LOG_LEVEL="${LOG_LEVEL:-${DEFAULT_LOG_LEVEL}}"
  INTERVAL="${INTERVAL:-${DEFAULT_INTERVAL}}"
}

create_default_config() {
  mkdir -p "${CONFIG_DIR}"
  
  cat > "${CONFIG_FILE}" <<'EOF'
# Claude Update 設定ファイル

# プロジェクトディレクトリ(配列)
PROJECTS_DIRS=(
  "${HOME}/projects"
)

# ログレベル (ERROR, WARN, INFO, DEBUG)
LOG_LEVEL="INFO"

# スケジューラー実行間隔(秒)
INTERVAL=3600
EOF
  
  log_info "設定ファイルを作成しました: ${CONFIG_FILE}"
}

# ========================================
# ロック管理
# ========================================
acquire_lock() {
  mkdir -p "${LOG_DIR}"
  
  local max_wait=10
  local wait_count=0
  
  while [[ -f "${LOCK_FILE}" ]]; do
    if [[ ${wait_count} -ge ${max_wait} ]]; then
      log_error "別のプロセスが実行中です"
      return 1
    fi
    sleep 1
    ((wait_count++))
  done
  
  if [[ -f "${PID_FILE}" ]]; then
    local existing_pid
    existing_pid=$(cat "${PID_FILE}" 2>/dev/null || echo "")
    
    if [[ -n "${existing_pid}" ]] && kill -0 "${existing_pid}" 2>/dev/null; then
      log_error "既に実行中です (PID: ${existing_pid})"
      return 1
    else
      rm -f "${PID_FILE}" 2>/dev/null || true
    fi
  fi
  
  echo $$ > "${PID_FILE}"
  touch "${LOCK_FILE}"
  return 0
}

# ========================================
# ファイル処理
# ========================================
is_header_present() {
  local file="$1"
  grep -qF "${MARKER_START}" "${file}" 2>/dev/null
}

update_file() {
  local file="$1"
  local temp_file
  
  temp_file="$(mktemp "${file}.XXXXXX")"
  
  {
    printf '%s' "${HEADER}"
    cat "${file}"
  } > "${temp_file}"
  
  chmod --reference="${file}" "${temp_file}" 2>/dev/null || \
    chmod "$(stat -c '%a' "${file}" 2>/dev/null || stat -f '%Lp' "${file}")" "${temp_file}" 2>/dev/null || true
  
  mv -f "${temp_file}" "${file}"
  return 0
}

# ========================================
# メイン処理
# ========================================
process_directory() {
  local projects_root="$1"
  local dry_run="$2"
  local count_total=0
  local count_updated=0
  local count_skipped=0
  local count_errors=0
  
  if [[ ! -d "${projects_root}" ]]; then
    log_error "ディレクトリが存在しません: ${projects_root}"
    return 1
  fi
  
  log_info "検索中: ${projects_root}"
  
  while IFS= read -r -d '' claude_file; do
    ((count_total++))
    
    local project_dir
    project_dir="$(dirname "$(dirname "${claude_file}")")"
    local project_name
    project_name="$(basename "${project_dir}")"
    
    if [[ ! -r "${claude_file}" ]] || [[ ! -w "${claude_file}" ]]; then
      log_error "アクセス権限エラー: ${project_name}"
      ((count_errors++))
      continue
    fi
    
    if is_header_present "${claude_file}"; then
      log_debug "スキップ: ${project_name}"
      ((count_skipped++))
      continue
    fi
    
    if [[ "${dry_run}" == "true" ]]; then
      printf "${BLUE}[DRY-RUN]${RESET} 更新予定: ${BOLD}%s${RESET}\n" "${project_name}"
      ((count_updated++))
      continue
    fi
    
    if update_file "${claude_file}"; then
      printf "${GREEN}✅${RESET} 更新完了: ${BOLD}%s${RESET}\n" "${project_name}"
      ((count_updated++))
    else
      log_error "更新失敗: ${project_name}"
      ((count_errors++))
    fi
    
  done < <(find "${projects_root}" -maxdepth 3 -type f -path "*/.claude/CLAUDE.md" -print0 2>/dev/null)
  
  # サマリー
  echo ""
  printf "${CYAN}${BOLD}=========================================${RESET}\n"
  printf "${BOLD}処理結果${RESET}\n"
  printf "  検出:     ${BOLD}%3d${RESET} プロジェクト\n" "${count_total}"
  printf "  ${GREEN}更新:     %3d${RESET} プロジェクト\n" "${count_updated}"
  printf "  スキップ: ${BOLD}%3d${RESET} プロジェクト\n" "${count_skipped}"
  if [[ ${count_errors} -gt 0 ]]; then
    printf "  ${RED}エラー:   %3d${RESET} プロジェクト\n" "${count_errors}"
  fi
  printf "${CYAN}${BOLD}=========================================${RESET}\n"
  
  [[ ${count_errors} -eq 0 ]]
}

process_all() {
  local dry_run="$1"
  local failed=0
  
  load_config
  
  for dir in "${PROJECTS_DIRS[@]}"; do
    if ! process_directory "${dir}" "${dry_run}"; then
      ((failed++))
    fi
  done
  
  return "${failed}"
}

# ========================================
# インストール/アンインストール
# ========================================
install_script() {
  log_info "インストールを開始します..."
  
  # ディレクトリ作成
  mkdir -p "${INSTALL_DIR}"
  mkdir -p "${CONFIG_DIR}"
  mkdir -p "${LOG_DIR}"
  
  # スクリプト自身をコピー
  local target="${INSTALL_DIR}/${SCRIPT_NAME}"
  cp "$0" "${target}"
  chmod +x "${target}"
  
  log_info "スクリプトをインストールしました: ${target}"
  
  # 設定ファイル作成
  if [[ ! -f "${CONFIG_FILE}" ]]; then
    create_default_config
  else
    log_info "設定ファイルは既に存在します: ${CONFIG_FILE}"
  fi
  
  # OS判定とスケジューラー設定
  if [[ "$(uname)" == "Darwin" ]]; then
    install_launchd
  else
    install_cron_hint
  fi
  
  printf "\n${GREEN}${BOLD}✅ インストールが完了しました${RESET}\n\n"
  printf "次のステップ:\n"
  printf "  1. 設定編集: ${CYAN}%s${RESET}\n" "${CONFIG_FILE}"
  printf "  2. テスト実行: ${CYAN}%s -d${RESET}\n" "${SCRIPT_NAME}"
  printf "  3. 本番実行: ${CYAN}%s${RESET}\n" "${SCRIPT_NAME}"
}

install_launchd() {
  local username
  username="$(whoami)"
  local plist_file="${HOME}/Library/LaunchAgents/com.${username}.update-claude-config.plist"
  
  mkdir -p "${HOME}/Library/LaunchAgents"
  mkdir -p "${HOME}/Library/Logs"
  
  cat > "${plist_file}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.${username}.update-claude-config</string>
    <key>ProgramArguments</key>
    <array>
        <string>${INSTALL_DIR}/${SCRIPT_NAME}</string>
        <string>--scheduled</string>
    </array>
    <key>StartInterval</key>
    <integer>${DEFAULT_INTERVAL}</integer>
    <key>StandardOutPath</key>
    <string>${HOME}/Library/Logs/claude-update.log</string>
    <key>StandardErrorPath</key>
    <string>${HOME}/Library/Logs/claude-update-error.log</string>
    <key>RunAtLoad</key>
    <true/>
    <key>ProcessType</key>
    <string>Background</string>
    <key>Nice</key>
    <integer>10</integer>
</dict>
</plist>
EOF
  
  if launchctl load "${plist_file}" 2>/dev/null; then
    log_info "launchdをセットアップしました"
  else
    log_warn "launchdの登録に失敗しました。手動で登録してください:"
    log_warn "  launchctl load ${plist_file}"
  fi
}

install_cron_hint() {
  log_info "Linux環境を検出しました"
  printf "\n${YELLOW}cronをセットアップしてください:${RESET}\n"
  printf "  ${CYAN}crontab -e${RESET}\n\n"
  printf "以下を追加:\n"
  printf "  ${CYAN}0 * * * * %s --scheduled${RESET}\n" "${INSTALL_DIR}/${SCRIPT_NAME}"
}

uninstall_script() {
  log_warn "アンインストールを開始します..."
  
  # スケジューラー削除
  if [[ "$(uname)" == "Darwin" ]]; then
    local username
    username="$(whoami)"
    local plist_file="${HOME}/Library/LaunchAgents/com.${username}.update-claude-config.plist"
    
    if [[ -f "${plist_file}" ]]; then
      launchctl unload "${plist_file}" 2>/dev/null || true
      rm -f "${plist_file}"
      log_info "launchdを削除しました"
    fi
  fi
  
  # スクリプト削除
  local target="${INSTALL_DIR}/${SCRIPT_NAME}"
  if [[ -f "${target}" ]]; then
    rm -f "${target}"
    log_info "スクリプトを削除しました: ${target}"
  fi
  
  # 設定・ログは残す(念のため)
  printf "\n${YELLOW}注意: 設定ファイルとログは削除していません${RESET}\n"
  printf "  設定: ${CYAN}%s${RESET}\n" "${CONFIG_DIR}"
  printf "  ログ: ${CYAN}%s${RESET}\n" "${LOG_DIR}"
  printf "\n完全に削除する場合は手動で削除してください\n"
}

# ========================================
# 使用方法
# ========================================
usage() {
  cat <<EOF
${BOLD}${SCRIPT_NAME}${RESET} - CLAUDE.mdグローバル設定参照を自動追加

${BOLD}使用方法:${RESET}
  ${SCRIPT_NAME} [OPTIONS] [DIR]

${BOLD}OPTIONS:${RESET}
  -d, --dry-run       ドライランモード(変更しない)
  -i, --install       インストール
  -u, --uninstall     アンインストール
  -s, --scheduled     スケジューラーからの実行(内部用)
  -h, --help          ヘルプ表示
  -v, --version       バージョン表示

${BOLD}ARGUMENTS:${RESET}
  DIR                 プロジェクトディレクトリ
                      (省略時: 設定ファイルの全ディレクトリ)

${BOLD}環境変数:${RESET}
  LOG_LEVEL           ログレベル (ERROR/WARN/INFO/DEBUG)

${BOLD}例:${RESET}
  ${CYAN}${SCRIPT_NAME} --install${RESET}           インストール
  ${CYAN}${SCRIPT_NAME} -d${RESET}                  ドライラン(全ディレクトリ)
  ${CYAN}${SCRIPT_NAME} ~/projects${RESET}          指定ディレクトリを処理
  ${CYAN}LOG_LEVEL=DEBUG ${SCRIPT_NAME}${RESET}     デバッグモード

${BOLD}設定ファイル:${RESET}
  ${CYAN}${CONFIG_FILE}${RESET}

EOF
}

# ========================================
# メイン
# ========================================
main() {
  local dry_run="false"
  local specific_dir=""
  local scheduled="false"
  
  # 引数解析
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -d|--dry-run)
        dry_run="true"
        shift
        ;;
      -i|--install)
        install_script
        exit 0
        ;;
      -u|--uninstall)
        uninstall_script
        exit 0
        ;;
      -s|--scheduled)
        scheduled="true"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      -v|--version)
        echo "${SCRIPT_NAME} version ${VERSION}"
        exit 0
        ;;
      -*)
        log_error "不明なオプション: $1"
        usage
        exit 1
        ;;
      *)
        specific_dir="$1"
        shift
        ;;
    esac
  done
  
  # ロック取得
  if ! acquire_lock; then
    exit 1
  fi
  
  # 実行
  if [[ -n "${specific_dir}" ]]; then
    process_directory "${specific_dir}" "${dry_run}"
  else
    process_all "${dry_run}"
  fi
}

# スクリプトとして実行された場合のみ
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi

