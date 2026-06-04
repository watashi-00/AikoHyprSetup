#!/usr/bin/env bash
set -euo pipefail

# --- Initial Settings ---
# Use BASH_SOURCE[0] if available (when run as script), fallback to $0
SCRIPT_REF="${BASH_SOURCE[0]:-$0}"
REAL_PATH="$(readlink -f "$SCRIPT_REF" 2>/dev/null || echo "$SCRIPT_REF")"
SOURCE_DIR_LOCAL="$(cd "$(dirname "$REAL_PATH")" && pwd 2>/dev/null || pwd)"

# Force AIKO_ROOT to the current installer directory to ensure modules 
# are loaded from the downloaded package and not from an old installation.
export AIKO_ROOT="$SOURCE_DIR_LOCAL"
export AIKO_SCRIPTS="$AIKO_ROOT/scripts"

# --- Load Central Utility Library ---
LIB_UTILS="$SOURCE_DIR_LOCAL/scripts/lib/utils.sh"
[ ! -f "$LIB_UTILS" ] && LIB_UTILS="$SOURCE_DIR_LOCAL/lib/utils.sh"

if [ -f "$LIB_UTILS" ]; then
    # shellcheck disable=SC1091
    source "$LIB_UTILS"
else
    echo "Error: utility library not found at $LIB_UTILS"
    exit 1
fi

# --- Load Installer Modules ---
load_installer_module() {
    local module="$1"
    local module_path="$AIKO_SCRIPTS/lib/$module"

    if [ -f "$module_path" ]; then
        # shellcheck disable=SC1090
        source "$module_path"
    else
        die "Installer module not found: $module_path. Verify the AikoHyprSetup repository is intact." "$AIKO_EXIT_MISSING_MODULE"
    fi
}

for module in system.sh packages.sh configs.sh health.sh; do
    load_installer_module "$module"
done

AIKO_LOG_COMPONENT="install"
aiko_init_term
aiko_enable_err_handler

REPO_ISSUES="https://github.com/watashi-00/AikoHyprSetup/issues"

# Logic for source files location (repo vs installed)
if [ -f "$AIKO_ROOT/waybar/config.jsonc" ]; then
    AIKO_SOURCE_WAYBAR="$AIKO_ROOT/waybar"
else
    AIKO_SOURCE_WAYBAR="$AIKO_ROOT"
fi

INSTALL_PACKAGES=1
INSTALL_HYPR=1
FORCE=0
DRY_RUN=0

# --- Load Modular Menu ---
if [ -f "$AIKO_SCRIPTS/menu.sh" ]; then
    # shellcheck disable=SC1091
    source "$AIKO_SCRIPTS/menu.sh"
elif [ -f "$AIKO_ROOT/menu.sh" ]; then
    source "$AIKO_ROOT/menu.sh"
else
    die "menu.sh not found in $AIKO_SCRIPTS or $AIKO_ROOT"
fi

# --- Summary Variables ---
INSTALLED_PKGS=0
COPIED_FILES=0
BACKUPS_CREATED=0

# --- Menu System (Configuration) ---

print_header() {
    cat <<EOF
${MAGENTA}${BOLD}
  ██╗███╗   ██╗███████╗████████╗ █████╗ ██╗     ██╗     ███████╗██████╗ 
  ██║████╗  ██║██╔════╝╚══██╔══╝██╔══██╗██║     ██║     ██╔════╝██╔══██╗
  ██║██╔██╗ ██║███████╗   ██║   ███████║██║     ██║     █████╗  ██████╔╝
  ██║██║╚██╗██║╚════██║   ██║   ██╔══██║██║     ██║     ██╔══╝  ██╔══██╗
  ██║██║ ╚████║███████║   ██║   ██║  ██║███████╗███████╗███████╗██║  ██║
  ╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝╚═╝  ╚═╝
${NC}
             ${CYAN}AikoHyprSetup v$AIKO_VERSION (Hyprland + Waybar)${NC}
EOF
    echo
}

show_summary() {
    printf "\n${BOLD}${GREEN}=== Installation Summary ===${NC}\n"
    printf "${CYAN}Packages installed:${NC}  %d\n" "$INSTALLED_PKGS"
    printf "${CYAN}Files copied:${NC}       %d\n" "$COPIED_FILES"
    printf "${CYAN}Backups created:${NC}    %d\n" "$BACKUPS_CREATED"
    
    if have fastfetch; then
        printf "${CYAN}Fastfetch Status:${NC}   ${GREEN}Ready${NC}\n"
    fi

    echo "=============================="
}

