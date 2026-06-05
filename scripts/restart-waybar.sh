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
pkill -f event-listener.sh 2>/dev/null || true
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
    local mon_idx="$4"
    local real_config
    real_config=$(get_config_path "$config_file")
    
    if [ ! -f "$real_config" ]; then
        return
    fi
    
    local shim="/tmp/waybar-shim-${id}-${mon//[^a-zA-Z0-9]/}.json"
    
    # If the config file contains hyprland/workspaces and mon_idx is provided, dynamically override workspaces
    if grep -q "hyprland/workspaces" "$real_config" && [ -n "$mon_idx" ]; then
        local w1=$((mon_idx * 5 + 1))
        local w2=$((mon_idx * 5 + 2))
        local w3=$((mon_idx * 5 + 3))
        local w4=$((mon_idx * 5 + 4))
        local w5=$((mon_idx * 5 + 5))
        
        jq -n \
           --arg include "$real_config" \
           --arg output "$mon" \
           --arg w1 "$w1" \
           --arg w2 "$w2" \
           --arg w3 "$w3" \
           --arg w4 "$w4" \
           --arg w5 "$w5" \
           '{
             include: [$include],
             output: $output,
             "hyprland/workspaces": {
               format: "{icon}",
               "on-click": "activate",
               "all-outputs": false,
               "persistent-workspaces": {
                 ($output): [($w1|tonumber), ($w2|tonumber), ($w3|tonumber), ($w4|tonumber), ($w5|tonumber)]
               },
               "format-icons": {
                 ($w1): "1",
                 ($w2): "2",
                 ($w3): "3",
                 ($w4): "4",
                 ($w5): "5"
               }
             }
           }' > "$shim"
    else
        echo "{\"include\": [\"$real_config\"], \"output\": \"$mon\"}" > "$shim"
    fi
    
    nohup waybar -c "$shim" -s "$STYLE_CSS" >/dev/null 2>&1 &
}

# --- Intelligent Per-Monitor Launch ---
if have hyprctl && have jq; then
    monitors=$(hyprctl monitors -j)
    
    # Sort monitors left-to-right by X coordinate to get stable indexes
    mon_names=($(echo "$monitors" | jq -r 'sort_by(.x) | .[].name'))
    
    # Iterate through each monitor in sorted order
    for i in "${!mon_names[@]}"; do
        name="${mon_names[i]}"
        
        # Get details for this monitor
        mon_json=$(echo "$monitors" | jq -c ".[] | select(.name == \"$name\")")
        transform=$(echo "$mon_json" | jq -r '.transform')
        width=$(echo "$mon_json" | jq -r '.width')
        height=$(echo "$mon_json" | jq -r '.height')
        active_ws=$(echo "$mon_json" | jq -r '.activeWorkspace.id')
        
        # Dynamic workspaces: assign 5 workspaces per monitor
        w_start=$((i * 5 + 1))
        w_end=$((i * 5 + 5))
        
        # Bind these workspaces to this monitor dynamically in Hyprland
        for w in $(seq "$w_start" "$w_end"); do
            hyprctl keyword workspace "$w,monitor:$name" >/dev/null 2>&1
        done
        
        # Auto-correct alignment: if the active workspace doesn't belong to this monitor,
        # move it to its correct monitor and focus this monitor on its default workspace
        if [ -n "$active_ws" ] && [ "$active_ws" -gt 0 ]; then
            correct_idx=$(( (active_ws - 1) / 5 ))
            if [ "$correct_idx" -ne "$i" ] && [ "$correct_idx" -ge 0 ] && [ "$correct_idx" -lt "${#mon_names[@]}" ]; then
                correct_mon="${mon_names[correct_idx]}"
                log "Workspace alignment mismatch: workspace $active_ws is active on $name. Moving workspace to $correct_mon"
                hyprctl dispatch moveworkspacetomonitor "$active_ws" "$correct_mon" >/dev/null 2>&1
                
                # Reset this monitor to its default workspace
                hyprctl dispatch focusmonitor "$name" >/dev/null 2>&1
                hyprctl dispatch workspace "$w_start" >/dev/null 2>&1
            fi
        fi
        
        # Orientation Detection
        is_portrait=0
        if [ "$height" -gt "$width" ]; then
            is_portrait=1
        elif [[ "$transform" =~ ^(1|3|5|7)$ ]]; then
            is_portrait=1
        fi

        if [ "$is_portrait" -eq 1 ]; then
            log "Launching full bar set for $name (Portrait Mode)"
            # Launch order: Left -> Bottom -> Top
            launch_pinned_bar "$name" "config-left.jsonc" "left" "$i"
            sleep 0.3
            launch_pinned_bar "$name" "config-bottom.jsonc" "bottom" "$i"
            sleep 0.3
            launch_pinned_bar "$name" "config-portrait.jsonc" "portrait" "$i"
        else
            log "Launching full bar set for $name (Landscape Mode)"
            # Launch order: Left -> Bottom -> Top
            launch_pinned_bar "$name" "config-left.jsonc" "left" "$i"
            sleep 0.3
            launch_pinned_bar "$name" "config-bottom.jsonc" "bottom" "$i"
            sleep 0.3
            launch_pinned_bar "$name" "config.jsonc" "top" "$i"
        fi
    done
else
    # Fallback
    nohup waybar --config "$(get_config_path config-left.jsonc)" --style "$STYLE_CSS" >/dev/null 2>&1 &
    sleep 0.3
    nohup waybar --config "$(get_config_path config-bottom.jsonc)" --style "$STYLE_CSS" >/dev/null 2>&1 &
    sleep 0.3
    nohup waybar --config "$(get_config_path config.jsonc)" --style "$STYLE_CSS" >/dev/null 2>&1 &
fi

# Restart Listeners
if [ -f "$AIKO_SCRIPTS/event-listener.sh" ]; then
    nohup "$AIKO_SCRIPTS/event-listener.sh" >/dev/null 2>&1 &
elif [ -f "$AIKO_SCRIPTS/icon-listener.sh" ]; then
    nohup "$AIKO_SCRIPTS/icon-listener.sh" >/dev/null 2>&1 &
fi

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
