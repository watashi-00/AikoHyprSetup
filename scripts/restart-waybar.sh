#!/usr/bin/env bash

# Kill all running Waybar instances and listeners
killall waybar || true
pkill -f icon-listener.sh || true
pkill -f clipboard-listener.sh || true

# Wait a moment to ensure processes are closed
sleep 0.5

# Apply wallpaper (static or animated)
if [ -x $HOME/.config/waybar/wallpaper.sh ]; then
    $HOME/.config/waybar/wallpaper.sh apply
fi

# Start the three instances with a specific order to help Hyprland alignment
# 1. Left Bar
nohup waybar --config "$HOME/.config/waybar/config-left.jsonc" --style "$HOME/.config/waybar/style.css" >/dev/null 2>&1 &
sleep 0.4

# 2. Top Bar
nohup waybar --config "$HOME/.config/waybar/config.jsonc" --style "$HOME/.config/waybar/style.css" >/dev/null 2>&1 &
sleep 0.4

# 3. Bottom Bar
nohup waybar --config "$HOME/.config/waybar/config-bottom.jsonc" --style "$HOME/.config/waybar/style.css" >/dev/null 2>&1 &

# Restart Listeners
nohup "$HOME/.config/waybar/scripts/icon-listener.sh" >/dev/null 2>&1 &
nohup "$HOME/.config/waybar/scripts/clipboard-listener.sh" >/dev/null 2>&1 &

echo "Waybars and Listeners restarted successfully!"
