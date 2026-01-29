#!/bin/sh
# dev-environment-docker-enforce.sh
# PreToolUse hook: パッケージマネージャー/環境構築コマンドのローカル実行をブロック
# Docker経由での実行のみ許可

set -eu

# jaq優先、jqフォールバック
if command -v jaq >/dev/null 2>&1; then
  JQ_CMD="jaq"
elif command -v jq >/dev/null 2>&1; then
  JQ_CMD="jq"
else
  echo '{"decision":"block","reason":"❌ jaq/jq が見つかりません。インストールしてください。"}'
  exit 0
fi

INPUT=$(cat)

echo "$INPUT" | $JQ_CMD -r '
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

