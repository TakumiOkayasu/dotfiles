#!/bin/sh
# shellcheck shell=bash
# Claude Code Statusline
# 3-line display: session info, 5h usage, 7d usage
# ref) https://zenn.dev/suthio/articles/f832922e18f994

# Re-exec with bash (required for (( )), +=, < <(), printf -v)
if [ -z "$BASH_VERSION" ]; then
    exec bash "$0" "$@"
fi

set -euo pipefail

input=$(cat)

# ── Platform detection ──
case "$(uname -s)" in Darwin) _IS_BSD=true ;; *) _IS_BSD=false ;; esac

DISPLAY_TZ=$(
    if [ -n "${TZ:-}" ]; then echo "$TZ"
    elif [ -L /etc/localtime ]; then readlink /etc/localtime | sed 's|.*/zoneinfo/||'
    elif [ -f /etc/timezone ]; then cat /etc/timezone
    else echo "UTC"
    fi
)

# Date helpers (BSD/GNU auto-detection)
_date_parse() {
    local iso=$1
    if $_IS_BSD; then
        TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "$iso" +%s 2>/dev/null
    else
        TZ=UTC date -d "$iso" +%s 2>/dev/null
    fi
}

_date_format() {
    local epoch=$1 fmt=$2
    if $_IS_BSD; then
        LC_ALL=en_US.UTF-8 TZ="$DISPLAY_TZ" date -r "$epoch" +"$fmt" 2>/dev/null
    else
        LC_ALL=en_US.UTF-8 TZ="$DISPLAY_TZ" date -d "@$epoch" +"$fmt" 2>/dev/null
    fi
}

# ── Colors ──
GREEN="\033[38;2;151;201;195m"
YELLOW="\033[38;2;229;192;123m"
RED="\033[38;2;224;108;117m"
GRAY="\033[38;2;74;88;92m"
RESET="\033[0m"

color_for_pct() {
    local pct=$1
    if (( pct >= 80 )); then
        printf '%s' "$RED"
    elif (( pct >= 50 )); then
        printf '%s' "$YELLOW"
    else
        printf '%s' "$GREEN"
    fi
}

# ── Progress bar (10 segments) ──
progress_bar() {
    local pct=$1
    (( pct > 100 )) && pct=100
    local filled=$(( pct / 10 ))
    local empty=$(( 10 - filled ))
    local color
    color=$(color_for_pct "$pct")
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="▰"; done
    for ((i=0; i<empty; i++)); do bar+="▱"; done
    printf '%b%s%b' "$color" "$bar" "$RESET"
}

