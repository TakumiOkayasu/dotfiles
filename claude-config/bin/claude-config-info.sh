#!/bin/sh
# claude-config-info.sh - Claude Code 設定情報を出力するユーティリティ
#
# 用途:
#   - SessionStart hook から呼び出し
#   - 手動でのデバッグ・確認
#   - 他のスクリプトからの再利用
#
# 配置先: claude-config/bin/claude-config-info.sh
#         -> ~/.claude/bin/claude-config-info.sh (symlink)
#
# 使い方:
#   claude-config-info.sh [オプション]
#
# オプション:
#   --all       すべての情報を表示 (デフォルト)
#   --hooks     hooks 一覧のみ
#   --skills    skills 一覧のみ
#   --failures  failure_log 情報のみ
#   --json      JSON形式で出力
#   --quiet     ヘッダーなしで出力

set -eu

# ============================================================================
# 設定
# ============================================================================

GLOBAL_SETTINGS="$HOME/.claude/settings.json"
PROJECT_SETTINGS=".claude/settings.json"
PROJECT_LOCAL_SETTINGS=".claude/settings.local.json"
SKILLS_DIR="$HOME/.claude/skills"
FAILURE_LOG="claude_tmp/failure_log.md"

# オプション
SHOW_HOOKS=false
SHOW_SKILLS=false
SHOW_FAILURES=false
OUTPUT_JSON=false
QUIET=false

# ============================================================================
# 引数解析
# ============================================================================

parse_args() {
    if [ $# -eq 0 ]; then
        SHOW_HOOKS=true
        SHOW_SKILLS=true
        SHOW_FAILURES=true
        return
    fi

    while [ $# -gt 0 ]; do
        case "$1" in
            --all)
                SHOW_HOOKS=true
                SHOW_SKILLS=true
                SHOW_FAILURES=true
                ;;
            --hooks)
                SHOW_HOOKS=true
                ;;
            --skills)
                SHOW_SKILLS=true
                ;;
            --failures)
                SHOW_FAILURES=true
                ;;
            --json)
                OUTPUT_JSON=true
                ;;
            --quiet|-q)
                QUIET=true
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                exit 1
                ;;
        esac
        shift
    done
}

show_help() {
    cat << 'EOF'
claude-config-info.sh - Claude Code 設定情報を出力

使い方:
    claude-config-info.sh [オプション]

オプション:
    --all       すべての情報を表示 (デフォルト)
    --hooks     hooks 一覧のみ
    --skills    skills 一覧のみ
    --failures  failure_log 情報のみ
    --json      JSON形式で出力
    --quiet     ヘッダーなしで出力
    -h, --help  このヘルプを表示

例:
    claude-config-info.sh              # すべて表示
    claude-config-info.sh --hooks      # hooks のみ
    claude-config-info.sh --json       # JSON形式で出力
EOF
}

# ============================================================================
# Hooks 抽出
# ============================================================================

# 単一ファイルから hooks を抽出
extract_hooks_from_file() {
    file="$1"

    if [ ! -f "$file" ]; then
        return 0
    fi

    if ! command -v jq >/dev/null 2>&1; then
        return 0
    fi

    if ! jq -e '.hooks' "$file" >/dev/null 2>&1; then
        return 0
    fi

    for event in SessionStart PreToolUse PostToolUse; do
        hooks_json=$(jq -r ".hooks.${event} // empty" "$file" 2>/dev/null)

        if [ -z "$hooks_json" ] || [ "$hooks_json" = "null" ]; then
            continue
        fi

        count=$(echo "$hooks_json" | jq 'length')

        i=0
        while [ "$i" -lt "$count" ]; do
            matcher=$(echo "$hooks_json" | jq -r ".[$i].matcher // \"\"")
            [ -z "$matcher" ] && matcher="*"

            commands=$(echo "$hooks_json" | jq -r ".[$i].hooks[].command" 2>/dev/null | \
                xargs -I{} basename {} 2>/dev/null | \
                tr '\n' ',' | \
                sed 's/,$//')

            if [ -n "$commands" ]; then
                echo "${event}|${matcher}|${commands}|${file}"
            fi
            i=$((i + 1))
        done
    done
}

# すべての設定ファイルから hooks を収集
collect_all_hooks() {
    extract_hooks_from_file "$GLOBAL_SETTINGS"
    extract_hooks_from_file "$PROJECT_SETTINGS"
    extract_hooks_from_file "$PROJECT_LOCAL_SETTINGS"
}

# hooks をテキスト形式で出力
print_hooks_text() {
    current_file=""

    while IFS='|' read -r event matcher commands file; do
        [ -z "$event" ] && continue

        if [ "$file" != "$current_file" ]; then
            current_file="$file"
            case "$file" in
                "$GLOBAL_SETTINGS") label="Global: ~/.claude/settings.json" ;;
                "$PROJECT_SETTINGS") label="Project: .claude/settings.json" ;;
                "$PROJECT_LOCAL_SETTINGS") label="Local: .claude/settings.local.json" ;;
                *) label="$file" ;;
            esac
            echo "  [$label]"
        fi

        echo "    ${event}[${matcher}]: ${commands}"
    done
}

