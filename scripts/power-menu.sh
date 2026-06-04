#!/usr/bin/env bash

# Power menu using wofi
if pgrep -x "wofi" > /dev/null; then
    pkill -x "wofi"
    exit 0
fi

entries="Logout\nReboot\nShutdown\nSuspend"

# Use the custom wofi style if available
WOFI_STYLE="$HOME/.config/wofi/style.css"
if [ ! -f "$WOFI_STYLE" ]; then
    WOFI_STYLE="$HOME/.config/waybar/wofi.css"
fi

selected=$(echo -e "$entries" | wofi --dmenu --prompt "Power Menu" --width 250 --height 280 --style "$WOFI_STYLE")

case $selected in
    "Logout")
        hyprctl dispatch exit
        ;;
    "Reboot")
        systemctl reboot
        ;;
    "Shutdown")
        systemctl poweroff
        ;;
    "Suspend")
        systemctl suspend
        ;;
esac
