#!/usr/bin/env bash

# AikoHyprSetup - Configuration Profile Manager
# Export and import user configuration presets (profiles)

set -euo pipefail

# --- Initial Setup ---
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
AIKO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
AIKO_SCRIPTS="$AIKO_ROOT/scripts"
AIKO_LOG_COMPONENT="profile-mgr"

# Load utilities
# shellcheck disable=SC1091
source "$AIKO_SCRIPTS/lib/utils.sh"
aiko_init_term
aiko_enable_err_handler

PROFILES_DIR="$HOME/.config/waybar/profiles"
CONFIG_TARGETS=(
    "$HOME/.config/waybar/config.jsonc"
    "$HOME/.config/waybar/style.css"
    "$HOME/.config/waybar/config-bottom.jsonc"
    "$HOME/.config/waybar/config-left.jsonc"
    "$HOME/.config/hypr/hyprland.conf"
    "$HOME/.local/share/fastfetch/config.jsonc"
)

THEME_TARGETS=(
    "$HOME/.config/waybar/style.css"
    "$HOME/.config/waybar/widgets"
)

ensure_profiles_dir() {
    if [ ! -d "$PROFILES_DIR" ]; then
        mkdir -p "$PROFILES_DIR"
        log "Created profiles directory: $PROFILES_DIR"
    fi
}

list_profiles() {
    ensure_profiles_dir

    if [ ! "$(ls -A "$PROFILES_DIR")" ]; then
        log "No profiles found."
        return 0
    fi

    printf "\n${BOLD}Available Profiles:${NC}\n"
    local count=1
    for profile in "$PROFILES_DIR"/*; do
        if [ -d "$profile" ]; then
            local name
            name="$(basename "$profile")"
            printf "  ${CYAN}%d)${NC} %s\n" "$count" "$name"
            count=$((count + 1))
        fi
    done
    echo
}

export_profile() {
    local profile_name="$1"

    if [ -z "$profile_name" ]; then
        read -rp "Enter profile name to export: " profile_name
    fi

    if [ -z "$profile_name" ]; then
        error "Profile name cannot be empty."
        return 1
    fi

    ensure_profiles_dir

    local profile_path="$PROFILES_DIR/$profile_name"
    if [ -e "$profile_path" ]; then
        if ! confirm "Profile '$profile_name' already exists. Overwrite?" "n"; then
            log "Export cancelled."
            return 0
        fi
        rm -rf "$profile_path"
    fi

    mkdir -p "$profile_path"
    log "Exporting profile '$profile_name'..."

    local count=0
    for target in "${CONFIG_TARGETS[@]}"; do
        if [ -e "$target" ]; then
            local rel_path
            rel_path="${target#$HOME/}"
            local dest="$profile_path/$rel_path"
            mkdir -p "$(dirname "$dest")"
            cp -P "$target" "$dest"
            log "  Exported: $rel_path"
            count=$((count + 1))
        fi
    done

    if [ "$count" -eq 0 ]; then
        error "No configuration files found to export."
        rm -rf "$profile_path"
        return 1
    fi

    # Save profile metadata
    {
        echo "# Profile: $profile_name"
        echo "# Created: $(date)"
        echo "# Files: $count"
    } > "$profile_path/.profile-info"

    success "Profile '$profile_name' exported with $count file(s)."
}

import_profile() {
    local profile_name="$1"

    if [ -z "$profile_name" ]; then
        list_profiles
        read -rp "Enter profile name to import: " profile_name
    fi

    if [ -z "$profile_name" ]; then
        error "Profile name cannot be empty."
        return 1
    fi

    ensure_profiles_dir

    local profile_path="$PROFILES_DIR/$profile_name"
    if [ ! -d "$profile_path" ]; then
        error "Profile '$profile_name' not found."
        return 1
    fi

    log "Importing profile '$profile_name'..."

    if ! confirm "This will overwrite your current configuration. Continue?" "n"; then
        log "Import cancelled."
        return 0
    fi

    local count=0
    for target in "${CONFIG_TARGETS[@]}"; do
        local rel_path
        rel_path="${target#$HOME/}"
        local src="$profile_path/$rel_path"

        if [ -e "$src" ]; then
            mkdir -p "$(dirname "$target")"
            cp -P "$src" "$target"
            log "  Restored: $rel_path"
            count=$((count + 1))
        fi
    done

    if [ "$count" -eq 0 ]; then
        error "No files found in profile to restore."
        return 1
    fi

    success "Profile '$profile_name' imported with $count file(s)."
    log "Run 'restart-waybar' to apply changes."
}

delete_profile() {
    local profile_name="$1"

    if [ -z "$profile_name" ]; then
        list_profiles
        read -rp "Enter profile name to delete: " profile_name
    fi

    if [ -z "$profile_name" ]; then
        error "Profile name cannot be empty."
        return 1
    fi

    ensure_profiles_dir

    local profile_path="$PROFILES_DIR/$profile_name"
    if [ ! -d "$profile_path" ]; then
        error "Profile '$profile_name' not found."
        return 1
    fi

    if ! confirm "Delete profile '$profile_name'?" "n"; then
        log "Deletion cancelled."
        return 0
    fi

    rm -rf "$profile_path"
    success "Profile '$profile_name' deleted."
}

usage() {
    cat << 'EOF'
Usage: profile-manager.sh [command] [profile-name]

Commands:
  list              List all available profiles.
  export [name]     Export current configuration as a profile.
  import [name]     Import a saved profile (overwrites current config).
  delete [name]     Delete a profile.
  -h, --help        Show this help.

If no profile-name is provided, you will be prompted to enter one.

Examples:
  ./profile-manager.sh export my-setup
  ./profile-manager.sh import my-setup
  ./profile-manager.sh list
EOF
}

# --- Main ---
if [ "$#" -eq 0 ]; then
    usage
    exit 0
fi

case "$1" in
    list) list_profiles ;;
    export) export_profile "${2:-}" ;;
    import) import_profile "${2:-}" ;;
    delete) delete_profile "${2:-}" ;;
    -h|--help) usage ;;
    *) die "Unknown command: $1. Use -h for help." ;;
esac
