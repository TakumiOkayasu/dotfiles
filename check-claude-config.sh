#!/bin/bash

# Claude Code Configuration Verification Script
# This script checks if the symbolic links are correctly set up

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

TARGET_DIR="${HOME}/.claude"

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}Claude Code Configuration Check${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# Counter for issues
ISSUES=0
WARNINGS=0

# Function to check if item is a valid symbolic link
check_symlink() {
    local item_name="$1"
    local target_path="${TARGET_DIR}/${item_name}"
    local is_optional="${2:-false}"

    echo -n "Checking ${item_name}... "

    if [ ! -e "${target_path}" ] && [ ! -L "${target_path}" ]; then
        if [ "$is_optional" = "true" ]; then
            echo -e "${YELLOW}SKIP${NC} (optional, not found)"
            ((WARNINGS++))
        else
            echo -e "${RED}FAIL${NC} (does not exist)"
            echo -e "${RED}  → File or directory not found: ${target_path}${NC}"
            echo -e "${BLUE}  → Fix: Run ./setup-claude-config.sh to create the symlink${NC}"
            ((ISSUES++))
        fi
        return 1
    fi

    if [ ! -L "${target_path}" ]; then
        echo -e "${YELLOW}WARN${NC} (exists but not a symlink)"
        echo -e "${YELLOW}  → Path exists but is not a symbolic link: ${target_path}${NC}"
        echo -e "${BLUE}  → Fix: Backup and remove the existing file/directory, then run ./setup-claude-config.sh${NC}"
        ((WARNINGS++))
        return 1
    fi

    local link_target=$(readlink "${target_path}")

    if [ ! -e "${target_path}" ]; then
        echo -e "${RED}FAIL${NC} (broken link)"
        echo -e "${RED}  → Symbolic link points to non-existent target: ${link_target}${NC}"
        echo -e "${BLUE}  → Fix: Remove the broken link and run ./setup-claude-config.sh${NC}"
        echo -e "${BLUE}       rm \"${target_path}\"${NC}"
        ((ISSUES++))
        return 1
    fi

    # Check if link points to dotfile-work/claude-config
    if [[ "${link_target}" == *"/claude-config/${item_name}" ]] || [[ "${link_target}" == *"\\claude-config\\${item_name}" ]]; then
        echo -e "${GREEN}OK${NC}"
        echo -e "${GREEN}  → ${target_path} -> ${link_target}${NC}"
        return 0
    else
        echo -e "${YELLOW}WARN${NC} (unexpected target)"
        echo -e "${YELLOW}  → Link target may not be correct: ${link_target}${NC}"
        echo -e "${YELLOW}  → Expected path containing: /claude-config/${item_name}${NC}"
        echo -e "${BLUE}  → If this is intentional, you can ignore this warning${NC}"
        ((WARNINGS++))
        return 1
    fi
}

# Check if target directory exists
if [ ! -d "${TARGET_DIR}" ]; then
    echo -e "${RED}ERROR: Directory ${TARGET_DIR} does not exist${NC}"
    echo -e "${BLUE}→ Fix: Run ./setup-claude-config.sh to set up the configuration${NC}"
    echo ""
    exit 1
fi

echo -e "${BLUE}Target directory: ${TARGET_DIR}${NC}"
echo ""

# Check each configuration item
check_symlink "CLAUDE.md" false
check_symlink "settings.json" false
check_symlink "skills" false
check_symlink "hooks" true  # hooks is optional

echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}Check Complete${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# Summary
if [ $ISSUES -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed! Your Claude Code configuration is correctly set up.${NC}"
    exit 0
elif [ $ISSUES -eq 0 ]; then
    echo -e "${YELLOW}⚠ Configuration is functional but has ${WARNINGS} warning(s).${NC}"
    echo -e "${YELLOW}  Review the warnings above and fix them if needed.${NC}"
    exit 0
else
    echo -e "${RED}✗ Found ${ISSUES} issue(s) and ${WARNINGS} warning(s).${NC}"
    echo -e "${RED}  Please review the errors above and follow the suggested fixes.${NC}"
    echo ""
    echo -e "${BLUE}Common fixes:${NC}"
    echo -e "${BLUE}  1. Run the setup script: ./setup-claude-config.sh${NC}"
    echo -e "${BLUE}  2. Check if dotfile-work repository is in the correct location${NC}"
    echo -e "${BLUE}  3. Ensure you have proper permissions to create symlinks${NC}"
    exit 1
fi
