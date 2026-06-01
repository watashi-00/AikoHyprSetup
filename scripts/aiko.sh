#!/usr/bin/env bash
# aiko - Global CLI for AikoHyprSetup management

VERSION="1.0.0"
# Get the real directory of the script, resolving symlinks
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

# Resolve the project root directory
if [ -f "$SCRIPT_DIR/../aiko-ideas.md" ]; then
    # Case: Running from the repository (scripts/ folder)
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
else
    # Case: Running from $HOME/.config/waybar
    if [[ "$SCRIPT_DIR" == */scripts ]]; then
        PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
    else
        PROJECT_ROOT="$SCRIPT_DIR"
    fi
fi

show_help() {
    cat <<EOF
Aiko CLI - Manage your AikoHyprSetup environment

Usage: aiko [options]

Options:
  -h, --help        Show this help message
  -v, --version     Show version information
  --install         Run the installation script
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
  --edit-usercard   Edit the User Card information
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
            echo "Error: install.sh not found in $PROJECT_ROOT"
        fi
        ;;
    --wallpaper)
        if [ -f "$PROJECT_ROOT/scripts/wallpaper.sh" ]; then
            bash "$PROJECT_ROOT/scripts/wallpaper.sh" select
        elif [ -f "$PROJECT_ROOT/wallpaper.sh" ]; then
             "$PROJECT_ROOT/wallpaper.sh" select
        fi
        ;;
    --theme)
        if [ -f "$PROJECT_ROOT/scripts/theme-selector.sh" ]; then
            bash "$PROJECT_ROOT/scripts/theme-selector.sh"
        elif [ -f "$PROJECT_ROOT/theme-selector.sh" ]; then
             "$PROJECT_ROOT/theme-selector.sh"
        fi
        ;;
    --note)
        # Try to find the widget in repo or installed path
        if [ -f "$PROJECT_ROOT/widgets/aiko-note/aiko-note.sh" ]; then
            bash "$PROJECT_ROOT/widgets/aiko-note/aiko-note.sh"
        else
            echo "Error: Aiko-Note widget not found."
        fi
        ;;
    --list)
        if [ -f "$PROJECT_ROOT/widgets/aiko-list/aiko-list.sh" ]; then
            bash "$PROJECT_ROOT/widgets/aiko-list/aiko-list.sh"
        else
            echo "Error: Aiko-List widget not found."
        fi
        ;;
    --sys)
        if [ -f "$PROJECT_ROOT/widgets/aiko-sys/aiko-sys.sh" ]; then
            bash "$PROJECT_ROOT/widgets/aiko-sys/aiko-sys.sh"
        else
            echo "Error: Aiko-System widget not found."
        fi
        ;;
    --clock)
        if [ -f "$PROJECT_ROOT/widgets/aiko-clock/aiko-clock.sh" ]; then
            bash "$PROJECT_ROOT/widgets/aiko-clock/aiko-clock.sh"
        else
            echo "Error: Aiko-Clock widget not found."
        fi
        ;;
    --weather)
        if [ -f "$PROJECT_ROOT/widgets/aiko-weather/aiko-weather.sh" ]; then
            bash "$PROJECT_ROOT/widgets/aiko-weather/aiko-weather.sh"
        else
            echo "Error: Aiko-Weather widget not found."
        fi
        ;;
    --usercard)
        if [ -f "$PROJECT_ROOT/widgets/aiko-usercard/aiko-usercard.sh" ]; then
            bash "$PROJECT_ROOT/widgets/aiko-usercard/aiko-usercard.sh"
        else
            echo "Error: Aiko-UserCard widget not found."
        fi
        ;;
    --player)
        if [ -f "$PROJECT_ROOT/widgets/aiko-player/aiko-player.sh" ]; then
            bash "$PROJECT_ROOT/widgets/aiko-player/aiko-player.sh"
        else
            echo "Error: Aiko-Player widget not found."
        fi
        ;;
    --all)
        echo "Launching all Aiko widgets..."
        # List of widgets to launch
        widgets=("aiko-clock" "aiko-weather" "aiko-note" "aiko-player" "aiko-list" "aiko-sys" "aiko-usercard")
        for widget in "${widgets[@]}"; do
            script="$PROJECT_ROOT/widgets/$widget/$widget.sh"
            if [ -f "$script" ]; then
                echo "  -> Starting $widget"
                bash "$script" &
                sleep 0.2 # Small delay to avoid race conditions and window overlap issues
            fi
        done
        ;;
    --edit-usercard)
        EDITOR_SCRIPT="$PROJECT_ROOT/widgets/aiko-usercard/aiko-usercard-editor.py"
        if [ -f "$EDITOR_SCRIPT" ]; then
            python3 "$EDITOR_SCRIPT"
        else
            echo "Error: User Card editor not found at $EDITOR_SCRIPT"
        fi
        ;;
    --restart)
        if [ -f "$PROJECT_ROOT/scripts/restart-waybar.sh" ]; then
            bash "$PROJECT_ROOT/scripts/restart-waybar.sh"
        elif [ -f "$PROJECT_ROOT/restart-waybar.sh" ]; then
             "$PROJECT_ROOT/restart-waybar.sh"
        fi
        ;;
    *)
        if [ -n "${1:-}" ]; then
            echo "Unknown option: $1"
            show_help
            exit 1
        else
            show_help
        fi
        ;;
esac
