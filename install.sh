#!/bin/bash
#
# dotfiles installer
# Creates symbolic links for dotfiles to home directory
#
# Usage:
#   ./install.sh              # Interactive mode (default)
#   ./install.sh -f           # Force install all
#   ./install.sh -n           # Dry run (preview only)
#   ./install.sh -u           # Uninstall
#

set -eu

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

# ============================================================================
# Configuration
# ============================================================================

# Mode flags
MODE_INTERACTIVE=true
MODE_DRY_RUN=false
MODE_UNINSTALL=false

# Counters
COUNT_CREATED=0
COUNT_SKIPPED=0
COUNT_BACKUP=0
COUNT_REMOVED=0

# Selected files to install (indices into FILE_DEFS)
SELECTED_INDICES=""

# ============================================================================
# Color Output
# ============================================================================

if [ -t 1 ]; then
    COLOR_GREEN='\033[0;32m'
    COLOR_YELLOW='\033[0;33m'
    COLOR_RED='\033[0;31m'
    COLOR_BLUE='\033[0;34m'
    COLOR_CYAN='\033[0;36m'
    COLOR_BOLD='\033[1m'
    COLOR_RESET='\033[0m'
else
    COLOR_GREEN=''
    COLOR_YELLOW=''
    COLOR_RED=''
    COLOR_BLUE=''
    COLOR_CYAN=''
    COLOR_BOLD=''
    COLOR_RESET=''
fi

print_success() { printf "${COLOR_GREEN}✓${COLOR_RESET} %s\n" "$1"; }
print_skip()    { printf "${COLOR_YELLOW}○${COLOR_RESET} %s\n" "$1"; }
print_error()   { printf "${COLOR_RED}✗${COLOR_RESET} %s\n" "$1"; }
print_info()    { printf "${COLOR_BLUE}→${COLOR_RESET} %s\n" "$1"; }
print_header()  { printf "\n${COLOR_BOLD}${COLOR_CYAN}%s${COLOR_RESET}\n" "$1"; }

# ============================================================================
# File Definitions with Categories and Descriptions
# ============================================================================

# Format: "category|source|destination|description"
# Using | as delimiter to avoid issues with colons in paths
FILE_COUNT=7

file_def() {
    case "$1" in
        0) echo "shell|.bashrc|$HOME/.bashrc|Bash configuration and prompt settings" ;;
        1) echo "shell|.shell_aliases|$HOME/.shell_aliases|Shell aliases for common commands" ;;
        2) echo "git|.gitconfig|$HOME/.gitconfig|Git configuration (user, aliases, colors)" ;;
        3) echo "git|.git-completion.bash|$HOME/.git-completion.bash|Git command completion" ;;
        4) echo "git|.git-prompt.sh|$HOME/.git-prompt.sh|Git branch info in prompt" ;;
        5) echo "git|.gitignore|$HOME/.config/git/ignore|Global gitignore patterns" ;;
        6) echo "vim|.vimrc|$HOME/.vimrc|Vim editor configuration" ;;
    esac
}

# Category list
CATEGORIES="shell git vim claude"

get_category_desc() {
    case "$1" in
        shell)  echo "Shell configuration (bashrc, aliases)" ;;
        git)    echo "Git configuration and completion" ;;
        vim)    echo "Vim editor settings" ;;
        claude) echo "Claude Code AI assistant settings" ;;
    esac
}

# ============================================================================
# Helper Functions
# ============================================================================

get_field() {
    local def="$1"
    local field="$2"
    case "$field" in
        category)    echo "$def" | cut -d'|' -f1 ;;
        source)      echo "$def" | cut -d'|' -f2 ;;
        dest)        echo "$def" | cut -d'|' -f3 ;;
        description) echo "$def" | cut -d'|' -f4 ;;
    esac
}

# Get file indices by category
get_indices_by_category() {
    local cat="$1"
    # claude category is handled separately via git ls-files
    if [ "$cat" = "claude" ]; then
        echo ""
        return
    fi
    local i=0
    local result=""
    while [ $i -lt $FILE_COUNT ]; do
        local def
        def=$(file_def $i)
        local fcat
        fcat=$(get_field "$def" category)
        if [ "$fcat" = "$cat" ]; then
            result="$result $i"
        fi
        i=$((i + 1))
    done
    echo "$result"
}

