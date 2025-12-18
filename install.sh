#!/bin/bash
#
# dotfiles installer
# Creates symbolic links for dotfiles to home directory
#

set -eu

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

# Symbolic link definitions: "source:destination"
LINKS=(
    ".bashrc:$HOME/.bashrc"
    ".bash_aliases:$HOME/.bash_aliases"
    ".zshrc:$HOME/.zshrc"
    ".zsh_aliases:$HOME/.zsh_aliases"
    ".vimrc:$HOME/.vimrc"
    ".gitconfig:$HOME/.gitconfig"
    ".git-completion.bash:$HOME/.git-completion.bash"
    ".git-prompt.sh:$HOME/.git-prompt.sh"
    ".gitignore:$HOME/.config/git/ignore"
    ".claude:$HOME/.claude"
)

create_link() {
    local src="$DOTFILES_DIR/$1"
    local dest="$2"

    if [[ ! -e "$src" ]]; then
        echo "Skip: $src (not found)"
        return
    fi

    local dest_dir
    dest_dir="$(dirname "$dest")"
    [[ -d "$dest_dir" ]] || mkdir -p "$dest_dir"

    if [[ -L "$dest" ]]; then
        rm "$dest"
    elif [[ -e "$dest" ]]; then
        echo "Backup: $dest -> ${dest}.bak"
        mv "$dest" "${dest}.bak"
    fi

    ln -s "$src" "$dest"
    echo "Created: $dest -> $src"
}

main() {
    echo "Installing dotfiles from: $DOTFILES_DIR"
    echo

    for link in "${LINKS[@]}"; do
        src="${link%%:*}"
        dest="${link#*:}"
        create_link "$src" "$dest"
    done

    # CLAUDE.md is inside .claude directory
    if [[ -d "$HOME/.claude" && -f "$DOTFILES_DIR/CLAUDE.md" ]]; then
        local claude_md="$HOME/.claude/CLAUDE.md"
        [[ -L "$claude_md" ]] && rm "$claude_md"
        [[ -e "$claude_md" && ! -L "$claude_md" ]] && mv "$claude_md" "${claude_md}.bak"
        ln -s "$DOTFILES_DIR/CLAUDE.md" "$claude_md"
        echo "Created: $claude_md -> $DOTFILES_DIR/CLAUDE.md"
    fi

    # settings.json for Claude Code
    if [[ -d "$HOME/.claude" && -f "$DOTFILES_DIR/settings.json" ]]; then
        local settings="$HOME/.claude/settings.json"
        [[ -L "$settings" ]] && rm "$settings"
        [[ -e "$settings" && ! -L "$settings" ]] && mv "$settings" "${settings}.bak"
        ln -s "$DOTFILES_DIR/settings.json" "$settings"
        echo "Created: $settings -> $DOTFILES_DIR/settings.json"
    fi

    # SKILL files for Claude Code commands
    if [[ -d "$HOME/.claude" ]]; then
        mkdir -p "$HOME/.claude/commands"
        for skill in "$DOTFILES_DIR"/SKILL-*.md; do
            [[ -f "$skill" ]] || continue
            local skill_name
            skill_name="$(basename "$skill")"
            local dest="$HOME/.claude/commands/$skill_name"
            [[ -L "$dest" ]] && rm "$dest"
            [[ -e "$dest" && ! -L "$dest" ]] && mv "$dest" "${dest}.bak"
            ln -s "$skill" "$dest"
            echo "Created: $dest -> $skill"
        done
    fi

    echo
    echo "Done. Run 'source ~/.bashrc' to apply changes."
}

main
