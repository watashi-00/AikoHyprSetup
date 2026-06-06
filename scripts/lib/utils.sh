#!/usr/bin/env bash

# AikoHyprSetup V2 - Central Utility Library
# Sourced by main scripts for consistent behavior and reduced redundancy.

# --- Version ---
export AIKO_VERSION="3.0.0"

# --- Colors ---
export NC=$'\e[0m'
export BOLD=$'\e[1m'
export UNDERLINE=$'\e[4m'
export RED=$'\e[0;31m'
export GREEN=$'\e[0;32m'
export YELLOW=$'\e[1;33m'
export BLUE=$'\e[0;34m'
export MAGENTA=$'\e[0;35m'
export CYAN=$'\e[0;36m'
export WHITE=$'\e[1;37m'

# --- Icons ---
export ICON_CHECK="✔"
export ICON_WARN="⚠"
export ICON_ERROR="✘"
export ICON_INFO="ℹ"
export ICON_ROCKET="🚀"
export ICON_PACKAGE="📦"
export ICON_CONFIG="🎨"
export ICON_SEARCH="🔍"
export ICON_RELOAD="🔄"

# --- Exit Codes ---
export AIKO_EXIT_SUCCESS=0
export AIKO_EXIT_MENU_CONTINUE=2
export AIKO_EXIT_MENU_BACK=130
export AIKO_EXIT_QUIT=127
export AIKO_EXIT_MISSING_MODULE=3
export AIKO_EXIT_INVALID_OPTION=64

# --- Path Resolution ---

# Detects the root of the AikoHyprSetup installation or repository.
# Exports: AIKO_ROOT, AIKO_SCRIPTS, AIKO_WIDGETS, AIKO_THEMES, AIKO_ASSETS
get_aiko_paths() {
    local resolved=0
    # If AIKO_ROOT is already set and exists, we use it, but we MUST still export subdirs
    if [ -n "${AIKO_ROOT:-}" ] && [ -d "$AIKO_ROOT" ]; then
        export AIKO_SCRIPTS="$AIKO_ROOT/scripts"
        export AIKO_WIDGETS="$AIKO_ROOT/widgets"
        export AIKO_THEMES="$AIKO_ROOT/themes"
        export AIKO_ASSETS="$AIKO_ROOT/assets"
        export AIKO_CONFIGS="$AIKO_ROOT/configs"
        resolved=1
    fi

    if [ "$resolved" -ne 1 ]; then
        # 1. First, find where this library (utils.sh) is actually located
        local lib_dir
        lib_dir="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
        
        # 2. Derive root from lib_dir (assuming it's in scripts/lib/)
        local potential_root
        potential_root="$(cd "$lib_dir/../.." && pwd)"

        local installed_path="$HOME/.config/waybar"

        # Detection Priority:
        # 1. If we are running inside a valid repository structure (like a temp update dir)
        if [ -f "$potential_root/install.sh" ] && [ -d "$potential_root/waybar" ]; then
            export AIKO_ROOT="$potential_root"
        # 2. Check if the caller script is already in the standard installed location
        elif [[ "${BASH_SOURCE[1]:-$0}" == "$installed_path"* ]]; then
            export AIKO_ROOT="$installed_path"
        # 3. Final fallback to standard installation path
        else
            export AIKO_ROOT="$installed_path"
        fi

        # Export Standard Subdirectories
        export AIKO_SCRIPTS="$AIKO_ROOT/scripts"
        export AIKO_WIDGETS="$AIKO_ROOT/widgets"
        export AIKO_THEMES="$AIKO_ROOT/themes"
        export AIKO_ASSETS="$AIKO_ROOT/assets"
        export AIKO_CONFIGS="$AIKO_ROOT/configs"
    fi

    export AIKO_LOG_FILE="$AIKO_ROOT/.aiko-setup.log"

    # Export Git/Metadata Commit Hash
    if [ -d "$AIKO_ROOT/.git" ]; then
        export AIKO_HASH=$(git -C "$AIKO_ROOT" rev-parse --short HEAD 2>/dev/null || echo "none")
    elif [ -f "$AIKO_ROOT/.version_hash" ]; then
        export AIKO_HASH=$(cat "$AIKO_ROOT/.version_hash" 2>/dev/null || echo "none")
    else
        export AIKO_HASH="none"
    fi
}

