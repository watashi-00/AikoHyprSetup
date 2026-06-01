#!/usr/bin/env bash

# icon-listener.sh - Listens for Hyprland window events to generate icons in real-time
# Usage: ./icon-listener.sh

GEN_SCRIPT="$HOME/.config/waybar/scripts/icon-gen.sh"

# If the script is not in the config folder yet, use the local one (repo)
if [ ! -f "$GEN_SCRIPT" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    GEN_SCRIPT="$SCRIPT_DIR/icon-gen.sh"
fi

handle() {
    case $1 in
        openwindow*)
            # Extract class name from event: openwindow>>[address],[workspace],[class],[title]
            class=$(echo "$1" | cut -d',' -f3)
            if [ -n "$class" ]; then
                bash "$GEN_SCRIPT" "" "$class"
            fi
            ;;
    esac
}

# Listen to hyprland socket
socat -U - "UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" | while read -r line; do
    handle "$line"
done