# Get claude-config files from git
get_claude_config_files() {
    cd "$DOTFILES_DIR" || return
    git ls-files claude-config/ 2>/dev/null || true
}

# Check if index is in selected list
is_selected() {
    local idx="$1"
    case " $SELECTED_INDICES " in
        *" $idx "*) return 0 ;;
        *) return 1 ;;
    esac
}

add_to_selected() {
    local idx="$1"
    if ! is_selected "$idx"; then
        SELECTED_INDICES="$SELECTED_INDICES $idx"
    fi
}

# Check if claude category is selected (uses special marker "claude")
is_claude_selected() {
    case " $SELECTED_INDICES " in
        *" claude "*) return 0 ;;
        *) return 1 ;;
    esac
}

# ============================================================================
# Core Functions
# ============================================================================

create_link() {
    local src="$DOTFILES_DIR/$1"
    local dest="$2"

    if [ ! -e "$src" ]; then
        print_skip "Skip: $src (not found)"
        COUNT_SKIPPED=$((COUNT_SKIPPED + 1))
        return
    fi

    local dest_dir
    dest_dir="$(dirname "$dest")"

    if $MODE_DRY_RUN; then
        print_info "[DRY RUN] Would create: $dest -> $src"
        if [ -e "$dest" ] && [ ! -L "$dest" ]; then
            print_info "[DRY RUN] Would backup: $dest -> ${dest}.bak"
        fi
        return
    fi

    [ -d "$dest_dir" ] || mkdir -p "$dest_dir"

    if [ -L "$dest" ]; then
        rm "$dest"
    elif [ -e "$dest" ]; then
        print_info "Backup: $dest -> ${dest}.bak"
        mv "$dest" "${dest}.bak"
        COUNT_BACKUP=$((COUNT_BACKUP + 1))
    fi

    ln -s "$src" "$dest"
    print_success "Created: $dest"
    echo "         -> $src"
    COUNT_CREATED=$((COUNT_CREATED + 1))
}

remove_link() {
    local src="$DOTFILES_DIR/$1"
    local dest="$2"

    if [ ! -L "$dest" ]; then
        print_skip "Skip: $dest (not a symlink)"
        COUNT_SKIPPED=$((COUNT_SKIPPED + 1))
        return
    fi

    local target
    target="$(readlink "$dest")"

    # Only remove if link points to our dotfiles
    if [ "$target" != "$src" ]; then
        print_skip "Skip: $dest (points to different location)"
        COUNT_SKIPPED=$((COUNT_SKIPPED + 1))
        return
    fi

    if $MODE_DRY_RUN; then
        print_info "[DRY RUN] Would remove: $dest"
        return
    fi

    rm "$dest"
    print_success "Removed: $dest"
    COUNT_REMOVED=$((COUNT_REMOVED + 1))

    # Restore backup if exists
    if [ -e "${dest}.bak" ]; then
        mv "${dest}.bak" "$dest"
        print_info "Restored: ${dest}.bak -> $dest"
    fi
}

# Install Claude config files from claude-config/ using git ls-files
install_claude_config() {
    local files
    files=$(get_claude_config_files)

    if [ -z "$files" ]; then
        print_skip "No claude-config files found in git"
        return
    fi

    # Ensure ~/.claude and ~/.claude/commands directories exist
    if $MODE_DRY_RUN; then
        print_info "[DRY RUN] Would create: $HOME/.claude (if not exists)"
        print_info "[DRY RUN] Would create: $HOME/.claude/commands (if not exists)"
    else
        mkdir -p "$HOME/.claude"
        mkdir -p "$HOME/.claude/commands"
    fi

    for file in $files; do
        # Remove "claude-config/" prefix to get relative path
        local relative="${file#claude-config/}"
        local src="$DOTFILES_DIR/$file"
        local dest

        # skills/ directory maps to ~/.claude/commands/
        if echo "$relative" | grep -q "^skills/"; then
            # Extract skill name and file from skills/skill-name/SKILL.md
            local skill_path="${relative#skills/}"
            local skill_name="${skill_path%%/*}"
            local skill_file="${skill_path#*/}"
            # Map skills/skill-name/SKILL.md to commands/SKILL-skill-name.md
            if [ "$skill_file" = "SKILL.md" ]; then
                dest="$HOME/.claude/commands/SKILL-${skill_name}.md"
            else
                # For other files in skills directory, use the original structure
                dest="$HOME/.claude/commands/${skill_name}-${skill_file}"
            fi
        else
            dest="$HOME/.claude/$relative"
        fi

        create_link "$file" "$dest"
    done
}

