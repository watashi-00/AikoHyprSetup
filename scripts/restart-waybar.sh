#!/bin/bash

# Kill all running Waybar instances
killall waybar || true

# Apply wallpaper (static or animated)
if [ -x $HOME/.config/waybar/wallpaper.sh ]; then
    $HOME/.config/waybar/wallpaper.sh apply
fi

# Wait a moment to ensure processes are closed
sleep 0.5

# Start the three instances with a specific order to help Hyprland alignment
# 1. Left Bar (Start first to reserve vertical space on the left)
nohup waybar --config "$HOME/.config/waybar/config-left.jsonc" --style "$HOME/.config/waybar/style.css" >/dev/null 2>&1 &
sleep 0.4

# 2. Top Bar (Now it knows about the space reserved on the left)
nohup waybar --config "$HOME/.config/waybar/config.jsonc" --style "$HOME/.config/waybar/style.css" >/dev/null 2>&1 &
sleep 0.4

# 3. Bottom Bar
nohup waybar --config "$HOME/.config/waybar/config-bottom.jsonc" --style "$HOME/.config/waybar/style.css" >/dev/null 2>&1 &

echo "Waybars restarted successfully with optimized order and delays!"
