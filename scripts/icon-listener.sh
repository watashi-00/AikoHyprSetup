#!/usr/bin/env bash

# icon-listener.sh - Listens for Hyprland window events to generate icons in real-time
# Usage: ./icon-listener.sh

GEN_SCRIPT="$HOME/.config/waybar/scripts/icon-gen.sh"
THEME_FILE="$HOME/.config/waybar/style.css"

# If the scripts are not in the config folder yet, use the local one (repo)
if [ ! -f "$GEN_SCRIPT" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    GEN_SCRIPT="$SCRIPT_DIR/icon-gen.sh"
    THEME_FILE="$SCRIPT_DIR/../waybar/style.css"
fi

get_accent_color() {
    local real_theme=$(readlink -f "$THEME_FILE")
    local color=$(grep "@mako-border" "$real_theme" | cut -d':' -f2 | tr -d '[:space:]' | head -n 1)
    echo "${color:-#ff8fbd}"
}

reload_bottom_bar() {
    pkill -f "waybar --config .*config-bottom.jsonc" || true
    sleep 0.4
    nohup waybar --config "$HOME/.config/waybar/config-bottom.jsonc" --style "$HOME/.config/waybar/style.css" >/dev/null 2>&1 &
}

handle() {
    case $1 in
        openwindow*)
            class=$(echo "$1" | sed 's/openwindow>>//' | cut -d',' -f3)
            
            if [ -n "$class" ]; then
                accent=$(get_accent_color)
                bash "$GEN_SCRIPT" "$accent" "$class"
                local exit_code=$?
                
                if [ $exit_code -eq 200 ]; then
                    reload_bottom_bar
                elif [ $exit_code -ne 0 ]; then
                    echo "[listener] Icon generation failed for $class (code: $exit_code)" >&2
                fi
            fi
            ;;
    esac
}

# Listen to hyprland socket
echo "[listener] Aiko Icon Listener active..."
socat -U - "UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" | while read -r line; do
    handle "$line"
done
