#!/bin/sh
# hierarchical-architecture-naming-check.sh - 階層型アーキテクチャの命名規則チェック
#
# 使い方 (手動実行):
#   echo '{"tool_input":{"file_path":"src/SensorProvider.cpp"}}' | ./hierarchical-architecture-naming-check.sh
#
# Claude Code hook として自動実行される場合は stdin から JSON を受け取る
#
# チェック対象: .cpp, .hpp, .h, .ts, .tsx, .py, .java, .cs, .rs ファイル
# チェック内容:
#   1. 同一型の連番getter (get_xxx_1_yyy, get_xxx_2_yyy)
#   2. get_プレフィックスなしのaccessor/provider getter
#   3. サブコンポーネント層へのContext/Provider/Accessorサフィックス混入

set -e

# 手動実行時のヘルプ
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    cat <<'EOF'
hierarchical-architecture-naming-check.sh - 命名規則チェック

使い方:
  echo '{"tool_input":{"file_path":"src/MyProvider.cpp"}}' | ./hierarchical-architecture-naming-check.sh

説明:
  Claude Code の PostToolUse hook として動作し、
  階層型アーキテクチャの命名規則違反を検出してフィードバックします。

チェック項目:
  1. 同一型の連番getter (get_xxx_1_yyy, get_xxx_2_yyy) → パラメータ化すべき
  2. get_プレフィックスなしのaccessor/provider返却メソッド
  3. サブコンポーネント(BLE*, HTTP*等)へのContext/Provider/Accessorサフィックス

依存関係:
  jaq または jq が必要です (jaq優先)
EOF
    exit 0
fi

# stdin がない場合のタイムアウト対策
if [ -t 0 ]; then
    echo "エラー: 標準入力がありません" >&2
    echo "使い方: echo '{\"tool_input\":{\"file_path\":\"src/MyFile.cpp\"}}' | $0" >&2
    exit 1
fi

# Read JSON input from stdin
INPUT=$(cat)

# jaq優先、jqフォールバック
JQ=$(command -v jaq || command -v jq || echo "jq")

# Extract file path from tool_input
FILE_PATH=$(echo "$INPUT" | $JQ -r '.tool_input.file_path // ""' 2>/dev/null || echo "")

# 対象拡張子のみチェック
case "$FILE_PATH" in
    *.cpp|*.hpp|*.h|*.cc|*.hh|*.ts|*.tsx|*.py|*.java|*.cs|*.rs|*.kt|*.go)
        ;;
    *)
        exit 0
        ;;
esac

# ファイルが存在しない場合はスキップ
if [ ! -f "$FILE_PATH" ]; then
    exit 0
fi

# マーカーファイル判定 - プロジェクトが opt-in している場合のみチェック
CWD=$(echo "$INPUT" | $JQ -r '.cwd // ""' 2>/dev/null || echo "")
if [ -n "$CWD" ] && [ ! -f "${CWD}/.hierarchical-architecture" ]; then
    exit 0
fi

WARNINGS=""

# --- チェック1: 同一型の連番getter ---
# パターン: get_xxx_1_yyy, get_xxx_2_yyy (数字が含まれる連番getter)
NUMBERED=$(perl -ne 'print "$.:$_" if /get_[a-z]+_[0-9]+_[a-z]+/' "$FILE_PATH" 2>/dev/null | head -5)
if [ -n "$NUMBERED" ]; then
    WARNINGS="${WARNINGS}[命名規則] 同一型の連番getterを検出。パラメータ化を検討してください:\n${NUMBERED}\n\n"
fi

# --- チェック2: get_プレフィックスなしのaccessor/provider返却 ---
# パターン: xxx_accessor() や xxx_provider() で get_ が付いていない
# ただし get_xxx_accessor / get_xxx_provider は正しいのでスキップ
NOGETTER=$(perl -ne 'print "$.:$_" if /\b[a-z_]+_(accessor|provider|context)\s*\(/ && !/\bget_/' "$FILE_PATH" 2>/dev/null | head -5)
if [ -n "$NOGETTER" ]; then
    WARNINGS="${WARNINGS}[命名規則] get_プレフィックスなしのgetter候補を検出:\n${NOGETTER}\nhierarchical-architecture スキルの命名規則を確認してください。\n\n"
fi

# --- チェック3: サブコンポーネント層への不適切なサフィックス ---
# BLE*, HTTP*, MQTT* 等のドメイン概念に Context/Provider/Accessor が付いている
SUBCOMP=$(perl -ne 'print "$.:$_" if /\b(BLE|HTTP|MQTT|USB|SPI|I2C|UART|CAN|GPIO|ADC|DAC|PWM|DMA|RTC|WDT|NFC|RFID)(Service|Characteristic|Request|Response|Header|Packet|Frame|Message|Channel|Endpoint)(Context|Provider|Accessor)\b/' "$FILE_PATH" 2>/dev/null | head -5)
if [ -n "$SUBCOMP" ]; then
    WARNINGS="${WARNINGS}[命名規則] サブコンポーネント層にContext/Provider/Accessorサフィックスを検出:\n${SUBCOMP}\nドメイン標準用語のみを使用してください。\n\n"
fi

# 警告がなければ正常終了
if [ -z "$WARNINGS" ]; then
    exit 0
fi

# 警告をClaude Codeにフィードバック
# additionalContext でClaude Codeに認識させる
ESCAPED_WARNINGS=$(printf '%s' "$WARNINGS" | perl -pe 's/\\/\\\\/g; s/"/\\"/g; s/\n/\\n/g')
ESCAPED_PATH=$(printf '%s' "$FILE_PATH" | perl -pe 's/\\/\\\\/g; s/"/\\"/g')

cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "[hierarchical-architecture 命名規則チェック] ${ESCAPED_PATH} で以下の命名規則違反の可能性を検出しました:\\n\\n${ESCAPED_WARNINGS}hierarchical-architecture スキルの命名規則を参照し、必要に応じて修正してください。"
  }
}
EOF

exit 0
