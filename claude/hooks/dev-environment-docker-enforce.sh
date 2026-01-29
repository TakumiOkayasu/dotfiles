#!/bin/sh
# dev-environment-docker-enforce.sh
# PreToolUse hook: パッケージマネージャー/環境構築コマンドのローカル実行をブロック
# Docker経由での実行のみ許可

set -eu

INPUT=$(cat)

# jqで判定とJSON出力を一括処理
echo "$INPUT" | jq -r '
  # Bash以外 or 空コマンド → 許可
  if .tool_name != "Bash" or (.tool_input.command // "") == "" then
    {"decision":"approve"}
  
  # docker で始まる → 許可
  elif .tool_input.command | test("^\\s*docker") then
    {"decision":"approve"}
  
  # ブロック対象パターン
  elif .tool_input.command | test("^\\s*(npm|npx|yarn|pnpm|corepack|bun|deno|pip3?|uv|poetry|pipenv|conda|pyenv|virtualenv|gem|bundler?|rbenv|rvm|composer|cargo|rustup|mvn|gradlew?|\\./gradlew|sbt|dotnet|nuget|apt(-get)?|yum|dnf|pacman|brew|snap|flatpak|apk|zypper|emerge|port|nvm|fnm|asdf|mise|volta|sdkman|jabba|phpenv|goenv)(\\s|$)") then
    {"decision":"block","reason":"❌ `\(.tool_input.command | split(" ")[0])` はローカル実行禁止です。`docker` 環境で実行してください。"}
  
  # python -m venv/pip
  elif .tool_input.command | test("^\\s*python3?\\s+-m\\s+(venv|pip)(\\s|$)") then
    {"decision":"block","reason":"❌ `python` はローカル実行禁止です。`docker` 環境で実行してください。"}
  
  # go mod/get/install
  elif .tool_input.command | test("^\\s*go\\s+(mod|get|install)(\\s|$)") then
    {"decision":"block","reason":"❌ `go` はローカル実行禁止です。`docker` 環境で実行してください。"}
  
  else
    {"decision":"approve"}
  end
'