# Uninstall Claude config files
uninstall_claude_config() {
    local files
    files=$(get_claude_config_files)

    if [ -z "$files" ]; then
        return
    fi

    for file in $files; do
        local relative="${file#claude-config/}"
        local dest

        # skills/ directory maps to ~/.claude/commands/
        if echo "$relative" | grep -q "^skills/"; then
            local skill_path="${relative#skills/}"
            local skill_name="${skill_path%%/*}"
            local skill_file="${skill_path#*/}"
            if [ "$skill_file" = "SKILL.md" ]; then
                dest="$HOME/.claude/commands/SKILL-${skill_name}.md"
            else
                dest="$HOME/.claude/commands/${skill_name}-${skill_file}"
            fi
        else
            dest="$HOME/.claude/$relative"
        fi

        remove_link "$file" "$dest"
    done
}

# ============================================================================
# Interactive Mode
# ============================================================================

show_category_menu() {
    print_header "Select categories to install"
    echo ""
    local i=1
    for cat in $CATEGORIES; do
        local desc
        desc=$(get_category_desc "$cat")
        printf "  ${COLOR_BOLD}%d)${COLOR_RESET} %s\n" "$i" "$desc"
        i=$((i + 1))
    done
    echo ""
    printf "  ${COLOR_BOLD}a)${COLOR_RESET} All categories\n"
    printf "  ${COLOR_BOLD}q)${COLOR_RESET} Quit\n"
    echo ""
}

show_files_in_category() {
    local cat="$1"
    local desc
    desc=$(get_category_desc "$cat")
    print_header "Files in $desc"
    echo ""

    if [ "$cat" = "claude" ]; then
        # Show claude-config files from git
        local i=1
        local files
        files=$(get_claude_config_files)
        for file in $files; do
            local relative="${file#claude-config/}"
            local display_dest

            # skills/ directory maps to ~/.claude/commands/
            if echo "$relative" | grep -q "^skills/"; then
                local skill_path="${relative#skills/}"
                local skill_name="${skill_path%%/*}"
                local skill_file="${skill_path#*/}"
                if [ "$skill_file" = "SKILL.md" ]; then
                    display_dest="~/.claude/commands/SKILL-${skill_name}.md"
                else
                    display_dest="~/.claude/commands/${skill_name}-${skill_file}"
                fi
            else
                display_dest="~/.claude/$relative"
            fi

            printf "  ${COLOR_BOLD}%d)${COLOR_RESET} %s\n" "$i" "$relative"
            printf "     ${COLOR_CYAN}-> %s${COLOR_RESET}\n" "$display_dest"
            i=$((i + 1))
        done
    else
        local i=1
        local indices
        indices=$(get_indices_by_category "$cat")
        for idx in $indices; do
            local def
            def=$(file_def "$idx")
            local src
            src=$(get_field "$def" source)
            local fdesc
            fdesc=$(get_field "$def" description)
            printf "  ${COLOR_BOLD}%d)${COLOR_RESET} %s\n" "$i" "$src"
            printf "     ${COLOR_CYAN}%s${COLOR_RESET}\n" "$fdesc"
            i=$((i + 1))
        done
    fi
    echo ""
    printf "  ${COLOR_BOLD}a)${COLOR_RESET} All files in this category\n"
    printf "  ${COLOR_BOLD}b)${COLOR_RESET} Back to category menu\n"
    echo ""
}

select_files_interactive() {
    while true; do
        show_category_menu
        printf "Select category (1-4/a/q): "
        read -r choice

        case "$choice" in
            q|Q)
                echo "Cancelled."
                exit 0
                ;;
            a|A)
                # Select all files
                local i=0
                while [ $i -lt $FILE_COUNT ]; do
                    add_to_selected $i
                    i=$((i + 1))
                done
                # Also select claude
                SELECTED_INDICES="$SELECTED_INDICES claude"
                return
                ;;
            [1-4])
                local cat_num=$((choice - 1))
                local cat_count=0
                local selected_cat=""
                for cat in $CATEGORIES; do
                    if [ $cat_count -eq $cat_num ]; then
                        selected_cat="$cat"
                        break
                    fi
                    cat_count=$((cat_count + 1))
                done
                if [ -n "$selected_cat" ]; then
                    select_from_category "$selected_cat"
                fi
                ;;
            *)
                print_error "Invalid selection"
                ;;
        esac

        # If we have selections, ask if done
        if [ -n "$SELECTED_INDICES" ]; then
            printf "\nContinue selecting? [Y/n]: "
            read -r cont
            case "$cont" in
                n|N) return ;;
            esac
        fi
    done
}

