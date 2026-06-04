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

STYLE_CSS="$AIKO_ROOT/style.css"

# Kill all running Waybar instances and listeners
killall waybar || true
pkill -f icon-listener.sh || true
pkill -f clipboard-listener.sh || true

# Wait a moment to ensure processes are closed
sleep 0.5

# --- Theme & Icon Sync ---
# Find which theme is currently active via style.css symlink
if [ -L "$STYLE_CSS" ]; then
    ACTIVE_THEME=$(readlink -f "$STYLE_CSS")
    if [ -f "$ACTIVE_THEME" ]; then
        # Extract accent color for icons
        ACCENT_COLOR=$(grep "@mako-border" "$ACTIVE_THEME" | cut -d':' -f2 | tr -d '[:space:]')
        [ -z "$ACCENT_COLOR" ] && ACCENT_COLOR="#ff8fbd"
        
        log "Syncing icons and colors for active theme: $(basename "$ACTIVE_THEME")"
        
        # Run icon generator
        if [ -f "$AIKO_SCRIPTS/icon-gen.sh" ]; then
            bash "$AIKO_SCRIPTS/icon-gen.sh" "$ACCENT_COLOR"
        fi
        
        # Sync fastfetch
        if [ -f "$AIKO_SCRIPTS/sync-fastfetch.py" ]; then
            python3 "$AIKO_SCRIPTS/sync-fastfetch.py"
        fi
    fi
fi

# Apply wallpaper (static or animated)
if [ -f "$AIKO_SCRIPTS/wallpaper.sh" ]; then
    bash "$AIKO_SCRIPTS/wallpaper.sh" apply
fi

# Start the three instances
nohup waybar --config "$AIKO_ROOT/config-left.jsonc" --style "$STYLE_CSS" >/dev/null 2>&1 &
sleep 0.4
nohup waybar --config "$AIKO_ROOT/config.jsonc" --style "$STYLE_CSS" >/dev/null 2>&1 &
sleep 0.4
nohup waybar --config "$AIKO_ROOT/config-bottom.jsonc" --style "$STYLE_CSS" >/dev/null 2>&1 &

# Restart Listeners
nohup "$AIKO_SCRIPTS/icon-listener.sh" >/dev/null 2>&1 &
nohup "$AIKO_SCRIPTS/clipboard-listener.sh" >/dev/null 2>&1 &

# Restart Aiko Widgets if they were running
widgets=("clock" "weather" "note" "player" "list" "sys" "usercard")
for w in "${widgets[@]}"; do
    widget="aiko-$w"
    if pgrep -f "$widget.py" >/dev/null || pgrep -f "$widget-bin" >/dev/null; then
        log "Restarting $widget..."
        pkill -f "$widget.py" || true
        pkill -f "$widget-bin" || true
        # Start it back using the global CLI
        nohup aiko --"$w" >/dev/null 2>&1 &
    fi
done
