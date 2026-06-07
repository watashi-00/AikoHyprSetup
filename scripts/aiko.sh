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
  --update-check    Check remote branches, versions, commit dates and messages
  --wallpaper       Open the wallpaper selector
  --theme           Open the theme selector
  --layout          Open the Waybar layout selector
  --monitors        Open the Monitor configuration widget
  --audio           Open the Aiko-Audio manager widget
  --note            Open the Aiko-Note widget
  --clock           Open the Aiko-Clock widget
  --weather         Open the Aiko-Weather widget
  --usercard        Open the Aiko-UserCard widget
  --player          Open the Aiko-Player widget
  --list            Open the Aiko-List widget
  --sys             Open the Aiko-System widget
  --calendar        Open the Aiko-Calendar widget
  --timer           Open the Aiko-Timer widget
  --recorder        Open the Aiko-Recorder widget
  --all             Open all Aiko widgets at once
  --launcher        Open application launcher (wofi)
  --search          Open advanced search utility (wofi)
  --power           Open power menu
  --bluetooth       Open bluetooth manager (wofi)
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

check_updates_info() {
    echo -e "${CYAN}--------------------------------------------------${NC}"
    log "Checking AikoHyprSetup Updates & Branches..."
    echo -e "${CYAN}--------------------------------------------------${NC}"

    # 1. Local Info
    local is_git=0
    local local_branch="master"
    local local_hash="unknown"
    
    if [ -d "$AIKO_ROOT/.git" ]; then
        is_git=1
        local_branch=$(git -C "$AIKO_ROOT" branch --show-current)
        local_hash=$(git -C "$AIKO_ROOT" rev-parse --short HEAD 2>/dev/null || echo "unknown")
    else
        # Fallback for non-git
        if [ -f "$AIKO_ROOT/.version_branch" ]; then
            local_branch=$(cat "$AIKO_ROOT/.version_branch")
        fi
        if [ -f "$AIKO_ROOT/.version_hash" ]; then
            local_hash=$(cat "$AIKO_ROOT/.version_hash")
        fi
    fi

    echo -e "${BOLD}Local Installation:${NC}"
    echo -e "  Version: ${CYAN}v$AIKO_VERSION${NC}"
    if [ "$is_git" -eq 1 ]; then
        echo -e "  Branch:  ${GREEN}$local_branch${NC} (via Git)"
    else
        echo -e "  Branch:  ${GREEN}$local_branch${NC} (Manual zip)"
    fi
    echo -e "  Commit:  ${YELLOW}$local_hash${NC}"
    echo ""

    # 2. Remote Info
    echo -e "${BOLD}Remote Branches on GitHub:${NC}"
    
    local branches=("master" "test")
    for b in "${branches[@]}"; do
        # Fetch version
        local r_version
        r_version=$(curl -sSL "https://raw.githubusercontent.com/watashi-00/AikoHyprSetup/$b/scripts/lib/utils.sh?$(date +%s)" | grep '^export AIKO_VERSION=' | cut -d '"' -f 2)
        
        # Fetch commit details
        local commit_json
        commit_json=$(curl -s "https://api.github.com/repos/watashi-00/AikoHyprSetup/commits/$b")
        
        if [ -n "$r_version" ] && echo "$commit_json" | jq -e .sha >/dev/null 2>&1; then
            local r_hash
            r_hash=$(echo "$commit_json" | jq -r '.sha | .[0:7]')
            
            local r_date
            r_date=$(echo "$commit_json" | jq -r '.commit.committer.date' | sed 's/T/ /;s/Z//')
            
            local r_msg
            r_msg=$(echo "$commit_json" | jq -r '.commit.message | split("\n") | .[0]')
            
            # Highlight active branch
            local branch_status=""
            local prefix="  ●"
            if [ "$b" == "$local_branch" ]; then
                prefix="  ${GREEN}●${NC}"
                branch_status=" ${BOLD}${GREEN}(Active & Selected)${NC}"
            fi
            
            echo -e "$prefix ${BOLD}$b${NC}$branch_status"
            echo -e "    Version: ${CYAN}v$r_version${NC}"
            echo -e "    Commit:  ${YELLOW}$r_hash${NC} ($r_date)"
            echo -e "    Message: ${WHITE}\"$r_msg\"${NC}"
            
            # Compare status if this is the active branch
            if [ "$b" == "$local_branch" ]; then
                echo -ne "    Status:  "
                if [ "$local_hash" == "$r_hash" ]; then
                    echo -e "${GREEN}${ICON_CHECK} Up to date${NC}"
                elif [ "$AIKO_VERSION" != "$r_version" ]; then
                    echo -e "${YELLOW}${ICON_WARN} Update Available! (New version v$r_version)${NC}"
                else
                    echo -e "${YELLOW}${ICON_WARN} Hotfix/Sync Update Available (Local: $local_hash vs Remote: $r_hash)${NC}"
                fi
            fi
        else
            echo -e "  ● ${RED}$b (Offline / Unreachable)${NC}"
        fi
        echo ""
    done
    echo -e "${CYAN}--------------------------------------------------${NC}"
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
    --update-check)
        check_updates_info
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
        cmd="${2:-select}"
        if [ "$cmd" = "select" ]; then
            bash "$AIKO_SCRIPTS/lib/widget_launcher.sh" "aiko-wallpaper"
        else
            script="$AIKO_SCRIPTS/wallpaper.sh"
            if [ -f "$script" ]; then
                bash "$script" "$cmd"
            else
                error "wallpaper.sh not found."
            fi
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
    --layout)
        script="$AIKO_SCRIPTS/layout-selector.sh"
        if [ -f "$script" ]; then
            bash "$script" "${2:-}"
        else
            error "layout-selector.sh not found."
        fi
        ;;
    --monitors)
        bash "$AIKO_SCRIPTS/lib/widget_launcher.sh" "aiko-monitors"
        ;;
    --audio)
        bash "$AIKO_SCRIPTS/lib/widget_launcher.sh" "aiko-audio"
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
    --calendar)
        bash "$AIKO_SCRIPTS/lib/widget_launcher.sh" "aiko-calendar"
        ;;
    --timer)
        bash "$AIKO_SCRIPTS/lib/widget_launcher.sh" "aiko-timer"
        ;;
    --recorder)
        bash "$AIKO_SCRIPTS/lib/widget_launcher.sh" "aiko-recorder"
        ;;
    --search)
        bash "$AIKO_SCRIPTS/lib/widget_launcher.sh" "aiko-search"
        ;;
    --bluetooth)
        bash "$AIKO_SCRIPTS/lib/widget_launcher.sh" "aiko-bluetooth"
        ;;
    --all)
        log "Launching all Aiko widgets..."
        widgets=("aiko-clock" "aiko-weather" "aiko-note" "aiko-player" "aiko-list" "aiko-sys" "aiko-usercard" "aiko-monitors" "aiko-audio" "aiko-calendar" "aiko-timer" "aiko-recorder" "aiko-search")
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
