#!/usr/bin/env bash

# bluetooth.sh - Streamlined Bluetooth Device Manager for AikoHyprSetup

# Resolve real path to locate utility library
SCRIPT_DIR_BT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
LIB_UTILS_BT="$SCRIPT_DIR_BT/lib/utils.sh"

if [ -f "$LIB_UTILS_BT" ]; then
    # shellcheck disable=SC1091
    source "$LIB_UTILS_BT"
else
    AIKO_ROOT="$HOME/.config/waybar"
    AIKO_CONFIGS="$AIKO_ROOT/configs"
fi

if pgrep -x "wofi" > /dev/null; then
    pkill -x "wofi"
    exit 0
fi

WOFI_STYLE="$HOME/.config/wofi/style.css"
[ ! -f "$WOFI_STYLE" ] && WOFI_STYLE="$AIKO_CONFIGS/wofi/style.css"
WOFI_CONF="$HOME/.config/wofi/config"
[ ! -f "$WOFI_CONF" ] && WOFI_CONF="$AIKO_CONFIGS/wofi/config"

# Check if bluetoothctl is installed
if ! command -v bluetoothctl >/dev/null 2>&1; then
    notify-send "Aiko Bluetooth" "bluetoothctl is not installed." -i dialog-error
    exit 1
fi

# Main menu loop
while true; do
    # Get power state
    power_state=$(bluetoothctl show | grep "Powered:" | awk '{print $2}')
    
    options=""
    if [ "$power_state" = "yes" ]; then
        options="Disable Bluetooth\nScan for Devices"
        # List paired devices
        paired_devices=$(bluetoothctl paired-devices | awk '{$1=""; print $0}' | sed 's/^ //')
        # Check connection status of each paired device
        if [ -n "$paired_devices" ]; then
            options="$options\n--- Paired Devices ---"
            while IFS= read -r dev; do
                [ -z "$dev" ] && continue
                # Get MAC address of device
                mac=$(bluetoothctl paired-devices | grep -F "$dev" | head -n 1 | awk '{print $2}')
                if [ -n "$mac" ]; then
                    is_connected=$(bluetoothctl info "$mac" 2>/dev/null | grep "Connected:" | awk '{print $2}')
                    if [ "$is_connected" = "yes" ]; then
                        options="$options\n$dev [Connected]"
                    else
                        options="$options\n$dev [Disconnected]"
                    fi
                fi
            done <<< "$paired_devices"
        fi
    else
        options="Enable Bluetooth"
    fi
    options="$options\nExit"

    selected=$(echo -e "$options" | wofi --dmenu --prompt "Aiko Bluetooth" --style "$WOFI_STYLE" --conf "$WOFI_CONF")
    
    [ -z "$selected" ] || [ "$selected" = "Exit" ] && exit 0

    if [ "$selected" = "Enable Bluetooth" ]; then
        bluetoothctl power on
        notify-send "Aiko Bluetooth" "Bluetooth enabled." -i bluetooth
        sleep 1
    elif [ "$selected" = "Disable Bluetooth" ]; then
        bluetoothctl power off
        notify-send "Aiko Bluetooth" "Bluetooth disabled." -i bluetooth-active
        sleep 1
    elif [ "$selected" = "Scan for Devices" ]; then
        notify-send "Aiko Bluetooth" "Scanning for devices (5s)..." -i bluetooth
        # Scan for 5 seconds asynchronously
        bluetoothctl --timeout 5 scan on >/dev/null 2>&1
        
        # Get all devices found
        all_devices=$(bluetoothctl devices | awk '{$1=""; print $0}' | sed 's/^ //')
        paired_list=$(bluetoothctl paired-devices | awk '{$1=""; print $0}' | sed 's/^ //')
        
        # Filter out paired devices from the scan list
        scan_options=""
        while IFS= read -r dev; do
            [ -z "$dev" ] && continue
            # If not in paired_list
            if ! echo "$paired_list" | grep -Fqx "$dev"; then
                scan_options="$scan_options\n$dev"
            fi
        done <<< "$all_devices"
        scan_options=$(echo -e "$scan_options" | grep -v '^$')
        
        if [ -z "$scan_options" ]; then
            notify-send "Aiko Bluetooth" "No new devices found." -i bluetooth
            continue
        fi
        
        selected_scan=$(echo -e "$scan_options\nBack" | wofi --dmenu --prompt "Select device to pair..." --style "$WOFI_STYLE" --conf "$WOFI_CONF")
        [ -z "$selected_scan" ] || [ "$selected_scan" = "Back" ] && continue
        
        # Get MAC
        mac=$(bluetoothctl devices | grep -F "$selected_scan" | head -n 1 | awk '{print $2}')
        if [ -n "$mac" ]; then
            notify-send "Aiko Bluetooth" "Pairing and connecting to $selected_scan..." -i bluetooth
            if bluetoothctl pair "$mac" && bluetoothctl connect "$mac"; then
                notify-send "Aiko Bluetooth" "Connected to $selected_scan." -i bluetooth-active
            else
                notify-send "Aiko Bluetooth" "Failed to connect to $selected_scan." -i dialog-error
            fi
        fi
    elif [[ "$selected" == *"---"* ]]; then
        continue
    else
        # Selected a paired device
        # Extract device name (remove [Connected] or [Disconnected])
        dev_name=$(echo "$selected" | sed 's/ \[Connected\]//; s/ \[Disconnected\]//')
        mac=$(bluetoothctl paired-devices | grep -F "$dev_name" | head -n 1 | awk '{print $2}')
        
        if [ -z "$mac" ]; then
            notify-send "Aiko Bluetooth" "Could not find MAC for $dev_name" -i dialog-error
            continue
        fi
        
        is_connected=$(bluetoothctl info "$mac" | grep "Connected:" | awk '{print $2}')
        
        device_actions=""
        if [ "$is_connected" = "yes" ]; then
            device_actions="Disconnect\nUnpair / Remove\nBack"
        else
            device_actions="Connect\nUnpair / Remove\nBack"
        fi
        
        action=$(echo -e "$device_actions" | wofi --dmenu --prompt "$dev_name Actions" --style "$WOFI_STYLE" --conf "$WOFI_CONF")
        [ -z "$action" ] || [ "$action" = "Back" ] && continue
        
        if [ "$action" = "Connect" ]; then
            notify-send "Aiko Bluetooth" "Connecting to $dev_name..." -i bluetooth
            if bluetoothctl connect "$mac"; then
                notify-send "Aiko Bluetooth" "Connected to $dev_name." -i bluetooth-active
            fi
        elif [ "$action" = "Disconnect" ]; then
            notify-send "Aiko Bluetooth" "Disconnecting from $dev_name..." -i bluetooth
            if bluetoothctl disconnect "$mac"; then
                notify-send "Aiko Bluetooth" "Disconnected from $dev_name." -i bluetooth
            fi
        elif [ "$action" = "Unpair / Remove" ]; then
            notify-send "Aiko Bluetooth" "Removing $dev_name..." -i edit-delete
            if bluetoothctl remove "$mac"; then
                notify-send "Aiko Bluetooth" "Removed $dev_name." -i edit-delete
            fi
        fi
        sleep 1
    fi
done
