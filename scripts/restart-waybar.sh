#!/bin/bash

# Kill all running Waybar instances
killall waybar || true

# Apply wallpaper (static or animated)
if [ -x ~/.config/waybar/wallpaper.sh ]; then
    ~/.config/waybar/wallpaper.sh apply
fi

# Wait a moment to ensure processes are closed
sleep 0.5

# Start the three instances according to your configuration
waybar --config ~/.config/waybar/config.jsonc --style ~/.config/waybar/style.css &
waybar --config ~/.config/waybar/config-bottom.jsonc --style ~/.config/waybar/style.css &
waybar --config ~/.config/waybar/config-left.jsonc --style ~/.config/waybar/style.css &

echo "Waybars restarted successfully!"
