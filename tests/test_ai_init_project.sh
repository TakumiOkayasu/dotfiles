#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd -P)
script="$repo_root/bin/ai-init-project"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

assert_file_contains() {
    file="$1"
    expected="$2"
    grep -Fq -- "$expected" "$file" || {
        printf 'expected %s to contain: %s\n' "$file" "$expected" >&2
        exit 1
    }
}

project="$work/project"
mkdir -p "$project"
git -C "$project" init -q
git -C "$project" remote add origin git@github.com:example/example-project.git

(
    cd "$project"
    bash "$script"
)

for path in .ai .ai/state .ai/inbox .ai/knowledge; do
    [[ -d "$project/$path" ]] || {
        printf 'missing directory: %s\n' "$path" >&2
        exit 1
    }
done

assert_file_contains "$project/.ai/manifest.toml" 'schema_version = 1'
assert_file_contains "$project/.ai/manifest.toml" 'project_id = "github.com/example/example-project"'
assert_file_contains "$project/.ai/manifest.toml" 'enabled = false'

# Idempotent when the directory belongs to this workflow.
(
    cd "$project"
    bash "$script"
)

# Dry-run must not create state.
dry="$work/dry"
mkdir -p "$dry"
git -C "$dry" init -q
(
    cd "$dry"
    output=$(bash "$script" --dry-run)
    [[ ! -e .ai ]]
    [[ "$output" == *'.ai/manifest.toml'* ]]
)

# Refuse to claim an existing foreign .ai directory.
foreign="$work/foreign"
mkdir -p "$foreign/.ai"
git -C "$foreign" init -q
if (
    cd "$foreign"
    bash "$script" >/dev/null 2>&1
); then
    echo 'expected foreign .ai directory to be rejected' >&2
    exit 1
fi

printf 'test_ai_init_project: PASS\n'
