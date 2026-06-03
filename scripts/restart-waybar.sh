#!/usr/bin/env bash

# Paths
WAYBAR_DIR="$HOME/.config/waybar"
STYLE_CSS="$WAYBAR_DIR/style.css"
SCRIPTS_DIR="$WAYBAR_DIR/scripts"

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
        
        echo "Syncing icons and colors for active theme: $(basename "$ACTIVE_THEME")"
        
        # Run icon generator
        if [ -f "$SCRIPTS_DIR/icon-gen.sh" ]; then
            bash "$SCRIPTS_DIR/icon-gen.sh" "$ACCENT_COLOR"
        fi
        
        # Sync fastfetch
        if [ -f "$SCRIPTS_DIR/sync-fastfetch.py" ]; then
            python3 "$SCRIPTS_DIR/sync-fastfetch.py"
        fi
    fi
fi

# Apply wallpaper (static or animated)
if [ -x "$WAYBAR_DIR/wallpaper.sh" ]; then
    "$WAYBAR_DIR/wallpaper.sh" apply
fi

# Start the three instances
nohup waybar --config "$WAYBAR_DIR/config-left.jsonc" --style "$STYLE_CSS" >/dev/null 2>&1 &
sleep 0.4
nohup waybar --config "$WAYBAR_DIR/config.jsonc" --style "$STYLE_CSS" >/dev/null 2>&1 &
sleep 0.4
nohup waybar --config "$WAYBAR_DIR/config-bottom.jsonc" --style "$STYLE_CSS" >/dev/null 2>&1 &

# Restart Listeners
nohup "$SCRIPTS_DIR/icon-listener.sh" >/dev/null 2>&1 &
nohup "$SCRIPTS_DIR/clipboard-listener.sh" >/dev/null 2>&1 &

# Restart Aiko Widgets if they were running
widgets=("aiko-clock" "aiko-weather" "aiko-note" "aiko-player" "aiko-list" "aiko-sys" "aiko-usercard")
for widget in "${widgets[@]}"; do
    if pgrep -f "$widget.py" >/dev/null || pgrep -f "$widget-bin" >/dev/null; then
        echo "Restarting $widget..."
        pkill -f "$widget.py" || true
        pkill -f "$widget-bin" || true
        # Start it back using its launcher script
        nohup bash "$WAYBAR_DIR/widgets/$widget/$widget.sh" >/dev/null 2>&1 &
    fi
done
