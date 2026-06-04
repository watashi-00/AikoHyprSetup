#!/usr/bin/env bash

# AikoHyprSetup V2 - Central Utility Library
# Sourced by main scripts for consistent behavior and reduced redundancy.

# --- Version ---
export AIKO_VERSION="1.0.4"

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

# --- Path Resolution ---

# Detects the root of the AikoHyprSetup installation or repository.
# Exports: AIKO_ROOT, AIKO_SCRIPTS, AIKO_WIDGETS, AIKO_THEMES, AIKO_ASSETS
get_aiko_paths() {
    # If AIKO_ROOT is already set and exists, don't re-detect (allows overrides)
    if [ -n "${AIKO_ROOT:-}" ] && [ -d "$AIKO_ROOT" ]; then
        return 0
    fi

    # BASH_SOURCE[1] is the script that sourced this library
    local caller_path="${BASH_SOURCE[1]:-$0}"
    local caller_dir
    caller_dir="$(cd "$(dirname "$(readlink -f "$caller_path")")" && pwd)"

    # CWD might be the repo root even if the script is called from elsewhere
    local cwd_dir
    cwd_dir="$(pwd)"

    # Detection Priority:
    # 1. Check if we are in the repository root (look for marker files)
    if [ -f "$cwd_dir/install.sh" ] && [ -d "$cwd_dir/waybar" ] && [ -d "$cwd_dir/scripts" ]; then
        export AIKO_ROOT="$cwd_dir"
    # 2. Check if the caller script is in the repo root
    elif [ -f "$caller_dir/install.sh" ] && [ -d "$caller_dir/waybar" ]; then
        export AIKO_ROOT="$caller_dir"
    # 3. Check if caller is in scripts/ or widgets/ and find root from there
    elif [[ "$caller_dir" == */scripts ]] || [[ "$caller_dir" == */widgets/* ]]; then
        if [[ "$caller_dir" == */widgets/* ]]; then
            export AIKO_ROOT="$(cd "$caller_dir/../.." && pwd)"
        else
            export AIKO_ROOT="$(cd "$caller_dir/.." && pwd)"
        fi
    # 4. Fallback to standard installation path
    else
        export AIKO_ROOT="$HOME/.config/waybar"
    fi

    # Export Standard Subdirectories
    export AIKO_SCRIPTS="$AIKO_ROOT/scripts"
    export AIKO_WIDGETS="$AIKO_ROOT/widgets"
    export AIKO_THEMES="$AIKO_ROOT/themes"
    export AIKO_ASSETS="$AIKO_ROOT/assets"
    export AIKO_CONFIGS="$AIKO_ROOT/configs"
}

# Automatically run path detection on source
get_aiko_paths

# --- Utility Functions ---

# Check if a command exists
have() {
    command -v "$1" >/dev/null 2>&1
}

# Standard Logging
# Usage: log "message" (uses $AIKO_LOG_COMPONENT if defined)
_aiko_log_format() {
    local color="$1"
    local icon="$2"
    local msg="$3"
    local component="${AIKO_LOG_COMPONENT:-}"
    
    if [ -n "$component" ]; then
        printf "${color}[%s]${NC} %s %s\n" "$component" "$icon" "$msg"
    else
        printf "${color}%s${NC} %s\n" "$icon" "$msg"
    fi
}

log() { _aiko_log_format "$BLUE" "$ICON_INFO" "$*"; }
success() { _aiko_log_format "$GREEN" "$ICON_CHECK" "$*"; }
warn() { _aiko_log_format "$YELLOW" "$ICON_WARN" "$*" >&2; }
error() { _aiko_log_format "$RED" "$ICON_ERROR" "$*" >&2; }

die() {
    error "$*"
    exit 1
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
