#!/usr/bin/env bash

set -euo pipefail

DATA=$(cat)

if command -v jq &>/dev/null; then
  JQ=jq
elif command -v jaq &>/dev/null; then
  JQ=jaq
else
  echo "jq or jaq required" >&2
  exit 1
fi

BRAILLE=(' ' '⣀' '⣄' '⣤' '⣦' '⣶' '⣷' '⣿')
R=$'\033[0m'
DIM=$'\033[2m'

gradient() {
  local pct=$1
  if (( pct < 50 )); then
    local r=$(( pct * 51 / 10 ))
    printf '\033[38;2;%d;200;80m' "$r"
  else
    local g=$(( 200 - (pct - 50) * 4 ))
    (( g < 0 )) && g=0
    printf '\033[38;2;255;%d;60m' "$g"
  fi
}

braille_bar() {
  local pct=$1 width=${2:-8}
  (( pct < 0 )) && pct=0
  (( pct > 100 )) && pct=100
  local bar=''
  for (( i = 0; i < width; i++ )); do
    local seg_start_num=$(( i * 100 ))
    local seg_end_num=$(( (i + 1) * 100 ))
    local level_num=$(( pct * width ))
    if (( level_num >= seg_end_num )); then
      bar+="${BRAILLE[7]}"
    elif (( level_num <= seg_start_num )); then
      bar+="${BRAILLE[0]}"
    else
      local frac_idx=$(( (level_num - seg_start_num) * 7 / (seg_end_num - seg_start_num) ))
      (( frac_idx > 7 )) && frac_idx=7
      bar+="${BRAILLE[$frac_idx]}"
    fi
  done
  printf '%s' "$bar"
}

fmt() {
  local label=$1 pct=$2
  local p
  p=$(printf '%.0f' "$pct")
  local color
  color=$(gradient "$p")
  local bar
  bar=$(braille_bar "$p")
  printf '%s%s%s %s%s%s %d%%' "$DIM" "$label" "$R" "$color" "$bar" "$R" "$p"
}

jq_val() {
  printf '%s' "$DATA" | "$JQ" -r "$1 // empty"
}

model=$(jq_val '.model.display_name')
[[ -z "$model" ]] && model='Claude'

parts=("$model")

ctx=$(jq_val '.context_window.used_percentage')
if [[ -n "$ctx" ]]; then
  parts+=("$(fmt 'ctx' "$ctx")")
fi

five=$(jq_val '.rate_limits.five_hour.used_percentage')
if [[ -n "$five" ]]; then
  parts+=("$(fmt '5h' "$five")")
fi

week=$(jq_val '.rate_limits.seven_day.used_percentage')
if [[ -n "$week" ]]; then
  parts+=("$(fmt '7d' "$week")")
fi

sep=" ${DIM}│${R} "
result=""
for (( i = 0; i < ${#parts[@]}; i++ )); do
  (( i > 0 )) && result+="$sep"
  result+="${parts[$i]}"
done
printf '%s' "$result"
