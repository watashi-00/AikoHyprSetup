#!/usr/bin/env bash
# aiko - Global CLI for AikoHyprSetup management

# Get the real directory of the script to locate the library
REAL_SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$REAL_SCRIPT_PATH")" && pwd)"

# --- Load Central Utility Library ---
LIB_UTILS="$SCRIPT_DIR/lib/utils.sh"
if [ -f "$LIB_UTILS" ]; then
    # shellcheck disable=SC1091
    source "$LIB_UTILS"
else
    echo "Error: utility library not found at $LIB_UTILS"
    exit 1
fi

AIKO_LOG_COMPONENT="aiko"
aiko_init_term

show_help() {
    cat <<EOF
Aiko CLI v$AIKO_VERSION - Manage your AikoHyprSetup environment

Usage: aiko [options]

Options:
  -h, --help        Show this help message
  -v, --version     Show version information
  --install         Run the installation script
  --update          Update AikoHyprSetup (git pull)
  --wallpaper       Open the wallpaper selector
  --theme           Open the theme selector
  --note            Open the Aiko-Note widget
  --clock           Open the Aiko-Clock widget
  --weather         Open the Aiko-Weather widget
  --usercard        Open the Aiko-UserCard widget
  --player          Open the Aiko-Player widget
  --list            Open the Aiko-List widget
  --sys             Open the Aiko-System widget
  --all             Open all Aiko widgets at once
  --diag            Run system environment diagnostics
  --edit-usercard   Edit the User Card information
  --edit-logo       Edit terminal ASCII logo color and spacing
  --gpu             GPU Setup and Optimization
  --restart         Restart Waybar and refresh configs

Examples:
  aiko --wallpaper
  aiko --note
EOF
}

