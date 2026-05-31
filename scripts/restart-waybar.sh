#!/bin/bash

# Kill all running Waybar instances
killall waybar || true

# Apply wallpaper (static or animated)
if [ -x $HOME/.config/waybar/wallpaper.sh ]; then
    $HOME/.config/waybar/wallpaper.sh apply
fi

# Wait a moment to ensure processes are closed
sleep 0.5

# Start the three instances according to your configuration (fully detached)
nohup waybar --config "$HOME/.config/waybar/config.jsonc" --style "$HOME/.config/waybar/style.css" >/dev/null 2>&1 &
nohup waybar --config "$HOME/.config/waybar/config-bottom.jsonc" --style "$HOME/.config/waybar/style.css" >/dev/null 2>&1 &
nohup waybar --config "$HOME/.config/waybar/config-left.jsonc" --style "$HOME/.config/waybar/style.css" >/dev/null 2>&1 &

echo "Waybars restarted successfully!"
