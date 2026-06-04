#!/usr/bin/env bash

# AikoHyprSetup V2 - System Utilities
# Handles sudo privileges and execution wrappers.

# --- Internal Logic ---

# Run a command with dry-run support
run() {
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        printf "${YELLOW}[dry-run]${NC} %s\n" "$*"
    else
        "$@"
    fi
}

# Run a command with sudo if not root
sudo_cmd() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

# Ensure sudo access is available
validate_sudo() {
    if [ "$(id -u)" -ne 0 ]; then
        log "Privileged access required. Please enter your password:"
        sudo -v || die "Sudo authentication failed."
    fi
}