case "${1:-}" in
    -h|--help)
        show_help
        ;;
    -v|--version)
        echo "Aiko CLI v$AIKO_VERSION"
        ;;
    --install)
        if [ -f "$AIKO_ROOT/install.sh" ]; then
            bash "$AIKO_ROOT/install.sh"
        else
            error "install.sh not found in $AIKO_ROOT"
        fi
        ;;
    --gpu)
        GPU_LOCAL="$(cd "$AIKO_ROOT/.." && pwd)/gpu_setup/setup.sh"
        if [ -f "$GPU_LOCAL" ]; then
            exec sudo bash "$GPU_LOCAL"
        else
            log "GPU Setup not found locally. Downloading and running from GitHub..."
            if ! have git; then
                error "'git' is required to download the GPU Setup Manager."
                exit 1
            fi
            TEMP_GPU=$(mktemp -d)
            if git clone --depth 1 https://github.com/watashi-00/gpu_setup.git "$TEMP_GPU"; then
                exec sudo bash "$TEMP_GPU/setup.sh"
            else
                error "Failed to download GPU Setup Manager."
                rm -rf "$TEMP_GPU"
                exit 1
            fi
        fi
        ;;
    --update)
        if [ -d "$AIKO_ROOT/.git" ]; then
            log "Updating AikoHyprSetup via git..."
            git -C "$AIKO_ROOT" pull
        else
            warn "Non-git installation detected. Checking for updates on GitHub..."
            if have curl && have unzip; then
                # Fetch remote version
                REMOTE_VERSION=$(curl -sSL https://raw.githubusercontent.com/watashi-00/AikoHyprSetup/master/scripts/lib/utils.sh | grep '^export AIKO_VERSION=' | cut -d '"' -f 2)
                
                if [ -z "$REMOTE_VERSION" ]; then
                    error "Could not check for updates. Please check your connection."
                elif [ "$REMOTE_VERSION" == "$AIKO_VERSION" ]; then
                    log "You are already using the latest version ($AIKO_VERSION)."
                else
                    log "A new version is available: $REMOTE_VERSION (Current: $AIKO_VERSION)"
                    log "Downloading and installing the update..."
                    
                    TEMP_DIR=$(mktemp -d)
                    if curl -L https://github.com/watashi-00/AikoHyprSetup/archive/refs/heads/master.zip -o "$TEMP_DIR/update.zip"; then
                        log "Extracting..."
                        unzip -q "$TEMP_DIR/update.zip" -d "$TEMP_DIR"
                        EXTRACTED_DIR=$(find "$TEMP_DIR" -maxdepth 1 -type d -name "AikoHyprSetup-*" | head -n 1)
                        
                        if [ -f "$EXTRACTED_DIR/install.sh" ]; then
                            log "Running installer..."
                            # Run with --no-packages to speed up configuration update
                            bash "$EXTRACTED_DIR/install.sh" --no-packages
                        else
                            error "install.sh not found in update package."
                        fi
                    else
                        error "Failed to download update."
                    fi
                    rm -rf "$TEMP_DIR"
                fi
            else
                error "'curl' and 'unzip' are required for non-git updates."
                log "Please update manually from: https://github.com/watashi-00/AikoHyprSetup"
            fi
        fi
        ;;
    --wallpaper)
        script="$AIKO_SCRIPTS/wallpaper.sh"
        if [ -f "$script" ]; then
            bash "$script" select
        else
            error "wallpaper.sh not found."
        fi
        ;;
    --theme)
        script="$AIKO_SCRIPTS/theme-selector.sh"
        if [ -f "$script" ]; then
            bash "$script"
        else
            error "theme-selector.sh not found."
        fi
        ;;
    --note)
        if [ -f "$AIKO_WIDGETS/aiko-note/aiko-note.sh" ]; then
            bash "$AIKO_WIDGETS/aiko-note/aiko-note.sh"
        else
            error "Aiko-Note widget not found."
        fi
        ;;
    --list)
        if [ -f "$AIKO_WIDGETS/aiko-list/aiko-list.sh" ]; then
            bash "$AIKO_WIDGETS/aiko-list/aiko-list.sh"
        else
            error "Aiko-List widget not found."
        fi
        ;;
    --sys)
        if [ -f "$AIKO_WIDGETS/aiko-sys/aiko-sys.sh" ]; then
            bash "$AIKO_WIDGETS/aiko-sys/aiko-sys.sh"
        else
            error "Aiko-System widget not found."
        fi
        ;;
    --clock)
        if [ -f "$AIKO_WIDGETS/aiko-clock/aiko-clock.sh" ]; then
            bash "$AIKO_WIDGETS/aiko-clock/aiko-clock.sh"
        else
            error "Aiko-Clock widget not found."
        fi
        ;;
    --weather)
        if [ -f "$AIKO_WIDGETS/aiko-weather/aiko-weather.sh" ]; then
            bash "$AIKO_WIDGETS/aiko-weather/aiko-weather.sh"
        else
            error "Aiko-Weather widget not found."
        fi
        ;;
    --usercard)
        if [ -f "$AIKO_WIDGETS/aiko-usercard/aiko-usercard.sh" ]; then
            bash "$AIKO_WIDGETS/aiko-usercard/aiko-usercard.sh"
        else
            error "Aiko-UserCard widget not found."
        fi
        ;;
    --player)
        if [ -f "$AIKO_WIDGETS/aiko-player/aiko-player.sh" ]; then
            bash "$AIKO_WIDGETS/aiko-player/aiko-player.sh"
        else
            error "Aiko-Player widget not found."
        fi
        ;;
    --all)
        log "Launching all Aiko widgets..."
        widgets=("aiko-clock" "aiko-weather" "aiko-note" "aiko-player" "aiko-list" "aiko-sys" "aiko-usercard")
        for widget in "${widgets[@]}"; do
            script="$AIKO_WIDGETS/$widget/$widget.sh"
            if [ -f "$script" ]; then
                log "  -> Starting $widget"
                bash "$script" &
                sleep 0.2
            fi
        done
        ;;
    --diag)
        script="$AIKO_SCRIPTS/diagnostics.sh"
        if [ -f "$script" ]; then
            bash "$script"
        else
            error "Diagnostics script not found."
        fi
        ;;
    --edit-usercard)
        EDITOR_SCRIPT="$AIKO_WIDGETS/aiko-usercard/aiko-usercard-editor.py"
        if [ -f "$EDITOR_SCRIPT" ]; then
            python3 "$EDITOR_SCRIPT"
        else
            error "User Card editor not found at $EDITOR_SCRIPT"
        fi
        ;;
    --edit-logo)
        LOGO_EDITOR="$AIKO_WIDGETS/aiko-sys/aiko-logo-editor.py"
        if [ -f "$LOGO_EDITOR" ]; then
            python3 "$LOGO_EDITOR"
            if have fastfetch; then
                clear
                fastfetch
            fi
        else
            error "Logo editor not found at $LOGO_EDITOR"
        fi
        ;;
    --restart)
        script="$AIKO_SCRIPTS/restart-waybar.sh"
        if [ -f "$script" ]; then
            bash "$script"
        else
            error "restart-waybar.sh not found."
        fi
        ;;
    *)
        if [ -n "${1:-}" ]; then
            error "Unknown option: $1"
            show_help
            exit 1
        else
            show_help
        fi
        ;;
esac
