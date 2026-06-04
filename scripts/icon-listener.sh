#!/usr/bin/env bash

# icon-listener.sh - Listens for Hyprland window events to generate icons in real-time
# Usage: ./icon-listener.sh

# Resolve real path to locate utility library
SCRIPT_DIR_LIS="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
LIB_UTILS_LIS="$SCRIPT_DIR_LIS/lib/utils.sh"

if [ -f "$LIB_UTILS_LIS" ]; then
    # shellcheck disable=SC1091
    source "$LIB_UTILS_LIS"
else
    AIKO_ROOT="$HOME/.config/waybar"
    AIKO_SCRIPTS="$AIKO_ROOT/scripts"
fi

AIKO_LOG_COMPONENT="icons"

GEN_SCRIPT="$AIKO_SCRIPTS/icon-gen.sh"
STYLE_FILE="$AIKO_ROOT/style.css"

get_accent_color() {
    local real_theme=$(readlink -f "$STYLE_FILE")
    local color=$(grep "@mako-border" "$real_theme" | cut -d':' -f2 | tr -d '[:space:]' | head -n 1)
    echo "${color:-#ff8fbd}"
}

reload_bottom_bar() {
    pkill -f "waybar --config .*config-bottom.jsonc" || true
    sleep 0.4
    nohup waybar --config "$AIKO_ROOT/config-bottom.jsonc" --style "$STYLE_FILE" >/dev/null 2>&1 &
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
                    error "Icon generation failed for $class (code: $exit_code)"
                fi
            fi
            ;;
    esac
}

# Listen to hyprland socket
if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    log "Aiko Icon Listener active..."
    socat -U - "UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" | while read -r line; do
        handle "$line"
    done
else
    error "HYPRLAND_INSTANCE_SIGNATURE not found. Icon listener cannot start."
    exit 1
fi
