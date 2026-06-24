#!/bin/sh

set -eu

DEFAULT_CONTEXT_WINDOW_SIZE=200000
USABLE_CONTEXT_RATIO=0.8

usage() {
    cat <<'EOF'
Usage: model-context.sh [--context-window-size N] [--id ID] [--display-name NAME] [model identifier...]
EOF
}

trim() {
    awk '{
        sub(/^[[:space:]]+/, "")
        sub(/[[:space:]]+$/, "")
        print
    }'
}

valid_window_size() {
    awk -v value="$1" '
        BEGIN {
            if (value !~ /^[[:space:]]*[+]?[0-9]+([.][0-9]+)?[[:space:]]*$/) {
                exit 1
            }
            numeric = value + 0
            if (numeric <= 0) {
                exit 1
            }
            if (numeric == int(numeric)) {
                printf "%d\n", numeric
            } else {
                printf "%s\n", numeric
            }
        }
    '
}

round_context_tokens() {
    value=$(printf '%s\n' "$1" | tr -d ',_')
    unit=$(printf '%s\n' "$2" | tr '[:upper:]' '[:lower:]')

    case "$unit" in
        m) multiplier=1000000 ;;
        k) multiplier=1000 ;;
        *) return 1 ;;
    esac

    awk -v value="$value" -v multiplier="$multiplier" '
        BEGIN {
            numeric = value + 0
            if (numeric <= 0) {
                exit 1
            }
            printf "%d\n", int(numeric * multiplier + 0.5)
        }
    '
}

parse_context_window_size() {
    model_identifier="$1"

    delimited=$(printf '%s\n' "$model_identifier" \
        | grep -Eio '[([][[:space:]]*[0-9][0-9,_]*([.][0-9]+)?[[:space:]]*[km][[:space:]]*[])]' \
        | head -n 1 || true)
    if [ -n "$delimited" ]; then
        delimited=$(printf '%s\n' "$delimited" \
            | sed -nE 's/^[([][[:space:]]*([0-9][0-9,_]*([.][0-9]+)?)[[:space:]]*([kKmM])[[:space:]]*[])]$/\1 \3/p')
        delimited_value=${delimited% *}
        delimited_unit=${delimited##* }
        round_context_tokens "$delimited_value" "$delimited_unit" && return 0
    fi

    context=$(printf '%s\n' "$model_identifier" \
        | grep -Eio '(^|[^[:alnum:]_])[0-9][0-9,_]*([.][0-9]+)?[[:space:]]*[km]([[:space:]]*(token[[:space:]]*)?context)?([^[:alnum:]_]|$)' \
        | head -n 1 || true)
    if [ -n "$context" ]; then
        context=$(printf '%s\n' "$context" \
            | sed -nE 's/^([^[:alnum:]_])?([0-9][0-9,_]*([.][0-9]+)?)[[:space:]]*([kKmM]).*$/\2 \4/p')
        context_value=${context% *}
        context_unit=${context##* }
        round_context_tokens "$context_value" "$context_unit" && return 0
    fi

    return 1
}

print_config() {
    max_tokens="$1"
    usable_tokens=$(awk -v max_tokens="$max_tokens" -v ratio="$USABLE_CONTEXT_RATIO" 'BEGIN { printf "%d\n", int(max_tokens * ratio) }')
    printf '{"maxTokens":%s,"usableTokens":%s}\n' "$max_tokens" "$usable_tokens"
}

context_window_size=""
model_id=""
display_name=""
model_identifier=""

while [ "$#" -gt 0 ]; do
    case "$1" in
        --context-window-size)
            shift
            [ "$#" -gt 0 ] || { usage >&2; exit 2; }
            context_window_size="$1"
            ;;
        --id)
            shift
            [ "$#" -gt 0 ] || { usage >&2; exit 2; }
            model_id=$(printf '%s\n' "$1" | trim)
            ;;
        --display-name)
            shift
            [ "$#" -gt 0 ] || { usage >&2; exit 2; }
            display_name=$(printf '%s\n' "$1" | trim)
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            while [ "$#" -gt 0 ]; do
                if [ -z "$model_identifier" ]; then
                    model_identifier="$1"
                else
                    model_identifier="${model_identifier} $1"
                fi
                shift
            done
            break
            ;;
        --*)
            printf 'Unknown option: %s\n' "$1" >&2
            usage >&2
            exit 2
            ;;
        *)
            if [ -z "$model_identifier" ]; then
                model_identifier="$1"
            else
                model_identifier="${model_identifier} $1"
            fi
            ;;
    esac
    shift
done

if [ -n "$context_window_size" ]; then
    if max_tokens=$(valid_window_size "$context_window_size"); then
        print_config "$max_tokens"
        exit 0
    fi
fi

model_identifier=$(printf '%s\n' "$model_identifier" | trim)
if [ -z "$model_identifier" ]; then
    if [ -n "$model_id" ] && [ -n "$display_name" ]; then
        model_identifier="${model_id} ${display_name}"
    elif [ -n "$model_id" ]; then
        model_identifier="$model_id"
    else
        model_identifier="$display_name"
    fi
fi

if [ -n "$model_identifier" ]; then
    if max_tokens=$(parse_context_window_size "$model_identifier"); then
        print_config "$max_tokens"
        exit 0
    fi
fi

print_config "$DEFAULT_CONTEXT_WINDOW_SIZE"