select_from_category() {
    local cat="$1"

    if [ "$cat" = "claude" ]; then
        # For claude, we select all or nothing
        show_files_in_category "$cat"
        printf "Install all Claude config files? [Y/n]: "
        read -r choice
        case "$choice" in
            n|N)
                return
                ;;
            *)
                SELECTED_INDICES="$SELECTED_INDICES claude"
                print_success "Added all Claude config files"
                return
                ;;
        esac
    fi

    local indices
    indices=$(get_indices_by_category "$cat")

    # Count files in category
    local file_count=0
    for _ in $indices; do
        file_count=$((file_count + 1))
    done

    while true; do
        show_files_in_category "$cat"
        printf "Select files (1-%d/a/b): " "$file_count"
        read -r choice

        case "$choice" in
            b|B)
                return
                ;;
            a|A)
                for idx in $indices; do
                    add_to_selected "$idx"
                done
                local desc
                desc=$(get_category_desc "$cat")
                print_success "Added all files from $desc"
                return
                ;;
            [1-9]*)
                if [ "$choice" -ge 1 ] && [ "$choice" -le "$file_count" ]; then
                    local target_num=$((choice - 1))
                    local current=0
                    for idx in $indices; do
                        if [ $current -eq $target_num ]; then
                            add_to_selected "$idx"
                            local def
                            def=$(file_def "$idx")
                            local src
                            src=$(get_field "$def" source)
                            print_success "Added: $src"
                            break
                        fi
                        current=$((current + 1))
                    done
                else
                    print_error "Invalid selection"
                fi
                ;;
            *)
                print_error "Invalid selection"
                ;;
        esac
    done
}

confirm_installation() {
    if [ -z "$SELECTED_INDICES" ]; then
        print_error "No files selected"
        exit 1
    fi

    print_header "Files to install"
    echo ""

    # Show regular dotfiles
    for idx in $SELECTED_INDICES; do
        # Skip the "claude" marker
        [ "$idx" = "claude" ] && continue

        local def
        def=$(file_def "$idx")
        local src
        src=$(get_field "$def" source)
        local dest
        dest=$(get_field "$def" dest)
        printf "  ${COLOR_GREEN}+${COLOR_RESET} %s -> %s\n" "$src" "$dest"
    done

    # Show claude config files if selected
    if is_claude_selected; then
        echo ""
        printf "  ${COLOR_CYAN}Claude Code config (from claude-config/):${COLOR_RESET}\n"
        local files
        files=$(get_claude_config_files)
        for file in $files; do
            local relative="${file#claude-config/}"
            local display_dest

            # skills/ directory maps to ~/.claude/commands/
            if echo "$relative" | grep -q "^skills/"; then
                local skill_path="${relative#skills/}"
                local skill_name="${skill_path%%/*}"
                local skill_file="${skill_path#*/}"
                if [ "$skill_file" = "SKILL.md" ]; then
                    display_dest="~/.claude/commands/SKILL-${skill_name}.md"
                else
                    display_dest="~/.claude/commands/${skill_name}-${skill_file}"
                fi
            else
                display_dest="~/.claude/$relative"
            fi

            printf "    + %s -> %s\n" "$relative" "$display_dest"
        done
    fi

    echo ""
    printf "Proceed with installation? [Y/n]: "
    read -r confirm
    case "$confirm" in
        n|N)
            echo "Cancelled."
            exit 0
            ;;
    esac
}

# ============================================================================
# Main Functions
# ============================================================================

install_files() {
    print_header "Installing dotfiles from: $DOTFILES_DIR"

    # Install regular dotfiles
    for idx in $SELECTED_INDICES; do
        # Skip the "claude" marker
        [ "$idx" = "claude" ] && continue

        local def
        def=$(file_def "$idx")
        local src
        src=$(get_field "$def" source)
        local dest
        dest=$(get_field "$def" dest)

        create_link "$src" "$dest"
    done

    # Install Claude config if selected
    if is_claude_selected; then
        install_claude_config
    fi
}

