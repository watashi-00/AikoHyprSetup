#!/usr/bin/env bash

# icon-listener.sh - Listens for Hyprland window events to generate icons in real-time
# Usage: ./icon-listener.sh

GEN_SCRIPT="$HOME/.config/waybar/scripts/icon-gen.sh"
THEME_FILE="$HOME/.config/waybar/style.css"

# If the script is not in the config folder yet, use the local one (repo)
if [ ! -f "$GEN_SCRIPT" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    GEN_SCRIPT="$SCRIPT_DIR/icon-gen.sh"
    THEME_FILE="$SCRIPT_DIR/../waybar/style.css"
fi

get_accent_color() {
    # Resolve the real theme file from the symlink
    local real_theme=$(readlink -f "$THEME_FILE")
    local color=$(grep "@mako-border" "$real_theme" | cut -d':' -f2 | tr -d '[:space:]' | head -n 1)
    echo "${color:-#ff8fbd}"
}

handle() {
    case $1 in
        openwindow*)
            class=$(echo "$1" | cut -d',' -f3)
            if [ -n "$class" ]; then
                accent=$(get_accent_color)
                bash "$GEN_SCRIPT" "$accent" "$class"
            fi
            ;;
    esac
}

# Listen to hyprland socket
socat -U - "UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" | while read -r line; do
    handle "$line"
done
