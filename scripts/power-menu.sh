#!/usr/bin/env bash

# Resolve real path to locate utility library
SCRIPT_DIR_POWER="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
LIB_UTILS_POWER="$SCRIPT_DIR_POWER/lib/utils.sh"

if [ -f "$LIB_UTILS_POWER" ]; then
    # shellcheck disable=SC1091
    source "$LIB_UTILS_POWER"
else
    AIKO_ROOT="$HOME/.config/waybar"
    AIKO_CONFIGS="$AIKO_ROOT/configs"
fi

# Power menu using wofi
if pgrep -x "wofi" > /dev/null; then
    pkill -x "wofi"
    exit 0
fi

entries="Logout\nReboot\nShutdown\nSuspend"

# Use the custom wofi style if available
WOFI_STYLE="$HOME/.config/wofi/style.css"
[ ! -f "$WOFI_STYLE" ] && WOFI_STYLE="$AIKO_CONFIGS/wofi/style.css"

selected=$(echo -e "$entries" | wofi --dmenu --prompt "Power Menu" --width 250 --height 280 --style "$WOFI_STYLE")

case $selected in
    "Logout")
        if have hyprctl; then hyprctl dispatch exit; fi
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
