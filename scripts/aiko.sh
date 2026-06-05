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
aiko_enable_err_handler

show_help() {
    cat <<EOF
Aiko CLI v$AIKO_VERSION - Manage your AikoHyprSetup environment

Usage: aiko [options]

Options:
  -h, --help        Show this help message
  -v, --version     Show version information
  --install         Run the installation script
  --update [branch] Update AikoHyprSetup from the specified branch (defaults to master)
  --update-test     Update AikoHyprSetup from the test branch
  --wallpaper       Open the wallpaper selector
  --theme           Open the theme selector
  --monitors        Open the Monitor configuration widget
  --note            Open the Aiko-Note widget
  --clock           Open the Aiko-Clock widget
  --weather         Open the Aiko-Weather widget
  --usercard        Open the Aiko-UserCard widget
  --player          Open the Aiko-Player widget
  --list            Open the Aiko-List widget
  --sys             Open the Aiko-System widget
  --all             Open all Aiko widgets at once
  --launcher        Open application launcher (wofi)
  --power           Open power menu
  --clip            Open clipboard history
  --clip-listener   Start the clipboard listener (deprecated, use --event-listener)
  --icon-listener   Start the icon window listener (deprecated, use --event-listener)
  --event-listener  Start the global event listener
  --screenshot      Open screenshot menu
  --minimize        Minimize/Restore active window
  --test            Run internal codebase integrity test
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

perform_update() {
    local branch="${1:-master}"
    if [ -d "$AIKO_ROOT/.git" ]; then
        log "Updating AikoHyprSetup via git (branch: $branch)..."
        git -C "$AIKO_ROOT" fetch origin
        if git -C "$AIKO_ROOT" show-ref --verify --quiet "refs/heads/$branch"; then
            git -C "$AIKO_ROOT" checkout "$branch"
        else
            git -C "$AIKO_ROOT" checkout -b "$branch" "origin/$branch"
        fi
        git -C "$AIKO_ROOT" pull origin "$branch"
    else
        warn "Non-git installation detected. Checking for updates on GitHub (branch: $branch)..."
        if have curl && have unzip; then
            # Fetch remote version from GitHub (using cache-buster to ensure fresh data)
            local remote_version
            remote_version=$(curl -sSL "https://raw.githubusercontent.com/watashi-00/AikoHyprSetup/$branch/scripts/lib/utils.sh?$(date +%s)" | grep '^export AIKO_VERSION=' | cut -d '"' -f 2)
            
            # Fetch latest commit hash from GitHub API
            local remote_hash
            remote_hash=$(curl -s "https://api.github.com/repos/watashi-00/AikoHyprSetup/commits/$branch" | grep -m1 '"sha":' | cut -d'"' -f4 | cut -c1-7)
            
            # Get local hash if available
            local local_hash_file="$AIKO_ROOT/.version_hash"
            local local_hash=""
            [ -f "$local_hash_file" ] && local_hash=$(cat "$local_hash_file")

            if [ -z "$remote_version" ]; then
                error "Could not check for updates. Please check your connection."
            # Only say "latest version" if both Version AND Hash match (and Hash file exists)
            elif [ "$remote_version" == "$AIKO_VERSION" ] && [ -n "$local_hash" ] && [ "$remote_hash" == "$local_hash" ]; then
                log "You are already using the latest version of branch '$branch' ($AIKO_VERSION)."
            else
                # Decide what message to show
                if [ "$remote_version" != "$AIKO_VERSION" ]; then
                    log "A new version is available: $remote_version (Current: $AIKO_VERSION)"
                elif [ "$remote_hash" != "$local_hash" ]; then
                    log "A hotfix or synchronization update is available (Hash: $remote_hash)"
                fi
                
                log "Downloading and installing the update..."
                
                local temp_dir
                temp_dir=$(mktemp -d)
                if curl -L "https://github.com/watashi-00/AikoHyprSetup/archive/refs/heads/$branch.zip" -o "$temp_dir/update.zip"; then
                    log "Extracting..."
                    unzip -q "$temp_dir/update.zip" -d "$temp_dir"
                    local extracted_dir
                    extracted_dir=$(find "$temp_dir" -maxdepth 1 -type d -name "AikoHyprSetup-*" | head -n 1)
                    
                    if [ -f "$extracted_dir/install.sh" ]; then
                        log "Running installer..."
                        bash "$extracted_dir/install.sh" --no-packages
                        
                        # Store the new hash for future checks
                        echo "$remote_hash" > "$local_hash_file"
                    else
                        error "install.sh not found in update package."
                    fi
                else
                    error "Failed to download update."
                fi
                rm -rf "$temp_dir"
            fi
        else
            error "'curl' and 'unzip' are required for non-git updates."
            log "Please update manually from: https://github.com/watashi-00/AikoHyprSetup"
        fi
    fi
}

case "${1:-}" in
    -h|--help)
        show_help
        ;;
    -v|--version)
        echo "Aiko CLI v$AIKO_VERSION (Hash: ${AIKO_HASH:-none})"
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
        perform_update "${2:-master}"
        ;;
    --update-test)
        perform_update "${2:-test}"
        ;;
    --launcher)
        [ -f "$AIKO_SCRIPTS/launcher.sh" ] && exec bash "$AIKO_SCRIPTS/launcher.sh"
        ;;
    --power)
        [ -f "$AIKO_SCRIPTS/power-menu.sh" ] && exec bash "$AIKO_SCRIPTS/power-menu.sh"
        ;;
    --clip)
        [ -f "$AIKO_SCRIPTS/clipboard-history.sh" ] && exec bash "$AIKO_SCRIPTS/clipboard-history.sh"
        ;;
    --clip-listener)
        if [ -f "$AIKO_SCRIPTS/event-listener.sh" ]; then
            exec bash "$AIKO_SCRIPTS/event-listener.sh"
        elif [ -f "$AIKO_SCRIPTS/clipboard-listener.sh" ]; then
            exec bash "$AIKO_SCRIPTS/clipboard-listener.sh"
        fi
        ;;
    --event-listener)
        [ -f "$AIKO_SCRIPTS/event-listener.sh" ] && exec bash "$AIKO_SCRIPTS/event-listener.sh"
        ;;
    --icon-listener)
        if [ -f "$AIKO_SCRIPTS/event-listener.sh" ]; then
            exec bash "$AIKO_SCRIPTS/event-listener.sh"
        elif [ -f "$AIKO_SCRIPTS/icon-listener.sh" ]; then
            exec bash "$AIKO_SCRIPTS/icon-listener.sh"
        fi
        ;;
    --screenshot)
        [ -f "$AIKO_SCRIPTS/screenshot.sh" ] && exec bash "$AIKO_SCRIPTS/screenshot.sh" "${2:-menu}"
        ;;
    --test)
        [ -f "$AIKO_SCRIPTS/test.sh" ] && exec bash "$AIKO_SCRIPTS/test.sh"
        ;;
    --minimize)
        [ -f "$AIKO_SCRIPTS/minimize.sh" ] && exec bash "$AIKO_SCRIPTS/minimize.sh" "${2:-toggle}"
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
    --monitors)
        bash "$AIKO_SCRIPTS/lib/widget_launcher.sh" "aiko-monitors"
        ;;
    --note)
        bash "$AIKO_SCRIPTS/lib/widget_launcher.sh" "aiko-note"
        ;;
    --list)
        bash "$AIKO_SCRIPTS/lib/widget_launcher.sh" "aiko-list"
        ;;
    --sys)
        bash "$AIKO_SCRIPTS/lib/widget_launcher.sh" "aiko-sys"
        ;;
    --clock)
        bash "$AIKO_SCRIPTS/lib/widget_launcher.sh" "aiko-clock"
        ;;
    --weather)
        bash "$AIKO_SCRIPTS/lib/widget_launcher.sh" "aiko-weather"
        ;;
    --usercard)
        bash "$AIKO_SCRIPTS/lib/widget_launcher.sh" "aiko-usercard"
        ;;
    --player)
        bash "$AIKO_SCRIPTS/lib/widget_launcher.sh" "aiko-player"
        ;;
    --all)
        log "Launching all Aiko widgets..."
        widgets=("aiko-clock" "aiko-weather" "aiko-note" "aiko-player" "aiko-list" "aiko-sys" "aiko-usercard" "aiko-monitors")
        for widget in "${widgets[@]}"; do
            log "  -> Starting $widget"
            bash "$AIKO_SCRIPTS/lib/widget_launcher.sh" "$widget"
            sleep 0.1
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
