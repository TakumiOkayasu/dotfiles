#!/bin/sh
# dev-environment-docker-enforce.sh
# PreToolUse hook: パッケージマネージャー/環境構築コマンドのローカル実行をブロック
# Docker経由での実行のみ許可

set -eu

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    cat <<'EOF'
dev-environment-docker-enforce.sh - パッケージマネージャーのローカル実行をブロック

使い方:
  echo '{"tool_name":"Bash","tool_input":{"command":"npm install"}}' | ./dev-environment-docker-enforce.sh

説明:
  Claude Code の PreToolUse hook として動作し、npm, pip, cargo 等の
  パッケージマネージャーをローカルで実行しようとした場合にブロックします。
  docker 経由での実行は許可されます。

依存関係:
  jaq または jq が必要です (jaq優先)
  - macOS: brew install jaq
  - Ubuntu/Debian: apt install jq (または cargo install jaq)
  - Arch: pacman -S jq (または paru -S jaq)
  - Windows: scoop install jaq (または winget install jqlang.jq)
EOF
    exit 0
fi

# stdin がない場合のタイムアウト対策 (POSIX互換)
if [ -t 0 ]; then
    echo "エラー: 標準入力がありません" >&2
    echo "使い方: echo '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"npm install\"}}' | $0" >&2
    echo "ヘルプ: $0 --help" >&2
    exit 1
fi

INPUT=$(cat)

# jaq優先、jqフォールバック
JQ=$(command -v jaq || command -v jq || echo "jq")

echo "$INPUT" | $JQ -r '
  if .tool_name != "Bash" or (.tool_input.command // "") == "" then
    {"decision":"approve"}
  elif .tool_input.command | test("^\\s*docker") then
    {"decision":"approve"}
  elif .tool_input.command | test("^\\s*(npm|npx|yarn|pnpm|corepack|bun|deno|pip3?|uv|poetry|pipenv|conda|pyenv|virtualenv|gem|bundler?|rbenv|rvm|composer|cargo|rustup|mvn|gradlew?|\\./gradlew|sbt|dotnet|nuget|apt(-get)?|yum|dnf|pacman|brew|snap|flatpak|apk|zypper|emerge|port|nvm|fnm|asdf|mise|volta|sdkman|jabba|phpenv|goenv)(\\s|$)") then
    {"decision":"block","reason":"❌ `\(.tool_input.command | split(" ")[0])` はローカル実行禁止です。`docker` 環境で実行してください。"}
  elif .tool_input.command | test("^\\s*python3?\\s+-m\\s+(venv|pip)(\\s|$)") then
    {"decision":"block","reason":"❌ `python` はローカル実行禁止です。`docker` 環境で実行してください。"}
  elif .tool_input.command | test("^\\s*go\\s+(mod|get|install)(\\s|$)") then
    {"decision":"block","reason":"❌ `go` はローカル実行禁止です。`docker` 環境で実行してください。"}
  else
    {"decision":"approve"}
  end
'

