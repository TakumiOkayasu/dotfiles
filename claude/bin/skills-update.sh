#!/bin/sh
# shellcheck shell=bash
# skills-update.sh - Vendor skills auto-updater with 2-layer security
#
# Layer 1: Docker isolation (git fetch/pull in container)
# Layer 2: Pattern scan (prompt injection, command exec, credential theft)
#
# Usage:
#   skills-update.sh [options]
#
# Options:
#   --force    Bypass 24h throttle
#   --quiet    Suppress "no update" messages
#   --dry-run  Scan only, do not pull
#   -h,--help  Show help
#
# Exit codes:
#   0  Updated or no update needed
#   1  Security issue detected (update blocked)
#   2  Error (Docker unavailable, network error, etc.)

# Re-exec with bash (required for (( )), +=, local arrays)
if [ -z "$BASH_VERSION" ]; then
    exec bash "$0" "$@"
fi

set -euo pipefail

# ── Constants ──
VENDOR_DIR="$HOME/.claude/vendor"
DOCKER_IMAGE="alpine/git:2.47.2"
STAMP_FILE="${TMPDIR:-/tmp}/skills-update-stamp-$(id -u)"
THROTTLE_SECONDS=86400  # 24h

# ── Options ──
FORCE=false
QUIET=false
DRY_RUN=false

# ── Dangerous patterns (Layer 2) ──
# Each line is a grep -Ei pattern with description
PATTERNS=(
    # Command execution
    'curl\s.*\|\s*sh'
    'wget\s.*\|\s*sh'
    '\beval\b\s'
    '\bexec\b\s'
    'base64\s+-d'
    'base64\s+--decode'
    'python[23]?\s+-c'
    'node\s+-e'
    '\bsh\s+-c\b'
    # Credential access
    '[~]\/\.ssh'
    '[~]\/\.aws'
    '[~]\/\.gnupg'
    'security\s+find-generic'
    '/etc/shadow'
    '/etc/passwd'
    'PRIVATE.KEY'
    # Prompt injection
    'ignore\s+(previous|above|all\s+prior)\s+instructions'
    'disregard\s+(previous|above|all)'
    'override\s+instructions'
    'you\s+are\s+now\s+in\s+.*\s+mode'
    'forget\s+(everything|all|your)\s+(above|previous|prior)'
    'system\s*prompt'
    'new\s+instructions'
    # Binary / suspicious
    '^Binary\s+files\s+.*\s+differ$'
    'https?://[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+'
)

# ── Functions ──

show_help() {
    sed -n '2,/^$/{ s/^# //; s/^#$//; p; }' "$0"
}

log() {
    if ! $QUIET || [ "${2:-}" = "force" ]; then
        echo "$1"
    fi
}

warn() {
    echo "⚠️  $1" >&2
}

error() {
    echo "❌ $1" >&2
}

should_update() {
    $FORCE && return 0
    [ ! -f "$STAMP_FILE" ] && return 0

    local now stamp age
    now=$(date +%s)

    # BSD stat / GNU stat
    if stat -f %m "$STAMP_FILE" >/dev/null 2>&1; then
        stamp=$(stat -f %m "$STAMP_FILE")
    else
        stamp=$(stat -c %Y "$STAMP_FILE" 2>/dev/null || echo "0")
    fi

    age=$(( now - stamp ))
    (( age >= THROTTLE_SECONDS ))
}

# Layer 2: Scan diff content for dangerous patterns
scan_diff() {
    local diff_content="$1"
    local repo_name="$2"
    local found=false
    local combined_pattern=""

    # Build combined pattern
    for pattern in "${PATTERNS[@]}"; do
        if [ -n "$combined_pattern" ]; then
            combined_pattern+="|"
        fi
        combined_pattern+="($pattern)"
    done

    local matches
    matches=$(echo "$diff_content" | grep -Eni "$combined_pattern" 2>/dev/null || true)

    if [ -n "$matches" ]; then
        found=true
        error "Security scan FAILED for $repo_name"
        echo "  Matched patterns:" >&2
        echo "$matches" | head -10 | while IFS= read -r line; do
            echo "    $line" >&2
        done
        local total
        total=$(echo "$matches" | wc -l | tr -d ' ')
        if (( total > 10 )); then
            echo "    ... and $((total - 10)) more matches" >&2
        fi
    fi

    $found && return 1
    return 0
}

