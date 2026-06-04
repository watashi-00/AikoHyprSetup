#!/usr/bin/env bash
# aiko - Global CLI for AikoHyprSetup management

VERSION="1.0.4"

# Get the real directory of the script, resolving symlinks
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

# Resolve the project root directory
# If we are in ~/.config/waybar or ~/.config/waybar/scripts, the root is ~/.config/waybar
if [[ "$SCRIPT_DIR" == */scripts ]]; then
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
elif [ -f "$SCRIPT_DIR/config.jsonc" ] || [ -f "$SCRIPT_DIR/waybar/config.jsonc" ]; then
    PROJECT_ROOT="$SCRIPT_DIR"
else
    # Fallback to standard location
    PROJECT_ROOT="$HOME/.config/waybar"
fi

show_help() {
    cat <<EOF
Aiko CLI - Manage your AikoHyprSetup environment

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
        echo "Aiko CLI v$VERSION"
        ;;
    --install)
        if [ -f "$PROJECT_ROOT/install.sh" ]; then
            bash "$PROJECT_ROOT/install.sh"
        else
            error "install.sh not found in $PROJECT_ROOT"
        fi
        ;;
    --gpu)
        GPU_LOCAL="$PROJECT_ROOT/../gpu_setup/setup.sh"
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
        if [ -d "$PROJECT_ROOT/.git" ]; then
            log "Updating AikoHyprSetup via git..."
            git -C "$PROJECT_ROOT" pull
        else
            warn "Non-git installation detected. Checking for updates on GitHub..."
            if have curl && have unzip; then
                # Fetch remote version
                REMOTE_VERSION=$(curl -sSL https://raw.githubusercontent.com/watashi-00/AikoHyprSetup/master/scripts/aiko.sh | grep '^VERSION=' | cut -d '"' -f 2)
                
                if [ -z "$REMOTE_VERSION" ]; then
                    error "Could not check for updates. Please check your connection."
                elif [ "$REMOTE_VERSION" == "$VERSION" ]; then
                    log "You are already using the latest version ($VERSION)."
                else
                    log "A new version is available: $REMOTE_VERSION (Current: $VERSION)"
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
        script="$PROJECT_ROOT/scripts/wallpaper.sh"
        [ ! -f "$script" ] && script="$PROJECT_ROOT/wallpaper.sh"
        if [ -f "$script" ]; then
            bash "$script" select
        else
            error "wallpaper.sh not found."
        fi
        ;;
    --theme)
        script="$PROJECT_ROOT/scripts/theme-selector.sh"
        [ ! -f "$script" ] && script="$PROJECT_ROOT/theme-selector.sh"
        if [ -f "$script" ]; then
            bash "$script"
        else
            error "theme-selector.sh not found."
        fi
        ;;
    --note)
        if [ -f "$PROJECT_ROOT/widgets/aiko-note/aiko-note.sh" ]; then
            bash "$PROJECT_ROOT/widgets/aiko-note/aiko-note.sh"
        else
            error "Aiko-Note widget not found."
        fi
        ;;
    --list)
        if [ -f "$PROJECT_ROOT/widgets/aiko-list/aiko-list.sh" ]; then
            bash "$PROJECT_ROOT/widgets/aiko-list/aiko-list.sh"
        else
            error "Aiko-List widget not found."
        fi
        ;;
    --sys)
        if [ -f "$PROJECT_ROOT/widgets/aiko-sys/aiko-sys.sh" ]; then
            bash "$PROJECT_ROOT/widgets/aiko-sys/aiko-sys.sh"
        else
            error "Aiko-System widget not found."
        fi
        ;;
    --clock)
        if [ -f "$PROJECT_ROOT/widgets/aiko-clock/aiko-clock.sh" ]; then
            bash "$PROJECT_ROOT/widgets/aiko-clock/aiko-clock.sh"
        else
            error "Aiko-Clock widget not found."
        fi
        ;;
    --weather)
        if [ -f "$PROJECT_ROOT/widgets/aiko-weather/aiko-weather.sh" ]; then
            bash "$PROJECT_ROOT/widgets/aiko-weather/aiko-weather.sh"
        else
            error "Aiko-Weather widget not found."
        fi
        ;;
    --usercard)
        if [ -f "$PROJECT_ROOT/widgets/aiko-usercard/aiko-usercard.sh" ]; then
            bash "$PROJECT_ROOT/widgets/aiko-usercard/aiko-usercard.sh"
        else
            error "Aiko-UserCard widget not found."
        fi
        ;;
    --player)
        if [ -f "$PROJECT_ROOT/widgets/aiko-player/aiko-player.sh" ]; then
            bash "$PROJECT_ROOT/widgets/aiko-player/aiko-player.sh"
        else
            error "Aiko-Player widget not found."
        fi
        ;;
    --all)
        log "Launching all Aiko widgets..."
        widgets=("aiko-clock" "aiko-weather" "aiko-note" "aiko-player" "aiko-list" "aiko-sys" "aiko-usercard")
        for widget in "${widgets[@]}"; do
            script="$PROJECT_ROOT/widgets/$widget/$widget.sh"
            if [ -f "$script" ]; then
                log "  -> Starting $widget"
                bash "$script" &
                sleep 0.2
            fi
        done
        ;;
    --diag)
        script="$PROJECT_ROOT/scripts/diagnostics.sh"
        [ ! -f "$script" ] && script="$PROJECT_ROOT/diagnostics.sh"
        if [ -f "$script" ]; then
            bash "$script"
        else
            error "Diagnostics script not found."
        fi
        ;;
    --edit-usercard)
        EDITOR_SCRIPT="$PROJECT_ROOT/widgets/aiko-usercard/aiko-usercard-editor.py"
        if [ -f "$EDITOR_SCRIPT" ]; then
            python3 "$EDITOR_SCRIPT"
        else
            error "User Card editor not found at $EDITOR_SCRIPT"
        fi
        ;;
    --edit-logo)
        LOGO_EDITOR="$PROJECT_ROOT/widgets/aiko-sys/aiko-logo-editor.py"
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
        script="$PROJECT_ROOT/scripts/restart-waybar.sh"
        [ ! -f "$script" ] && script="$PROJECT_ROOT/restart-waybar.sh"
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