uninstall_files() {
    print_header "Uninstalling dotfiles"

    # Uninstall regular dotfiles
    local i=0
    while [ $i -lt $FILE_COUNT ]; do
        local def
        def=$(file_def $i)
        local src
        src=$(get_field "$def" source)
        local dest
        dest=$(get_field "$def" dest)
        remove_link "$src" "$dest"
        i=$((i + 1))
    done

    # Uninstall Claude config
    uninstall_claude_config
}

show_summary() {
    print_header "Summary"
    echo ""
    if $MODE_UNINSTALL; then
        printf "  Removed: ${COLOR_GREEN}%d${COLOR_RESET}\n" "$COUNT_REMOVED"
    else
        printf "  Created: ${COLOR_GREEN}%d${COLOR_RESET}\n" "$COUNT_CREATED"
        printf "  Backups: ${COLOR_YELLOW}%d${COLOR_RESET}\n" "$COUNT_BACKUP"
    fi
    printf "  Skipped: ${COLOR_YELLOW}%d${COLOR_RESET}\n" "$COUNT_SKIPPED"
    echo ""

    if ! $MODE_DRY_RUN && ! $MODE_UNINSTALL && [ $COUNT_CREATED -gt 0 ]; then
        printf "${COLOR_CYAN}Run 'source ~/.bashrc' to apply shell changes.${COLOR_RESET}\n"
        echo ""
    fi
}

show_help() {
    cat << 'EOF'
dotfiles installer - Create symbolic links for dotfiles

USAGE:
    ./install.sh [OPTIONS]

OPTIONS:
    -h, --help          Show this help message
    -i, --interactive   Interactive mode (default)
    -f, --force         Install all files without confirmation
    -n, --dry-run       Show what would be done without making changes
    -u, --uninstall     Remove symlinks created by this installer

CATEGORIES:
    shell   Bash configuration (.bashrc, .shell_aliases)
    git     Git settings (.gitconfig, .git-completion.bash, etc.)
    vim     Vim configuration (.vimrc)
    claude  Claude Code settings (from claude-config/)

EXAMPLES:
    ./install.sh              # Interactive installation
    ./install.sh -f           # Install everything
    ./install.sh -n           # Preview what would be installed
    ./install.sh -u           # Remove all symlinks
    ./install.sh -n -u        # Preview uninstall

CLAUDE CONFIG:
    Files in claude-config/ are automatically detected via 'git ls-files'.
    - claude-config/CLAUDE.md -> ~/.claude/CLAUDE.md
    - claude-config/settings.json -> ~/.claude/settings.json
    - claude-config/skills/*/SKILL.md -> ~/.claude/commands/SKILL-*.md
    To add new Claude config files, simply add them to claude-config/ and
    commit to git.
EOF
}

# ============================================================================
# Argument Parsing
# ============================================================================

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -i|--interactive)
                MODE_INTERACTIVE=true
                shift
                ;;
            -f|--force)
                MODE_INTERACTIVE=false
                shift
                ;;
            -n|--dry-run)
                MODE_DRY_RUN=true
                shift
                ;;
            -u|--uninstall)
                MODE_UNINSTALL=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use -h for help"
                exit 1
                ;;
        esac
    done
}

# ============================================================================
# Entry Point
# ============================================================================

main() {
    parse_args "$@"

    if $MODE_DRY_RUN; then
        print_header "DRY RUN MODE - No changes will be made"
    fi

    if $MODE_UNINSTALL; then
        if $MODE_INTERACTIVE && ! $MODE_DRY_RUN; then
            printf "Remove all dotfile symlinks? [y/N]: "
            read -r confirm
            case "$confirm" in
                y|Y) ;;
                *) echo "Cancelled."; exit 0 ;;
            esac
        fi
        uninstall_files
    else
        if $MODE_INTERACTIVE; then
            select_files_interactive
            confirm_installation
        else
            # Force mode: select all files
            local i=0
            while [ $i -lt $FILE_COUNT ]; do
                add_to_selected $i
                i=$((i + 1))
            done
            # Also select claude
            SELECTED_INDICES="$SELECTED_INDICES claude"
        fi
        install_files
    fi

    show_summary
}

main "$@"