# Menu Action Functions
action_full_setup() {
    log "Starting full setup..."
    install_packages
    install_configs
    action_global_aiko "silent"
    post_install_checks
    show_summary
    apply_changes
    return "$AIKO_EXIT_MENU_BACK"
}

action_update_configs() {
    install_configs
    show_summary
    prompt_apply
    return 0
}

action_install_packages() {
    install_packages
    show_summary
    return 0
}

action_check_health() {
    post_install_checks
    return 0
}

action_restart_waybar() {
    apply_changes
    success "Waybar and Hyprland reloaded!"
    return 0
}

action_git_pull() {
    if [ -d "$AIKO_ROOT/.git" ]; then
        log "Updating AikoHyprSetup from GitHub in: $AIKO_ROOT"
        if git -C "$AIKO_ROOT" pull; then
            success "Update successful! Please exit (0) and run ./install.sh again to use the updated version."
        else
            error "Failed to pull updates. Check your connection or git status."
        fi
    else
        warn "Source at $AIKO_ROOT is not a git repository."
        if confirm "Do you want to download the latest version from GitHub?" "n"; then
            local TEMP_DIR
            TEMP_DIR=$(mktemp -d)
            log "Downloading latest master archive..."
            if curl -L https://github.com/watashi-00/AikoHyprSetup/archive/refs/heads/master.zip -o "$TEMP_DIR/update.zip"; then
                log "Extracting to $AIKO_ROOT..."
                unzip -o -q "$TEMP_DIR/update.zip" -d "$TEMP_DIR"
                local EXTRACTED_DIR
                EXTRACTED_DIR=$(find "$TEMP_DIR" -maxdepth 1 -type d -name "AikoHyprSetup-*" | head -n 1)
                if [ -d "$EXTRACTED_DIR" ]; then
                    # Copy all files from extracted dir to current AIKO_ROOT
                    cp -rf "$EXTRACTED_DIR"/* "$AIKO_ROOT/"
                    success "Update successful! Source files updated."
                    printf "${YELLOW}[!]${NC} Please exit (0) and run ./install.sh again to use the updated version.\n"
                    exit 0
                else
                    error "Could not find extracted directory."
                fi
            else
                error "Failed to download update."
            fi
            rm -rf "$TEMP_DIR"
        else
            warn "Non-git updates require 'curl' and 'unzip'. Please update manually."
        fi
    fi
    return 0
}

# Wallpaper, theme and other modules...
action_wallpaper_changer() {
    local wp_script="$AIKO_SCRIPTS/wallpaper.sh"
    if [ -f "$wp_script" ]; then
        bash "$wp_script" select
    else
        warn "Wallpaper script not found."
    fi
    return 0
}

action_theme_selector() {
    local theme_script="$AIKO_SCRIPTS/theme-selector.sh"
    if [ -f "$theme_script" ]; then
        bash "$theme_script"
    else
        warn "Theme selector script not found."
    fi
    return 0
}

action_monitor_config() {
    bash "$AIKO_SCRIPTS/lib/widget_launcher.sh" "aiko-monitors"
    return 0
}

action_global_aiko() {
    local mode="${1:-normal}"
    local aiko_src="$HOME/.config/waybar/scripts/aiko.sh"
    local aiko_dest="/usr/local/bin/aiko"

    if [ ! -f "$aiko_src" ]; then
        if [ "$mode" != "silent" ]; then
            error "Aiko script not found. Install configs first."
        fi
        return 0
    fi

    if [ "$mode" != "silent" ]; then
        log "Setting up 'aiko' command..."
    fi
    
    validate_sudo
    sudo_cmd ln -sf "$aiko_src" "$aiko_dest"
    sudo_cmd chmod +x "$aiko_dest"
    
    if [ "$mode" != "silent" ]; then
        success "Global command 'aiko' is ready!"
    fi
    return 0
}

action_diagnostics() {
    local diag_script="$AIKO_SCRIPTS/diagnostics.sh"
    if [ -f "$diag_script" ]; then
        bash "$diag_script"
    else
        warn "Diagnostics script not found."
    fi
    return 0
}

action_gpu_setup() {
    local gpu_local="$(cd "$AIKO_ROOT/.." && pwd)/gpu_setup/setup.sh"
    if [ -f "$gpu_local" ]; then
        log "Handing over to local GPU Setup Manager..."
        exec sudo bash "$gpu_local"
    else
        log "GPU Setup not found locally. Downloading and running from GitHub..."
        if ! have git; then
            error "Error: 'git' is required to download the GPU Setup Manager."
            return 1
        fi
        local temp_gpu
        temp_gpu=$(mktemp -d)
        if git clone --depth 1 https://github.com/watashi-00/gpu_setup.git "$temp_gpu"; then
            exec sudo bash "$temp_gpu/setup.sh"
        else
            error "Failed to download GPU Setup Manager."
            rm -rf "$temp_gpu"
            return 1
        fi
    fi
}

action_cleanup_backups() {
    cleanup_generated_backups
    return 0
}

action_exit() {
    if [ -t 1 ]; then clear; fi
    log "Exiting..."
    return "$AIKO_EXIT_QUIT"
}

# Submenu Navigation...
submenu_install() {
    declare -A labels=(
        [1]="🚀  Full Setup (Recommended)"
        [2]="🎨  Update Configs & Widgets"
        [3]="📦  Install Packages Only"
        [4]="🆙  Update Setup (Git Pull)"
        [5]="🎮  GPU Setup"
        [0]="⬅   Back"
    )
    declare -A actions=(
        [1]="action_full_setup"
        [2]="action_update_configs"
        [3]="action_install_packages"
        [4]="action_git_pull"
        [5]="action_gpu_setup"
        [0]="menu_back"
    )
    local order=(1 2 3 4 5 0)
    menu "Installation & Updates" labels actions order
}

submenu_customization() {
    declare -A labels=(
        [1]="🖼️   Change Wallpaper"
        [2]="🎨  Change Theme"
        [3]="🖥️   Monitor Configuration"
        [0]="⬅   Back"
    )
    declare -A actions=(
        [1]="action_wallpaper_changer"
        [2]="action_theme_selector"
        [3]="action_monitor_config"
        [0]="menu_back"
    )
    local order=(1 2 3 0)
    menu "Desktop Customization" labels actions order
}

submenu_maintenance() {
    declare -A labels=(
        [1]="🔄  Restart Waybar"
        [2]="🔍  Check System Health"
        [3]="🩺  Environment Diagnostics"
        [4]="🧪  Codebase Self-Test"
        [5]="🗑️   Clean Generated Backups"
        [0]="⬅   Back"
    )
    declare -A actions=(
        [1]="action_restart_waybar"
        [2]="action_check_health"
        [3]="action_diagnostics"
        [4]="action_self_test"
        [5]="action_cleanup_backups"
        [0]="menu_back"
    )
    local order=(1 2 3 4 5 0)
    menu "Maintenance & Diagnostics" labels actions order
}

interactive_menu() {
    declare -A labels=(
        [1]="📦  Installation & Updates"
        [2]="🎨  Desktop Customization"
        [3]="🛠️   Maintenance & Tools"
        [0]="✘   Exit"
    )

    declare -A actions=(
        [1]="submenu_install"
        [2]="submenu_customization"
        [3]="submenu_maintenance"
        [0]="action_exit"
    )
    local order=(1 2 3 0)
    
    menu "Main Menu" labels actions order
}

# --- CLI Options ---

usage() {
    cat <<EOF
Usage: ./install.sh [options]

Options:
  --no-packages  Do not install system dependencies.
  --no-hypr      Do not install hyprland.conf in ~/.config/hypr.
  --force        Overwrite files without asking.
  --dry-run      Show actions without copying/installing.
  -h, --help     Show this help.

If run without options, opens the interactive menu.
EOF
}

if [ "$#" -gt 0 ]; then
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --no-packages) INSTALL_PACKAGES=0 ;;
            --no-hypr) INSTALL_HYPR=0 ;;
            --force) FORCE=1 ;;
            --dry-run) DRY_RUN=1 ;;
            -h|--help) usage; exit 0 ;;
            *) die "Unknown option: $1" ;;
        esac
        shift
    done
    [ "$INSTALL_PACKAGES" -eq 1 ] && install_packages
    install_configs
    action_global_aiko "silent"
    post_install_checks
    show_summary
else
    interactive_menu
fi
