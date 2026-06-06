#!/usr/bin/env bash
# scripts/events/openwindow.sh - Handle openwindow Hyprland event

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
AIKO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AIKO_SCRIPTS="$AIKO_ROOT/scripts"

if [ -f "$AIKO_SCRIPTS/lib/utils.sh" ]; then
    # shellcheck disable=SC1091
    source "$AIKO_SCRIPTS/lib/utils.sh"
fi

AIKO_LOG_COMPONENT="event-openwindow"

GEN_SCRIPT="$AIKO_SCRIPTS/icon-gen.sh"
STYLE_FILE="$AIKO_ROOT/style.css"

get_accent_color() {
    local real_theme=$(readlink -f "$STYLE_FILE")
    local color=$(grep "@mako-border" "$real_theme" | cut -d':' -f2 | tr -d '[:space:]' | head -n 1)
    echo "${color:-#ff8fbd}"
}

reload_bottom_bar() {
    pkill -f "waybar -c /tmp/waybar-shim-bottom-" || pkill -f "waybar --config .*config-bottom.jsonc" || true
    sleep 0.4
    local found=0
    for shim in /tmp/waybar-shim-bottom-*.json; do
        if [ -f "$shim" ]; then
            nohup waybar -c "$shim" -s "$STYLE_FILE" >/dev/null 2>&1 &
            found=1
        fi
    done
    if [ "$found" -eq 0 ]; then
        nohup waybar --config "$AIKO_ROOT/config-bottom.jsonc" --style "$STYLE_FILE" >/dev/null 2>&1 &
    fi
}

event_data="$1"
class=$(echo "$event_data" | sed 's/openwindow>>//' | cut -d',' -f3)

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