# Automatically run path detection on source
get_aiko_paths

# --- Utility Functions ---

# Check if a command exists
have() {
    command -v "$1" >/dev/null 2>&1
}

# Fallback wrapper for ImageMagick v6 systems where 'magick' is named 'convert'
if ! command -v magick >/dev/null 2>&1 && command -v convert >/dev/null 2>&1; then
    magick() {
        convert "$@"
    }
fi

# Standard Logging
# Usage: log "message" (uses $AIKO_LOG_COMPONENT if defined)
_aiko_log_format() {
    local color="$1"
    local icon="$2"
    local msg="$3"
    local component="${AIKO_LOG_COMPONENT:-}"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    local line

    if [ -n "$component" ]; then
        line="[$timestamp][$component] $icon $msg"
        printf "${color}[%s]${NC} %s %s\n" "$component" "$icon" "$msg"
    else
        line="[$timestamp] $icon $msg"
        printf "${color}%s${NC} %s\n" "$icon" "$msg"
    fi

    if [ -n "${AIKO_LOG_FILE:-}" ]; then
        mkdir -p "$(dirname "$AIKO_LOG_FILE")" 2>/dev/null || true
        printf '%s\n' "$line" >> "$AIKO_LOG_FILE" 2>/dev/null || true
    fi
}

log() { _aiko_log_format "$BLUE" "$ICON_INFO" "$*"; }
success() { _aiko_log_format "$GREEN" "$ICON_CHECK" "$*"; }
warn() { _aiko_log_format "$YELLOW" "$ICON_WARN" "$*" >&2; }
error() { _aiko_log_format "$RED" "$ICON_ERROR" "$*" >&2; }

die() {
    local code="${2:-1}"
    error "$1"
    exit "$code"
}

# Confirmation Prompt
# Usage: if confirm "Do you want to proceed?"; then ...
confirm() {
    local prompt="$1"
    local default="${2:-y}" # 'y' or 'n'
    local response
    local options

    if [[ "$default" == [yY] ]]; then
        options="[Y/n]"
    else
        options="[y/N]"
    fi

    printf "${CYAN}${BOLD}%s %s: ${NC}" "$prompt" "$options"
    read -r response
    
    response=$(echo "${response:-$default}" | tr '[:upper:]' '[:lower:]')
    
    if [[ "$response" =~ ^(y|yes)$ ]]; then
        return 0
    else
        return 1
    fi
}

# Terminal Management
aiko_cleanup_term() {
    # Disable focus tracking and bracketed paste
    printf "\e[?1004l\e[?2004l"
}

aiko_init_term() {
    # Ensure cleanup on exit
    trap aiko_cleanup_term EXIT
}

# --- Error Handling ---

_aiko_error_handler() {
    local exit_code=$?
    local line_no=$1
    local command="$2"
    local component="${AIKO_LOG_COMPONENT:-system}"
    
    # Ignore code 127/130 (Exit or Interrupt) and 2 (Clean Menu Exit)
    if [ "$exit_code" -eq "$AIKO_EXIT_QUIT" ] || [ "$exit_code" -eq "$AIKO_EXIT_MENU_BACK" ] || [ "$exit_code" -eq "$AIKO_EXIT_MENU_CONTINUE" ]; then
        return
    fi

    # Attempt rollback if install error handling is enabled.
    trap '' ERR
    if [ "${AIKO_ROLLBACK_ON_ERROR:-0}" -eq 1 ] && declare -f aiko_install_rollback > /dev/null; then
        aiko_install_rollback || true
    fi

    echo
    printf "${RED}[%s]${NC} ${BOLD}FATAL EXCEPTION:${NC} Command failed!\n" "$component" >&2
    printf "    ${WHITE}Command:${NC}  $command\n" >&2
    printf "    ${WHITE}Line:${NC}     $line_no\n" >&2
    printf "    ${WHITE}Exit Code:${NC} $exit_code\n" >&2
    echo
    printf "${YELLOW}%s${NC} This might be a bug. Please report it.\n" "$ICON_INFO" >&2
    echo
}

aiko_enable_err_handler() {
    # Trap ERR to catch any command failure
    trap '_aiko_error_handler $LINENO "$BASH_COMMAND"' ERR
}
