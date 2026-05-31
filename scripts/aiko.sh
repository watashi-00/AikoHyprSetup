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