# ── Line 1: Session info ──
read -r model used_pct lines_added lines_removed cwd < <(
    echo "$input" | jq -r '[
        (.model.display_name // ""),
        (.context_window.used_percentage // ""),
        (.cost.total_lines_added // 0),
        (.cost.total_lines_removed // 0),
        (.workspace.current_dir // "")
    ] | @tsv'
)

# Context percentage (integer)
ctx_int=0
if [ -n "$used_pct" ]; then
    printf -v ctx_int "%.0f" "$used_pct" 2>/dev/null || ctx_int="${used_pct%%.*}"
fi
ctx_color=$(color_for_pct "$ctx_int")

# Git branch
git_branch=""
if [ -n "$cwd" ] && git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
    git_branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
fi

sep="${GRAY} │ ${RESET}"

line1="🤖 ${model}${sep}${ctx_color}📊 ${ctx_int}%${RESET}${sep}✏️ +${lines_added}/-${lines_removed}"
if [ -n "$git_branch" ]; then
    line1+="${sep}🔀 ${git_branch}"
fi

# ── Usage API (OAuth, cached 60s) ──
CACHE_FILE="${TMPDIR:-/tmp}/claude-usage-cache-$(id -u).json"
CACHE_TTL=60

fetch_usage() {
    # Get OAuth token (env var override → macOS Keychain)
    local access_token=""

    if [ -n "${CLAUDE_OAUTH_TOKEN:-}" ]; then
        access_token="$CLAUDE_OAUTH_TOKEN"
    elif command -v security >/dev/null 2>&1; then
        local token
        token=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null || true)
        if [ -n "$token" ]; then
            access_token=$(printf '%s\n' "$token" | jq -r '.claudeAiOauth.accessToken // .accessToken // .access_token // empty' 2>/dev/null || true)
        fi
    fi

    if [ -z "$access_token" ]; then
        return 1
    fi

    local response
    response=$(curl -sf --max-time 5 \
        -H "Authorization: Bearer ${access_token}" \
        -H "anthropic-beta: oauth-2025-04-20" \
        "https://api.anthropic.com/api/oauth/usage" 2>/dev/null) || return 1

    # Write cache with timestamp
    local now
    now=$(date +%s)
    (umask 077 && echo "$response" | jq --arg ts "$now" '. + {cached_at: ($ts | tonumber)}' > "$CACHE_FILE" 2>/dev/null)
    echo "$response"
}

get_usage() {
    local now
    now=$(date +%s)

    # Check cache
    if [ -f "$CACHE_FILE" ]; then
        local cached_at
        cached_at=$(jq -r '.cached_at // 0' "$CACHE_FILE" 2>/dev/null || echo "0")
        local age=$(( now - cached_at ))
        if (( age < CACHE_TTL )); then
            jq -r 'del(.cached_at)' "$CACHE_FILE" 2>/dev/null
            return 0
        fi
    fi

    fetch_usage
}

# Convert ISO 8601 to epoch seconds
iso_to_epoch() {
    local stripped="${1%%.*}"
    _date_parse "$stripped" || echo ""
}

# Format reset time: ISO → localized string
format_reset_time() {
    local iso_time=$1 fmt=$2
    local epoch
    epoch=$(iso_to_epoch "$iso_time")
    [ -z "$epoch" ] && return
    _date_format "$epoch" "$fmt" | sed 's/AM/am/;s/PM/pm/'
}

line2=""
line3=""

usage_json=$(get_usage 2>/dev/null || true)

if [ -n "$usage_json" ]; then
    read -r five_util five_reset seven_util seven_reset < <(
        echo "$usage_json" | jq -r '[
            (.five_hour.utilization // ""),
            (.five_hour.resets_at // ""),
            (.seven_day.utilization // ""),
            (.seven_day.resets_at // "")
        ] | @tsv'
    )

    if [ -n "$five_util" ]; then
        printf -v five_int "%.0f" "$five_util" 2>/dev/null || five_int="${five_util%%.*}"
        five_color=$(color_for_pct "$five_int")
        five_bar=$(progress_bar "$five_int")
        five_reset_str=""
        if [ -n "$five_reset" ]; then
            five_reset_str=$(format_reset_time "$five_reset" "Resets %-l%p ($DISPLAY_TZ)")
        fi
        line2="${five_color}⏱ 5h${RESET}  ${five_bar}  ${five_color}${five_int}%${RESET}"
        if [ -n "$five_reset_str" ]; then
            line2+="    ${GRAY}${five_reset_str}${RESET}"
        fi
    fi

    if [ -n "$seven_util" ]; then
        printf -v seven_int "%.0f" "$seven_util" 2>/dev/null || seven_int="${seven_util%%.*}"
        seven_color=$(color_for_pct "$seven_int")
        seven_bar=$(progress_bar "$seven_int")
        seven_reset_str=""
        if [ -n "$seven_reset" ]; then
            seven_reset_str=$(format_reset_time "$seven_reset" "Resets %b %-d at %-l%p ($DISPLAY_TZ)")
        fi
        line3="${seven_color}📅 7d${RESET}  ${seven_bar}  ${seven_color}${seven_int}%${RESET}"
        if [ -n "$seven_reset_str" ]; then
            line3+="    ${GRAY}${seven_reset_str}${RESET}"
        fi
    fi
fi

# ── Output ──
printf '%b' "$line1"
if [ -n "$line2" ]; then
    printf '\n%b' "$line2"
fi
if [ -n "$line3" ]; then
    printf '\n%b' "$line3"
fi
