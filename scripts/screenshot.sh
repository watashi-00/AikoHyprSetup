#!/usr/bin/env bash

# Screenshot script for Hyprland
DIR="$HOME/Imagens/Screenshots"
mkdir -p "$DIR"
FILE="$DIR/print_$(date +'%Y-%m-%d_%H-%M-%S').png"

# Check if swappy is installed for editing
EDITOR_CMD="swappy -f"
if ! command -v swappy &> /dev/null; then
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
        waybar -c "$HOME/.config/waybar/config-screenshot.jsonc" -s "$HOME/.config/waybar/style.css" &
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