# hooks を JSON 形式で出力
print_hooks_json() {
    echo "["
    first=true

    while IFS='|' read -r event matcher commands file; do
        [ -z "$event" ] && continue

        if [ "$first" = "true" ]; then
            first=false
        else
            echo ","
        fi

        # commands をカンマ区切りから JSON 配列に変換
        commands_json=$(echo "$commands" | tr ',' '\n' | jq -R . | jq -s .)

        printf '  {"event":"%s","matcher":"%s","commands":%s,"file":"%s"}' \
            "$event" "$matcher" "$commands_json" "$file"
    done

    echo ""
    echo "]"
}

# ============================================================================
# Skills 抽出
# ============================================================================

collect_skills() {
    if [ ! -d "$SKILLS_DIR" ]; then
        return 0
    fi

    # macOS互換: -printf がないので別の方法
    find "$SKILLS_DIR" -maxdepth 2 -name "SKILL.md" 2>/dev/null | while read -r skill_file; do
        dirname "$skill_file" | xargs basename
    done | sort
}

print_skills_text() {
    skills=$(collect_skills)
    count=$(echo "$skills" | grep -c . 2>/dev/null || echo "0")

    if [ "$count" -eq 0 ] || [ -z "$skills" ]; then
        echo "  No skills found in ~/.claude/skills/"
        return
    fi

    echo "  ${count} skill(s) in ~/.claude/skills/"

    # 最大10個まで表示
    echo -n "  "
    echo "$skills" | head -10 | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g'
    echo ""

    if [ "$count" -gt 10 ]; then
        echo "  ... and $((count - 10)) more"
    fi
}

print_skills_json() {
    skills=$(collect_skills)

    if [ -z "$skills" ]; then
        echo '{"count": 0, "skills": []}'
    else
        echo "$skills" | jq -R . | jq -s '{count: length, skills: .}'
    fi
}

# ============================================================================
# Failure Log 抽出
# ============================================================================

get_failure_info() {
    if [ ! -f "$FAILURE_LOG" ]; then
        echo "0|none"
        return
    fi

    count=$(grep -c "^## " "$FAILURE_LOG" 2>/dev/null || echo "0")

    latest=""
    if [ "$count" -gt 0 ]; then
        latest=$(grep "^## " "$FAILURE_LOG" 2>/dev/null | tail -1 | sed 's/^## //')
    fi

    echo "${count}|${latest}"
}

print_failures_text() {
    info=$(get_failure_info)
    count="${info%%|*}"
    latest="${info#*|}"

    if [ "$count" -eq 0 ]; then
        echo "  No failures recorded"
    else
        echo "  ${count} failure(s) recorded in $FAILURE_LOG"
        if [ -n "$latest" ] && [ "$latest" != "none" ]; then
            echo "  Latest: ${latest}"
        fi
    fi
}

print_failures_json() {
    info=$(get_failure_info)
    count="${info%%|*}"
    latest="${info#*|}"

    if [ "$latest" = "none" ]; then
        latest=""
    fi

    printf '{"count":%d,"file":"%s","latest":"%s"}' "$count" "$FAILURE_LOG" "$latest"
}

# ============================================================================
# メイン出力
# ============================================================================

main() {
    parse_args "$@"

    if [ "$OUTPUT_JSON" = "true" ]; then
        echo "{"

        first=true

        if [ "$SHOW_HOOKS" = "true" ]; then
            echo '  "hooks":'
            collect_all_hooks | print_hooks_json | sed 's/^/  /'
            first=false
        fi

        if [ "$SHOW_SKILLS" = "true" ]; then
            [ "$first" = "false" ] && echo ","
            echo -n '  "skills": '
            print_skills_json
            first=false
        fi

        if [ "$SHOW_FAILURES" = "true" ]; then
            [ "$first" = "false" ] && echo ","
            echo -n '  "failures": '
            print_failures_json
            echo ""
        fi

        echo "}"
    else
        if [ "$SHOW_HOOKS" = "true" ]; then
            [ "$QUIET" = "false" ] && echo "🔗 ACTIVE HOOKS:"
            if ! command -v jq >/dev/null 2>&1; then
                echo "  (jq not installed - cannot parse settings.json)"
            else
                collect_all_hooks | print_hooks_text
            fi
            [ "$QUIET" = "false" ] && echo ""
        fi

        if [ "$SHOW_SKILLS" = "true" ]; then
            [ "$QUIET" = "false" ] && echo "📚 AVAILABLE SKILLS:"
            print_skills_text
            [ "$QUIET" = "false" ] && echo ""
        fi

        if [ "$SHOW_FAILURES" = "true" ]; then
            [ "$QUIET" = "false" ] && echo "⚠️  FAILURE LOG:"
            print_failures_text
            [ "$QUIET" = "false" ] && echo ""
        fi
    fi
}

main "$@"
