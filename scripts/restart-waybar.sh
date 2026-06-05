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

# Kill all running Waybar instances and listeners
killall waybar 2>/dev/null || true
pkill -f icon-listener.sh 2>/dev/null || true
pkill -f clipboard-listener.sh 2>/dev/null || true

# Wait a moment to ensure processes are closed
sleep 0.6

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

# --- Intelligent Per-Monitor Launch ---
if have hyprctl; then
    monitors=$(hyprctl monitors -j)
    
    # Iterate through each monitor
    echo "$monitors" | jq -c '.[]' | while read -r mon; do
        name=$(echo "$mon" | jq -r '.name')
        transform=$(echo "$mon" | jq -r '.transform')
        
        # 0 or 2 = Landscape (Normal/Inverted)
        # 1 or 3 = Portrait (90°/270°)
        if [ "$transform" -eq 1 ] || [ "$transform" -eq 3 ]; then
            log "Launching Portrait bar for $name"
            nohup waybar --bar "portrait-$name" --config "$(get_config_path config-portrait.jsonc)" --style "$STYLE_CSS" >/dev/null 2>&1 &
        else
            log "Launching Landscape bars for $name"
            # Top Bar
            nohup waybar --bar "top-$name" --config "$(get_config_path config.jsonc)" --style "$STYLE_CSS" >/dev/null 2>&1 &
            # Bottom Bar (if it should be on every landscape monitor)
            nohup waybar --bar "bottom-$name" --config "$(get_config_path config-bottom.jsonc)" --style "$STYLE_CSS" >/dev/null 2>&1 &
            # Left Bar (Launcher) - Optional: only on primary or eDP-1 if you prefer
            nohup waybar --bar "left-$name" --config "$(get_config_path config-left.jsonc)" --style "$STYLE_CSS" >/dev/null 2>&1 &
        fi
    done
else
    # Fallback to old behavior if hyprctl is not available
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
