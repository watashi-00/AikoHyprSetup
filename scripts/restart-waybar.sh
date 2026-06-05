#!/usr/bin/env bash

# Resolve real path to locate utility library
SCRIPT_DIR_RESTART="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
LIB_UTILS_RESTART="$SCRIPT_DIR_RESTART/lib/utils.sh"

if [ -f "$LIB_UTILS_RESTART" ]; then
    # shellcheck disable=SC1091
    source "$LIB_UTILS_RESTART"
else
    # Fallback paths
    NC=$'\e[0m'
    BLUE=$'\e[0;34m'
    AIKO_ROOT="$HOME/.config/waybar"
    AIKO_SCRIPTS="$AIKO_ROOT/scripts"
fi

AIKO_LOG_COMPONENT="restart"

# --- Path Setup ---
STYLE_CSS="$AIKO_ROOT/style.css"
[ ! -f "$STYLE_CSS" ] && STYLE_CSS="$AIKO_ROOT/waybar/style.css"

get_config_path() {
    local name="$1"
    if [ -f "$AIKO_ROOT/$name" ]; then
        echo "$AIKO_ROOT/$name"
    else
        echo "$AIKO_ROOT/waybar/$name"
    fi
}

# Aggressively kill all running Waybar instances and listeners
pkill -9 waybar 2>/dev/null || true
pkill -f icon-listener.sh 2>/dev/null || true
pkill -f clipboard-listener.sh 2>/dev/null || true

# Clean up old shims
rm -f /tmp/waybar-shim-*.json

# Wait a moment to ensure processes are closed
sleep 0.8

# --- Theme & Icon Sync ---
if [ -L "$STYLE_CSS" ]; then
    ACTIVE_THEME=$(readlink -f "$STYLE_CSS")
    if [ -f "$ACTIVE_THEME" ]; then
        ACCENT_COLOR=$(grep "@mako-border" "$ACTIVE_THEME" | cut -d':' -f2 | tr -d '[:space:]')
        [ -z "$ACCENT_COLOR" ] && ACCENT_COLOR="#ff8fbd"
        
        log "Syncing icons and colors for active theme: $(basename "$ACTIVE_THEME")"
        
        if [ -f "$AIKO_SCRIPTS/icon-gen.sh" ]; then
            nohup bash "$AIKO_SCRIPTS/icon-gen.sh" "$ACCENT_COLOR" >/dev/null 2>&1 &
        fi
        
        if [ -f "$AIKO_SCRIPTS/sync-fastfetch.py" ]; then
            python3 "$AIKO_SCRIPTS/sync-fastfetch.py" >/dev/null 2>&1
        fi
    fi
fi

# Apply wallpaper
if [ -f "$AIKO_SCRIPTS/wallpaper.sh" ]; then
    nohup bash "$AIKO_SCRIPTS/wallpaper.sh" apply >/dev/null 2>&1 &
fi

# Helper function to launch a specific config pinned to an output
launch_pinned_bar() {
    local mon="$1"
    local config_file="$2"
    local id="$3"
    local real_config
    real_config=$(get_config_path "$config_file")
    
    if [ ! -f "$real_config" ]; then
        return
    fi
    
    local shim="/tmp/waybar-shim-${id}-${mon//[^a-zA-Z0-9]/}.json"
    
    # Create shim JSON that includes the original config and pins the output
    echo "{\"include\": [\"$real_config\"], \"output\": \"$mon\"}" > "$shim"
    
    nohup waybar -c "$shim" -s "$STYLE_CSS" >/dev/null 2>&1 &
}

# --- Intelligent Per-Monitor Launch ---
if have hyprctl && have jq; then
    monitors=$(hyprctl monitors -j)
    
    # Iterate through each monitor
    echo "$monitors" | jq -c '.[]' | while read -r mon; do
        name=$(echo "$mon" | jq -r '.name')
        transform=$(echo "$mon" | jq -r '.transform')
        width=$(echo "$mon" | jq -r '.width')
        height=$(echo "$mon" | jq -r '.height')
        
        # Orientation Detection
        is_portrait=0
        if [ "$height" -gt "$width" ]; then
            is_portrait=1
        elif [[ "$transform" =~ ^(1|3|5|7)$ ]]; then
            is_portrait=1
        fi

        if [ "$is_portrait" -eq 1 ]; then
            log "Launching full bar set for $name (Portrait Mode)"
            # Portrait Top Bar (Minimal: Workspaces + Power)
            launch_pinned_bar "$name" "config-portrait.jsonc" "portrait"
            # Bottom Bar (Taskbar)
            launch_pinned_bar "$name" "config-bottom.jsonc" "bottom"
            # Left Bar (Launcher)
            launch_pinned_bar "$name" "config-left.jsonc" "left"
        else
            log "Launching full bar set for $name (Landscape Mode)"
            # Top Bar (Full)
            launch_pinned_bar "$name" "config.jsonc" "top"
            # Bottom Bar (Taskbar)
            launch_pinned_bar "$name" "config-bottom.jsonc" "bottom"
            # Left Bar (Launcher)
            launch_pinned_bar "$name" "config-left.jsonc" "left"
        fi
    done
else
    # Fallback
    nohup waybar --config "$(get_config_path config-left.jsonc)" --style "$STYLE_CSS" >/dev/null 2>&1 &
    sleep 0.3
    nohup waybar --config "$(get_config_path config.jsonc)" --style "$STYLE_CSS" >/dev/null 2>&1 &
    sleep 0.3
    nohup waybar --config "$(get_config_path config-bottom.jsonc)" --style "$STYLE_CSS" >/dev/null 2>&1 &
fi

# Restart Listeners
nohup "$AIKO_SCRIPTS/icon-listener.sh" >/dev/null 2>&1 &
nohup "$AIKO_SCRIPTS/clipboard-listener.sh" >/dev/null 2>&1 &

# Restart Aiko Widgets
widgets=("clock" "weather" "note" "player" "list" "sys" "usercard")
for w in "${widgets[@]}"; do
    widget="aiko-$w"
    if pgrep -f "$widget.py" >/dev/null || pgrep -f "$widget-bin" >/dev/null; then
        log "Restarting $widget..."
        pkill -f "$widget.py" || true
        pkill -f "$widget-bin" || true
        nohup aiko --"$w" >/dev/null 2>&1 &
    fi
done

disown -a