# Detect default branch for a repo (inside Docker)
get_default_branch() {
    local repo_dir="$1"
    docker run --rm \
        -v "${repo_dir}:/repo:ro" \
        -w /repo \
        "$DOCKER_IMAGE" \
        symbolic-ref refs/remotes/origin/HEAD 2>/dev/null \
        | sed 's|refs/remotes/origin/||' || echo "main"
}

# Update a single vendor repo
update_repo() {
    local repo_dir="$1"
    local repo_name
    repo_name=$(basename "$repo_dir")

    # Validate
    if [ ! -d "${repo_dir}/.git" ]; then
        return 0
    fi

    log "🔄 Checking $repo_name..."

    # Layer 1: Docker fetch
    if ! docker run --rm \
        -v "${repo_dir}:/repo" \
        -w /repo \
        "$DOCKER_IMAGE" \
        fetch origin 2>/dev/null; then
        warn "$repo_name: fetch failed (network?)"
        return 2
    fi

    # Detect branch
    local branch
    branch=$(get_default_branch "$repo_dir")

    # Get diff (Docker, read-only)
    local diff_output
    diff_output=$(docker run --rm \
        -v "${repo_dir}:/repo:ro" \
        -w /repo \
        "$DOCKER_IMAGE" \
        diff "HEAD..origin/${branch}" --no-color 2>/dev/null || true)

    # No changes
    if [ -z "$diff_output" ]; then
        log "  ✅ $repo_name: up to date"
        return 0
    fi

    # Layer 2: Pattern scan (on host, diff content only)
    if ! scan_diff "$diff_output" "$repo_name"; then
        error "$repo_name: update BLOCKED. Review manually:"
        error "  cd $repo_dir && git diff HEAD..origin/${branch}"
        return 1
    fi

    # Dry run stops here
    if $DRY_RUN; then
        log "  🔍 $repo_name: changes available (dry-run, not pulling)"
        return 0
    fi

    # Layer 1: Docker pull (ff-only for safety)
    if ! docker run --rm \
        -v "${repo_dir}:/repo" \
        -w /repo \
        "$DOCKER_IMAGE" \
        pull --ff-only origin "$branch" 2>/dev/null; then
        warn "$repo_name: pull --ff-only failed (diverged?)"
        return 2
    fi

    log "  ✅ $repo_name: updated" "force"
    return 0
}

main() {
    # Parse args
    while [ $# -gt 0 ]; do
        case "$1" in
            --force)   FORCE=true ;;
            --quiet)   QUIET=true ;;
            --dry-run) DRY_RUN=true ;;
            -h|--help) show_help; exit 0 ;;
            *) error "Unknown option: $1"; exit 2 ;;
        esac
        shift
    done

    # Check vendor dir
    if [ ! -d "$VENDOR_DIR" ]; then
        log "No vendor directory"
        exit 0
    fi

    # Check for repos
    local has_repos=false
    for d in "$VENDOR_DIR"/*/; do
        [ -d "${d}.git" ] && has_repos=true && break
    done
    if ! $has_repos; then
        log "No vendor repos found"
        exit 0
    fi

    # Throttle check
    if ! should_update; then
        log "⏭  Skipped (last check < 24h, use --force to override)"
        exit 0
    fi

    # Check Docker
    if ! command -v docker >/dev/null 2>&1; then
        warn "Docker required for secure vendor updates"
        exit 2
    fi

    if ! docker info >/dev/null 2>&1; then
        warn "Docker daemon not running"
        exit 2
    fi

    # Update each repo
    local final_exit=0
    for repo_dir in "$VENDOR_DIR"/*/; do
        [ ! -d "${repo_dir}.git" ] && continue

        local rc=0
        update_repo "$repo_dir" || rc=$?

        case $rc in
            1) final_exit=1 ;;               # Security issue → always propagate
            2) [ $final_exit -ne 1 ] && final_exit=2 ;;  # Error (lower priority)
        esac
    done

    # Update stamp on success
    if [ $final_exit -eq 0 ]; then
        touch "$STAMP_FILE"
    fi

    exit $final_exit
}

main "$@"
