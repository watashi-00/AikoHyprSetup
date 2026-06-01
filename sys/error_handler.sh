#!/usr/bin/env bash

# Global Error Handler for AikoHyprSetup
# This script should be sourced by main entry points.

setup_error_handler() {
    # Trap ERR to catch any command failure (due to set -e)
    trap 'error_handler $LINENO "$BASH_COMMAND"' ERR
}

error_handler() {
    local exit_code=$?
    local line_no=$1
    local command="$2"
    
    # Ignore code 127/130 (Exit or Interrupt) to avoid spamming on normal exit
    if [ $exit_code -eq 127 ] || [ $exit_code -eq 130 ]; then
        return
    fi

    # Ensure colors are defined if not already (fallback)
    local red='\e[0;31m'
    local yellow='\e[1;33m'
    local white='\e[1;37m'
    local bold='\e[1m'
    local underline='\e[4m'
    local nc='\e[0m'
    
    # Use existing variables from install.sh if available
    local RED="${RED:-$red}"
    local YELLOW="${YELLOW:-$yellow}"
    local WHITE="${WHITE:-$white}"
    local BOLD="${BOLD:-$bold}"
    local UNDERLINE="${UNDERLINE:-$underline}"
    local NC="${NC:-$nc}"
    local ERROR_ICON="${ERROR:-✘}"
    local INFO_ICON="${INFO:-ℹ}"
    local ISSUES_URL="${REPO_ISSUES:-https://github.com/watashi-00/AikoHyprSetup/issues}"

    echo
    printf "${RED}[$ERROR_ICON]${NC} ${BOLD}FATAL EXCEPTION:${NC} Installation failed!\n" >&2
    printf "    ${WHITE}Command:${NC}  $command\n" >&2
    printf "    ${WHITE}Line:${NC}     $line_no\n" >&2
    printf "    ${WHITE}Exit Code:${NC} $exit_code\n" >&2
    echo
    printf "${YELLOW}[$INFO_ICON]${NC} This might be a bug. Please report it at:\n" >&2
    printf "    ${UNDERLINE}${ISSUES_URL}${NC}\n" >&2
    echo
}

# Auto-initialize when sourced
setup_error_handler
