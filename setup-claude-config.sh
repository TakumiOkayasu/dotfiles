#!/bin/bash

# Claude Code Configuration Setup Script for Linux/macOS/WSL
# This script creates symbolic links from ~/.claude to the dotfile-work/claude-config directory

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Get the absolute path of the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SOURCE_DIR="${SCRIPT_DIR}/claude-config"
TARGET_DIR="${HOME}/.claude"

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}Claude Code Configuration Setup${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# Check if source directory exists
if [ ! -d "${CONFIG_SOURCE_DIR}" ]; then
    echo -e "${RED}Error: Source directory ${CONFIG_SOURCE_DIR} does not exist${NC}"
    exit 1
fi

echo -e "${BLUE}Source directory: ${CONFIG_SOURCE_DIR}${NC}"
echo -e "${BLUE}Target directory: ${TARGET_DIR}${NC}"
echo ""

# Create target directory if it doesn't exist
if [ ! -d "${TARGET_DIR}" ]; then
    echo -e "${GREEN}Creating directory: ${TARGET_DIR}${NC}"
    mkdir -p "${TARGET_DIR}"
else
    echo -e "${YELLOW}Directory already exists: ${TARGET_DIR}${NC}"
fi

# Function to create backup with timestamp
backup_if_exists() {
    local target_path="$1"
    if [ -e "${target_path}" ] || [ -L "${target_path}" ]; then
        local timestamp=$(date +%Y%m%d_%H%M%S)
        local backup_path="${target_path}.backup_${timestamp}"
        echo -e "${YELLOW}Backing up existing ${target_path} to ${backup_path}${NC}"
        mv "${target_path}" "${backup_path}"
    fi
}

# Function to create symbolic link
create_symlink() {
    local source_name="$1"
    local source_path="${CONFIG_SOURCE_DIR}/${source_name}"
    local target_path="${TARGET_DIR}/${source_name}"

    if [ ! -e "${source_path}" ]; then
        echo -e "${YELLOW}Warning: ${source_name} does not exist in source directory, skipping${NC}"
        return 1
    fi

    backup_if_exists "${target_path}"

    echo -e "${GREEN}Creating symlink: ${target_path} -> ${source_path}${NC}"
    ln -s "${source_path}" "${target_path}"
    return 0
}

echo -e "${CYAN}Creating symbolic links...${NC}"
echo ""

# Create symlinks for each configuration item
create_symlink "CLAUDE.md"
create_symlink "settings.json"
create_symlink "skills"
create_symlink "hooks"

echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}Setup Complete!${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# Display final link status
echo -e "${CYAN}Final Configuration Status:${NC}"
echo ""

for item in "CLAUDE.md" "settings.json" "skills" "hooks"; do
    target_path="${TARGET_DIR}/${item}"
    if [ -L "${target_path}" ]; then
        link_target=$(readlink "${target_path}")
        if [ -e "${target_path}" ]; then
            echo -e "${GREEN}✓${NC} ${item}: ${target_path} -> ${link_target}"
        else
            echo -e "${RED}✗${NC} ${item}: ${target_path} -> ${link_target} ${RED}(broken link)${NC}"
        fi
    elif [ -e "${target_path}" ]; then
        echo -e "${YELLOW}⚠${NC} ${item}: ${target_path} ${YELLOW}(exists but not a symlink)${NC}"
    else
        echo -e "${RED}✗${NC} ${item}: ${target_path} ${RED}(does not exist)${NC}"
    fi
done

echo ""
echo -e "${GREEN}You can now use Claude Code with your configured settings!${NC}"
