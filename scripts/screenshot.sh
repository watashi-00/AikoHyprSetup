#!/usr/bin/env bash

# Resolve real path to locate utility library
SCRIPT_DIR_SHOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
LIB_UTILS_SHOT="$SCRIPT_DIR_SHOT/lib/utils.sh"

if [ -f "$LIB_UTILS_SHOT" ]; then
    # shellcheck disable=SC1091
    source "$LIB_UTILS_SHOT"
else
    AIKO_ROOT="$HOME/.config/waybar"
fi

AIKO_LOG_COMPONENT="shot"

# Screenshot script for Hyprland
DIR="$HOME/Imagens/Screenshots"
mkdir -p "$DIR"
FILE="$DIR/print_$(date +'%Y-%m-%d_%H-%M-%S').png"

# Check if swappy is installed for editing
EDITOR_CMD="swappy -f"
if ! have swappy; then
    EDITOR_CMD="xdg-open"
fi

# Function to hide the screenshot bar before taking the print
hide_bar() {
    pkill -f "config-screenshot.jsonc"
    sleep 0.15 # Vital to ensure the bar is gone from the screen buffer
}

case "$1" in
    "menu")
        if pgrep -f "config-screenshot.jsonc" > /dev/null; then
            pkill -f "config-screenshot.jsonc"
            exit 0
        fi
        waybar -c "$AIKO_ROOT/config-screenshot.jsonc" -s "$AIKO_ROOT/style.css" &
        exit 0
        ;;
    "area")
        hide_bar
        grim -g "$(slurp)" "$FILE"
        ;;
    "full")
        hide_bar
        grim "$FILE"
        ;;
    "picker")
        hide_bar
        color=$(hyprpicker -a)
        if [ -n "$color" ]; then
            wl-copy "$color"
            notify-send "Color Picker" "Color copied: $color" -i color-management
        fi
        exit 0
        ;;
    "edit")
        hide_bar
        TARGET=${2:-$(ls -t "$DIR"/print_*.png 2>/dev/null | head -n 1)}
        if [ -n "$TARGET" ]; then
            $EDITOR_CMD "$TARGET"
        fi
        exit 0
        ;;
    *)
        echo "Usage: $0 {menu|area|full|picker|edit}"
        exit 1
        ;;
esac

if [ -f "$FILE" ]; then
    wl-copy < "$FILE"
    # Send notification with 'screenshot' category
    notify-send -a "Hyprland" -i "$FILE" -c "screenshot" "Screenshot" "Image saved and copied.\nClick to edit."
fi
